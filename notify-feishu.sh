#!/usr/bin/env bash
# Claude Code → Feishu notification hook
# Sends a card message with urgent (加急) when Claude Code completes a task or needs attention.

set -euo pipefail

USER_OPEN_ID="${CC_FEISHU_OPEN_ID:-ou_REPLACE_ME}"
LOG_FILE="$HOME/.claude/hooks/cc-notify.log"

# Ensure log directory exists (before any log calls)
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null || true; }

# Mute: set CC_FEISHU_NOTIFY=0 to suppress all notifications
if [ "${CC_FEISHU_NOTIFY:-1}" = "0" ]; then exit 0; fi

# Validate USER_OPEN_ID (check prefix pattern, not literal value)
if [[ "$USER_OPEN_ID" == "ou_REPLACE"* ]]; then
  echo "[cc-notify] CC_FEISHU_OPEN_ID not configured. Set the environment variable with your open_id." >&2
  exit 1
fi

input=$(cat)

event=$(echo "$input" | jq -r '.hook_event_name // "unknown"')

case "$event" in
  Stop)
    msg=$(echo "$input" | jq -r '.last_assistant_message // ""')
    cwd=$(echo "$input" | jq -r '.cwd // ""')
    transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')

    # Fallback: read last assistant message from transcript JSONL
    if [ -z "$msg" ] && [ -n "$transcript_path" ]; then
      expanded_path="${transcript_path/#\~/$HOME}"
      if [ -f "$expanded_path" ]; then
        msg=$(tail -100 "$expanded_path" 2>/dev/null | jq -r 'select(.message.content != null) | .message.content[] | select(.type == "text") | .text' 2>/dev/null | tail -1 || true)
      fi
    fi

    if [ -z "$msg" ]; then msg="任务完成"; fi
    if [ ${#msg} -gt 1000 ]; then msg="${msg:0:1000}..."; fi

    # Error detection (case-insensitive)
    is_error=false
    if echo "$msg" | grep -qi -E "api error:|error:|failed|traceback"; then
      is_error=true
    fi

    if [ "$is_error" = true ]; then
      title="❌ Claude Code 任务异常"
      color="red"
    else
      title="✅ Claude Code 任务完成"
      color="green"
    fi

    if [ -n "$cwd" ]; then
      NL=$'\n'
      body="<font size=2>📂 ${cwd##*/}</font>${NL}${msg}"
    else
      body="$msg"
    fi
    ;;
  Notification)
    msg=$(echo "$input" | jq -r '.message // "需要关注"')
    notif_type=$(echo "$input" | jq -r '.notification_type // ""')
    case "$notif_type" in
      permission_prompt)
        title="⚠️ Claude Code 需要确认"
        color="orange"
        ;;
      idle_prompt)
        title="⏳ Claude Code 等待中"
        color="blue"
        ;;
      auth_success)
        title="✅ Claude Code 认证成功"
        color="green"
        ;;
      *)
        title="🔔 Claude Code 通知"
        color="purple"
        ;;
    esac
    body="$msg"
    ;;
  *)
    title="🔔 Claude Code"
    color="grey"
    body=$(echo "$input" | jq -r '.message // .last_assistant_message // "未知事件"')
    ;;
esac

# Feishu card 2.0 format
card=$(jq -nc \
  --arg title "$title" \
  --arg color "$color" \
  --arg body "$body" \
  '{
    schema: "2.0",
    header: {
      title: {tag: "plain_text", content: $title},
      template: $color,
      padding: "12px 12px 12px 12px"
    },
    body: {
      direction: "vertical",
      padding: "12px 12px 12px 12px",
      elements: [{
        tag: "markdown",
        content: $body,
        text_align: "left",
        text_size: "normal"
      }]
    }
  }')

# Send card message via lark-cli (capture stdout, log stderr)
send_result=$(lark-cli im +messages-send \
  --as bot \
  --user-id "$USER_OPEN_ID" \
  --content "$card" \
  --msg-type interactive 2>>"$LOG_FILE")

if [ -z "$send_result" ]; then
  log "ERROR: Failed to send message via lark-cli"
  exit 1
fi

# Extract message_id
msg_id=$(echo "$send_result" | jq -r '.data.message_id // empty' 2>/dev/null)

if [ -n "$msg_id" ]; then
  urgent_data=$(jq -nc --arg uid "$USER_OPEN_ID" '{"user_id_list": [$uid]}')
  lark-cli api PATCH "/open-apis/im/v1/messages/${msg_id}/urgent_app" \
    --as bot \
    --params '{"user_id_type":"open_id"}' \
    --data "$urgent_data" 2>>"$LOG_FILE" || log "WARN: Failed to mark message as urgent"
fi
