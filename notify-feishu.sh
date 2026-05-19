#!/usr/bin/env bash
# Claude Code → Feishu notification hook
# Sends a card message with urgent (加急) when Claude Code completes a task or needs attention.

set -euo pipefail

USER_OPEN_ID="ou_f81ddcc56b518ca1b0df3ce94db740dc"

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

# Send card message via lark-cli
send_result=$(lark-cli im +messages-send \
  --as bot \
  --user-id "$USER_OPEN_ID" \
  --content "$card" \
  --msg-type interactive 2>&1) || true

# Extract message_id and mark as urgent
msg_id=$(echo "$send_result" | jq -r '.data.message_id // empty' 2>/dev/null)

if [ -n "$msg_id" ]; then
  lark-cli api PATCH "/open-apis/im/v1/messages/${msg_id}/urgent_app" \
    --as bot \
    --params '{"user_id_type":"open_id"}' \
    --data "{\"user_id_list\":[\"$USER_OPEN_ID\"]}" >/dev/null 2>&1 || true
fi
