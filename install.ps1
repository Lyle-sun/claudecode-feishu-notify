# PowerShell: Install the Feishu notification hook into Claude Code (Windows)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$HookScript = Join-Path $ScriptDir "notify-feishu.ps1"
$SettingsFile = Join-Path $env:USERPROFILE ".claude\settings.json"
$HooksDir = Join-Path $env:USERPROFILE ".claude\hooks"

function Info($msg)  { Write-Host "✅ $msg" -ForegroundColor Green }
function Warn($msg)  { Write-Host "⚠️  $msg" -ForegroundColor Yellow }
function ErrorMsg($msg) { Write-Host "❌ $msg" -ForegroundColor Red; exit 1 }

# ── 1. Check dependencies ──

## lark-cli
if (-not (Get-Command lark-cli -ErrorAction SilentlyContinue)) {
    Warn "lark-cli not found. Installing..."
    if (Get-Command npm -ErrorAction SilentlyContinue) {
        npm install -g @larksuite/cli
        if (-not $?) { ErrorMsg "npm install -g failed." }
        Info "lark-cli installed"
    } else {
        ErrorMsg "npm not found. Please install Node.js first: https://nodejs.org"
    }
}

## jq (not needed for PowerShell version, but check for completeness)
if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
    Warn "jq not found. PowerShell version does not require jq, but bash version does."
}

# ── 2. Check lark-cli auth ──
$authResult = lark-cli auth status 2>$null
if (-not $authResult) {
    Warn "lark-cli not authenticated. Run: lark-cli auth login"
}

# ── 3. Check USER_OPEN_ID ──
if (-not (Test-Path $HookScript)) {
    ErrorMsg "notify-feishu.ps1 not found in $ScriptDir"
}

$hookContent = Get-Content $HookScript -Raw
if ($hookContent -match "ou_REPLACE_ME") {
    ErrorMsg "USER_OPEN_ID not configured in notify-feishu.ps1"
    Write-Host ""
    Write-Host "  1. Run: lark-cli contact +get-user --as user"
    Write-Host "  2. Then edit notify-feishu.ps1, replace ou_REPLACE_ME with your open_id"
    Write-Host ""
    exit 1
}

# ── 4. Deploy hook script ──
if (-not (Test-Path $HooksDir)) { New-Item -ItemType Directory -Path $HooksDir -Force | Out-Null }
Copy-Item $HookScript (Join-Path $HooksDir "notify-feishu.ps1") -Force
Info "Hook script deployed to $HooksDir\notify-feishu.ps1"

# ── 5. Configure hooks in settings.json ──
if (-not (Test-Path $SettingsFile)) {
    if (-not (Test-Path (Split-Path $SettingsFile))) {
        New-Item -ItemType Directory -Path (Split-Path $SettingsFile) -Force | Out-Null
    }
    Set-Content $SettingsFile "{}"
}

# Backup settings.json
Copy-Item $SettingsFile "${SettingsFile}.bak"

$hookCommand = Join-Path $HooksDir "notify-feishu.ps1"

$settings = Get-Content $SettingsFile -Raw | ConvertFrom-Json

$stopHook = @(
    @{
        matcher = ""
        hooks = @(@{ type = "command"; command = $hookCommand })
    }
)

$permHook = @(
    @{
        matcher = "permission_prompt"
        hooks = @(@{ type = "command"; command = $hookCommand })
    }
)

$idleHook = @(
    @{
        matcher = "idle_prompt"
        hooks = @(@{ type = "command"; command = $hookCommand })
    }
)

$notificationHooks = @($permHook, $idleHook)

if (-not $settings.hooks) {
    $settings | Add-Member -NotePropertyName "hooks" -NotePropertyValue @{} -Force
}

$settings.hooks | Add-Member -NotePropertyName "Stop" -NotePropertyValue $stopHook -Force
$settings.hooks | Add-Member -NotePropertyName "Notification" -NotePropertyValue $notificationHooks -Force

$settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsFile

Info "Hooks configured in settings.json"
Write-Host "  Stop → notify on task completion (green card)"
Write-Host "  Notification (permission_prompt) → notify when confirmation needed (orange card)"
Write-Host "  Notification (idle_prompt) → notify when waiting idle (blue card)"

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "  🎉 Installation complete!"
Write-Host "  Restart Claude Code for hooks to take effect."
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"