#!/usr/bin/env bash
# Claude Code → Feishu notification hook
# Sends a private message with urgent (加急) when Claude Code completes a task or needs attention.

set -euo pipefail

USER_OPEN_ID="ou_f81ddcc56b518ca1b0df3ce94db740dc"

input=$(cat)

event=$(echo "$input" | jq -r '.hook_event_name // "unknown"')

case "$event" in
  Stop)
    reason=$(echo "$input" | jq -r '.stop_reason // "unknown"')
    title="✅ Claude Code 任务完成"
    body="stop_reason: ${reason}"
    ;;
  Notification)
    msg=$(echo "$input" | jq -r '.message // "需要关注"')
    matcher=$(echo "$input" | jq -r '.matcher // ""')
    case "$matcher" in
      permission_prompt)
        title="⚠️ Claude Code 需要确认"
        ;;
      idle_prompt)
        title="⏳ Claude Code 等待中"
        ;;
      *)
        title="🔔 Claude Code 通知"
        ;;
    esac
    body="$msg"
    ;;
  *)
    title="🔔 Claude Code"
    body=$(echo "$input" | jq -r '.message // .stop_reason // "未知事件"')
    ;;
esac

text="${title}\n${body}"

# Send message via lark-cli
send_result=$(lark-cli im +messages-send \
  --as bot \
  --user-id "$USER_OPEN_ID" \
  --text "$text" 2>&1) || true

# Extract message_id and mark as urgent
msg_id=$(echo "$send_result" | jq -r '.data.message_id // empty' 2>/dev/null)

if [ -n "$msg_id" ]; then
  lark-cli api PATCH "/open-apis/im/v1/messages/${msg_id}/urgent_app" \
    --params "{\"user_id_type\":\"open_id\"}" \
    --data "{\"user_id_list\":[\"$USER_OPEN_ID\"]}" 2>/dev/null || true
fi
