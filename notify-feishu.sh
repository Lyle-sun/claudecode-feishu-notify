#!/usr/bin/env bash
# Claude Code → Feishu notification hook
# Sends a card message with urgent (加急) when Claude Code completes a task or needs attention.

set -euo pipefail

USER_OPEN_ID="ou_REPLACE_ME"
LOG_FILE="$HOME/.claude/hooks/cc-notify.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null || true; }

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Validate USER_OPEN_ID (check prefix pattern, not literal value)
if [[ "$USER_OPEN_ID" == "ou_REPLACE"* ]]; then
  echo "[cc-notify] USER_OPEN_ID not configured. Edit this script and set your open_id." >&2
  exit 1
fi

input=$(cat)

event=$(echo "$input" | jq -r '.hook_event_name // "unknown"')

case "$event" in
  Stop)
    reason=$(echo "$input" | jq -r '.stop_reason // "unknown"')
    title="✅ Claude Code 任务完成"
    color="green"
    body="**stop_reason**: ${reason}"
    ;;
  Notification)
    msg=$(echo "$input" | jq -r '.message // "需要关注"')
    matcher=$(echo "$input" | jq -r '.matcher // ""')
    case "$matcher" in
      permission_prompt)
        title="⚠️ Claude Code 需要确认"
        color="orange"
        ;;
      idle_prompt)
        title="⏳ Claude Code 等待中"
        color="blue"
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
    body=$(echo "$input" | jq -r '.message // .stop_reason // "未知事件"')
    ;;
esac

card=$(jq -nc \
  --arg title "$title" \
  --arg color "$color" \
  --arg body "$body" \
  '{
    config: {wide_screen_mode: true},
    header: {
      template: $color,
      title: {tag: "plain_text", content: $title}
    },
    elements: [
      {tag: "div", text: {tag: "lark_md", content: $body}}
    ]
  }')

# Send card message via lark-cli (capture stdout, log stderr)
send_result=$(lark-cli im +messages-send \
  --as bot \
  --user-id "$USER_OPEN_ID" \
  --content "$card" \
  --msg-type interactive 2>"$LOG_FILE")

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