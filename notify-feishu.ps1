# PowerShell: Claude Code → Feishu notification hook
# Sends a card message with urgent when Claude Code completes a task or needs attention.

$UserOpenId = "ou_REPLACE_ME"
$LogFile = Join-Path $env:USERPROFILE ".claude\hooks\cc-notify.log"

if ($UserOpenId -like "ou_REPLACE*") {
    Write-Error "[cc-notify] USER_OPEN_ID not configured. Edit this script and set your open_id."
    exit 1
}

function Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$ts] $msg" -ErrorAction SilentlyContinue
}

# Read and parse stdin JSON once
$inputJson = $null
$parsed = $null
try {
    $inputJson = [System.Console]::In.ReadToEnd()
    if ($inputJson) {
        $parsed = $inputJson | ConvertFrom-Json
    }
} catch {
    $parsed = $null
}

$event = if ($parsed) { $parsed.hook_event_name } else { "unknown" }
if (-not $event) { $event = "unknown" }

switch ($event) {
    "Stop" {
        $reason = if ($parsed) { $parsed.stop_reason } else { "unknown" }
        if (-not $reason) { $reason = "unknown" }
        $title = "✅ Claude Code 任务完成"
        $color = "green"
        $body = "**stop_reason**: $reason"
    }
    "Notification" {
        $msg = if ($parsed) { $parsed.message } else { "需要关注" }
        if (-not $msg) { $msg = "需要关注" }
        $matcher = if ($parsed) { $parsed.matcher } else { "" }
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
        $body = if ($parsed) { $parsed.message } else { "未知事件" }
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

# Write card JSON to temp file to avoid PowerShell quoting issues with external commands
$tempFile = Join-Path $env:TEMP "cc-notify-card-$(Get-Random).json"
try {
    Set-Content -Path $tempFile -Value $card -Encoding UTF8

    # Send card message via lark-cli, reading content from temp file
    $cardContent = Get-Content -Path $tempFile -Raw
    $sendResult = & lark-cli im +messages-send --as bot --user-id $UserOpenId --content $cardContent --msg-type interactive 2>&1

    if (-not $sendResult) {
        Log "ERROR: Failed to send message via lark-cli"
        exit 1
    }

    # Extract message_id
    $msgId = $null
    try {
        $sendObj = $sendResult | ConvertFrom-Json
        $msgId = $sendObj.data.message_id
    } catch {
        Log "WARN: Could not parse send result as JSON"
    }

    if ($msgId) {
        $urgentData = @{ user_id_list = @($UserOpenId) } | ConvertTo-Json -Compress
        & lark-cli api PATCH "/open-apis/im/v1/messages/$msgId/urgent_app" --as bot --params '{"user_id_type":"open_id"}' --data $urgentData 2>&1 | Out-Null
        if (-not $?) {
            Log "WARN: Failed to mark message as urgent"
        }
    }
} finally {
    Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
}