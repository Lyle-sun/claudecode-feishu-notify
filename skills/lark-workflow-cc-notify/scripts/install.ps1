# PowerShell: Install the Feishu notification hook into Claude Code (Windows)

$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$HookScript = Join-Path $ScriptDir "notify-feishu.ps1"
$SettingsFile = Join-Path $env:USERPROFILE ".claude\settings.json"
$HooksDir = Join-Path $env:USERPROFILE ".claude\hooks"

function Info($msg)  { Write-Host "✅ $msg" -ForegroundColor Green }
function Warn($msg)  { Write-Host "⚠️  $msg" -ForegroundColor Yellow }
function ErrorMsg($msg) { Write-Host "❌ $msg" -ForegroundColor Red; exit 1 }

# ── 1. Check dependencies ──

## Node.js / npm
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Warn "npm not found. Installing Node.js..."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements
        if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
            ErrorMsg "Node.js installed but npm not found. You may need to restart your shell."
        }
        Info "Node.js installed via winget"
    } else {
        ErrorMsg "Cannot auto-install Node.js. Please install manually: https://nodejs.org"
    }
}

## lark-cli
if (-not (Get-Command lark-cli -ErrorAction SilentlyContinue)) {
    Warn "lark-cli not found. Installing..."
    npm install -g @larksuite/cli
    if (-not $?) { ErrorMsg "npm install -g failed." }
    # Verify lark-cli is now available
    if (-not (Get-Command lark-cli -ErrorAction SilentlyContinue)) {
        ErrorMsg "lark-cli installed but not found in PATH. You may need to restart your shell."
    }
    Info "lark-cli installed"
}

# ── 2. Check lark-cli auth ──
$authResult = lark-cli auth status 2>$null
if (-not $authResult) {
    Warn "lark-cli not authenticated. Run: lark-cli auth login"
} else {
    try {
        $authObj = $authResult | ConvertFrom-Json
        $expiresAt = $authObj.expiresAt
        if ($expiresAt) {
            $expDate = [datetime]::Parse($expiresAt.Replace("Z","").Substring(0,19))
            if ($expDate -lt [datetime]::UtcNow) {
                Warn "lark-cli token expired at $expiresAt. Run: lark-cli auth login"
            }
        }
    } catch {
        # Could not parse auth status, skip expiry check
    }
}

# ── 3. Check CC_FEISHU_OPEN_ID ──
if (-not $env:CC_FEISHU_OPEN_ID) {
    ErrorMsg "CC_FEISHU_OPEN_ID not set."
    Write-Host ""
    Write-Host "  1. Run: lark-cli contact +get-user --as user"
    Write-Host "  2. Then set the environment variable:"
    Write-Host '     [Environment]::SetEnvironmentVariable("CC_FEISHU_OPEN_ID", "ou_YOUR_OPEN_ID", "User")'
    Write-Host ""
    exit 1
}

if ($env:CC_FEISHU_OPEN_ID -like "ou_REPLACE*") {
    ErrorMsg "CC_FEISHU_OPEN_ID still has placeholder value. Set your real open_id."
    exit 1
}

# ── 4. Deploy hook script ──
if (-not (Test-Path $HookScript)) {
    ErrorMsg "notify-feishu.ps1 not found in $ScriptDir"
}

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

# Backup settings.json with timestamp
$backupSuffix = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item $SettingsFile "${SettingsFile}.${backupSuffix}.bak"

$hookCommand = Join-Path $HooksDir "notify-feishu.ps1"

try {
    $settings = Get-Content $SettingsFile -Raw | ConvertFrom-Json
} catch {
    ErrorMsg "Failed to parse settings.json: $_"
}

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

$authHook = @(
    @{
        matcher = "auth_success"
        hooks = @(@{ type = "command"; command = $hookCommand })
    }
)

$notificationHooks = @($permHook, $idleHook, $authHook)

# Set hooks in settings (will replace existing Stop/Notification entries)
if (-not $settings.hooks) {
    $settings | Add-Member -NotePropertyName "hooks" -NotePropertyValue @{} -Force
}

# Warn if overwriting existing hooks with different commands
$existingStop = $settings.hooks.PSObject.Properties | Where-Object { $_.Name -eq "Stop" }
if ($existingStop) {
    foreach ($entry in $settings.hooks.Stop) {
        foreach ($h in $entry.hooks) {
            if ($h.command -and $h.command -ne $hookCommand) {
                Warn "Overwriting existing Stop hook: $($h.command)"
            }
        }
    }
}

$settings.hooks | Add-Member -NotePropertyName "Stop" -NotePropertyValue $stopHook -Force
$settings.hooks | Add-Member -NotePropertyName "Notification" -NotePropertyValue $notificationHooks -Force

try {
    $settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsFile
} catch {
    ErrorMsg "Failed to write settings.json: $_"
}

Info "Hooks configured in settings.json"
Write-Host "  Stop → notify on task completion (green card)"
Write-Host "  Notification (permission_prompt) → notify when confirmation needed (orange card)"
Write-Host "  Notification (idle_prompt) → notify when waiting idle (blue card)"
Write-Host "  Notification (auth_success) → notify on auth success (green card)"

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "  🎉 Installation complete!"
Write-Host "  Restart Claude Code for hooks to take effect."
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
