# PowerShell: Claude Code → Feishu notification hook
# Sends a card message with urgent when Claude Code completes a task or needs attention.

$UserOpenId = "ou_REPLACE_ME"

if ($UserOpenId -like "ou_REPLACE*") {
    Write-Error "[cc-notify] USER_OPEN_ID not configured. Edit this script and set your open_id."
    exit 1
}

$inputJson = [System.Console]::In.ReadToEnd()
$event = if ($inputJson) { ($inputJson | ConvertFrom-Json).hook_event_name } else { "unknown" }
if (-not $event) { $event = "unknown" }

switch ($event) {
    "Stop" {
        $reason = if ($inputJson) { ($inputJson | ConvertFrom-Json).stop_reason } else { "unknown" }
        if (-not $reason) { $reason = "unknown" }
        $title = "✅ Claude Code 任务完成"
        $color = "green"
        $body = "**stop_reason**: $reason"
    }
    "Notification" {
        $msg = if ($inputJson) { ($inputJson | ConvertFrom-Json).message } else { "需要关注" }
        if (-not $msg) { $msg = "需要关注" }
        $matcher = if ($inputJson) { ($inputJson | ConvertFrom-Json).matcher } else { "" }
        if (-not $matcher) { $matcher = "" }
        switch ($matcher) {
            "permission_prompt" { $title = "⚠️ Claude Code 需要确认"; $color = "orange" }
            "idle_prompt"       { $title = "⏳ Claude Code 等待中"; $color = "blue" }
            default             { $title = "🔔 Claude Code 通知"; $color = "purple" }
        }
        $body = $msg
    }
    default {
        $title = "🔔 Claude Code"
        $color = "grey"
        $body = if ($inputJson) { ($inputJson | ConvertFrom-Json).message } else { "未知事件" }
        if (-not $body) { $body = "未知事件" }
    }
}

$card = @{
    config = @{ wide_screen_mode = $true }
    header = @{
        template = $color
        title    = @{ tag = "plain_text"; content = $title }
    }
    elements = @(
        @{ tag = "div"; text = @{ tag = "lark_md"; content = $body } }
    )
} | ConvertTo-Json -Depth 5 -Compress

# Send card message via lark-cli
$sendResult = lark-cli im +messages-send --as bot --user-id $UserOpenId --content $card --msg-type interactive 2>$null

if (-not $sendResult) {
    Write-Error "[cc-notify] Failed to send message via lark-cli"
    exit 1
}

$msgId = ($sendResult | ConvertFrom-Json).data.message_id

if ($msgId) {
    $urgentData = @{ user_id_list = @($UserOpenId) } | ConvertTo-Json -Compress
    lark-cli api PATCH "/open-apis/im/v1/messages/$msgId/urgent_app" --as bot --params '{"user_id_type":"open_id"}' --data $urgentData 2>$null
    if (-not $?) {
        Write-Error "[cc-notify] Failed to mark message as urgent"
    }
}