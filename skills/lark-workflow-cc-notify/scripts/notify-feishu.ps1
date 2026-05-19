# PowerShell: Claude Code → Feishu notification hook
# Sends a card message with urgent when Claude Code completes a task or needs attention.

$UserOpenId = if ($env:CC_FEISHU_OPEN_ID) { $env:CC_FEISHU_OPEN_ID } else { "ou_REPLACE_ME" }
$LogFile = Join-Path $env:USERPROFILE ".claude\hooks\cc-notify.log"

# Ensure log directory exists (before any log calls)
$logDir = Split-Path $LogFile
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force -ErrorAction SilentlyContinue | Out-Null }

function Log($msg) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$ts] $msg" -ErrorAction SilentlyContinue
}

# Mute: set CC_FEISHU_NOTIFY=0 to suppress all notifications
if ($env:CC_FEISHU_NOTIFY -eq "0") { exit 0 }

# Validate USER_OPEN_ID
if ($UserOpenId -like "ou_REPLACE*") {
    Write-Error "[cc-notify] CC_FEISHU_OPEN_ID not configured. Set the environment variable with your open_id."
    exit 1
}

function Read-LastMessageFromTranscript($transcriptPath) {
    try {
        $expanded = $transcriptPath.Replace("~", $env:USERPROFILE)
        if (-not (Test-Path $expanded)) { return "" }
        $lines = Get-Content $expanded -Tail 100 -ErrorAction SilentlyContinue
        $lastText = ""
        foreach ($line in $lines) {
            try {
                $obj = $line | ConvertFrom-Json
                if ($obj.message.content) {
                    foreach ($item in $obj.message.content) {
                        if ($item.type -eq "text" -and $item.text) {
                            $lastText = $item.text
                        }
                    }
                }
            } catch { continue }
        }
        return $lastText
    } catch { return "" }
}

# Read stdin: try Console.In first (Claude Code hooks), then $input (PowerShell pipeline)
$raw = $null
try {
    $raw = [System.Console]::In.ReadToEnd()
} catch { }
if (-not $raw) {
    try {
        $raw = (@($input) | Out-String)
    } catch { }
}

$parsed = $null
if ($raw) {
    try { $parsed = $raw | ConvertFrom-Json } catch { $parsed = $null }
}

$event = if ($parsed) { $parsed.hook_event_name } else { "unknown" }
if (-not $event) { $event = "unknown" }

switch ($event) {
    "Stop" {
        $msg = if ($parsed) { $parsed.last_assistant_message } else { $null }
        $cwd = if ($parsed) { $parsed.cwd } else { $null }
        $transcriptPath = if ($parsed) { $parsed.transcript_path } else { $null }

        # Fallback: read last assistant message from transcript JSONL
        if (-not $msg -and $transcriptPath) {
            $msg = Read-LastMessageFromTranscript $transcriptPath
        }

        if (-not $msg) { $msg = "任务完成" }
        if ($msg.Length -gt 1000) { $msg = $msg.Substring(0, 1000) + "..." }

        # Error detection (case-insensitive via -like)
        $isError = $false
        $errorKeywords = @("API Error:", "Error:", "FAILED", "Traceback")
        foreach ($kw in $errorKeywords) {
            if ($msg -like "*$kw*") { $isError = $true; break }
        }

        if ($isError) {
            $title = "❌ Claude Code 任务异常"
            $color = "red"
        } else {
            $title = "✅ Claude Code 任务完成"
            $color = "green"
        }

        if ($cwd) {
            $projectName = Split-Path $cwd -Leaf
            $body = "<font size=2>📂 $projectName</font>`n$msg"
        } else {
            $body = $msg
        }
    }
    "Notification" {
        $msg = if ($parsed) { $parsed.message } else { "需要关注" }
        if (-not $msg) { $msg = "需要关注" }
        $notifType = if ($parsed) { $parsed.notification_type } else { "" }
        if (-not $notifType) { $notifType = "" }
        switch ($notifType) {
            "permission_prompt" { $title = "⚠️ Claude Code 需要确认"; $color = "orange" }
            "idle_prompt"       { $title = "⏳ Claude Code 等待中"; $color = "blue" }
            "auth_success"      { $title = "✅ Claude Code 认证成功"; $color = "green" }
            default             { $title = "🔔 Claude Code 通知"; $color = "purple" }
        }
        $body = $msg
    }
    default {
        $title = "🔔 Claude Code"
        $color = "grey"
        $body = if ($parsed) { $parsed.message } else { $null }
        if (-not $body) { $body = if ($parsed) { $parsed.last_assistant_message } else { $null } }
        if (-not $body) { $body = "未知事件" }
    }
}

# Feishu card 2.0 format
$card = @{
    schema = "2.0"
    header = @{
        title    = @{ tag = "plain_text"; content = $title }
        template = $color
        padding  = "12px 12px 12px 12px"
    }
    body = @{
        direction = "vertical"
        padding   = "12px 12px 12px 12px"
        elements  = @(
            @{
                tag       = "markdown"
                content   = $body
                text_align = "left"
                text_size  = "normal"
            }
        )
    }
} | ConvertTo-Json -Depth 5 -Compress

# Write card JSON to temp file to avoid PowerShell quoting issues with external commands
$tempFile = Join-Path $env:TEMP "cc-notify-card-$(Get-Random).json"
try {
    Set-Content -Path $tempFile -Value $card -Encoding UTF8

    # Send card message via lark-cli, reading content from temp file
    $cardContent = Get-Content -Path $tempFile -Raw
    $sendResult = & lark-cli im +messages-send --as bot --user-id $UserOpenId --content $cardContent --msg-type interactive 2>$null

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
        & lark-cli api PATCH "/open-apis/im/v1/messages/$msgId/urgent_app" --as bot --params '{"user_id_type":"open_id"}' --data $urgentData 2>$null
        if (-not $?) {
            Log "WARN: Failed to mark message as urgent"
        }
    }
} finally {
    Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
}
