#!/usr/bin/env bash
# Install the Feishu notification hook into Claude Code
# Supports macOS and Linux. For Windows, use install.ps1 instead.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_SCRIPT="${SCRIPT_DIR}/notify-feishu.sh"
SETTINGS_FILE="$HOME/.claude/settings.json"
HOOKS_DIR="$HOME/.claude/hooks"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo "${GREEN}✅ $1${NC}"; }
warn()  { echo "${YELLOW}⚠️  $1${NC}"; }
error() { echo "${RED}❌ $1${NC}"; }

# ──────────────────────────────────────────────
# 0. Platform check
# ──────────────────────────────────────────────
OS="$(uname -s 2>/dev/null || echo unknown)"
if [ "$OS" = "MINGW" ] || [ "$OS" = "MSYS" ] || [ "$OS" = "CYGWIN" ]; then
  error "Windows detected. Please use install.ps1 instead."
  exit 1
fi

# ──────────────────────────────────────────────
# 1. Check and install dependencies
# ──────────────────────────────────────────────

## python3
if ! command -v python3 &>/dev/null; then
  error "python3 not found. Please install Python 3 first: https://www.python.org/downloads/"
  exit 1
fi

## Node.js / npm
if ! command -v npm &>/dev/null; then
  warn "npm not found. Installing Node.js..."
  if command -v brew &>/dev/null; then
    brew install node && info "Node.js installed via brew"
  elif command -v apt-get &>/dev/null; then
    sudo apt-get update -y && sudo apt-get install -y nodejs npm && info "Node.js installed via apt-get"
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y nodejs npm && info "Node.js installed via dnf"
  elif command -v yum &>/dev/null; then
    sudo yum install -y nodejs npm && info "Node.js installed via yum"
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm nodejs npm && info "Node.js installed via pacman"
  else
    error "Cannot auto-install Node.js. Please install manually: https://nodejs.org"
    exit 1
  fi
  # Verify npm is now available
  if ! command -v npm &>/dev/null; then
    error "Node.js installed but npm not found in PATH. You may need to restart your shell."
    exit 1
  fi
fi

## lark-cli
if ! command -v lark-cli &>/dev/null; then
  warn "lark-cli not found. Installing..."
  if npm install -g @larksuite/cli; then
    # Verify lark-cli is now available
    if ! command -v lark-cli &>/dev/null; then
      error "lark-cli installed but not found in PATH. You may need to restart your shell or run: npm config get prefix"
      exit 1
    fi
    info "lark-cli installed"
  else
    error "npm install -g failed. You may need: sudo npm install -g @larksuite/cli"
    exit 1
  fi
fi

## jq
if ! command -v jq &>/dev/null; then
  warn "jq not found. Installing..."
  if command -v brew &>/dev/null; then
    brew install jq && info "jq installed via brew"
  elif command -v apt-get &>/dev/null; then
    sudo apt-get install -y jq && info "jq installed via apt-get"
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y jq && info "jq installed via dnf"
  elif command -v yum &>/dev/null; then
    sudo yum install -y jq && info "jq installed via yum"
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm jq && info "jq installed via pacman"
  else
    error "Cannot auto-install jq. Please install manually: https://jqlang.github.io/jq/download/"
    exit 1
  fi
fi

# ──────────────────────────────────────────────
# 2. Check lark-cli auth
# ──────────────────────────────────────────────
auth_output=$(lark-cli auth status 2>/dev/null || true)
if [ -z "$auth_output" ]; then
  warn "lark-cli not authenticated. Run: lark-cli auth login"
  warn "See README.md Step 2-3 for details."
else
  expires=$(echo "$auth_output" | jq -r '.expiresAt // empty' 2>/dev/null)
  if [ -n "$expires" ]; then
    is_expired=$(python3 -c "
from datetime import datetime, timezone
import sys
try:
    ts = '${expires%%+*}'.replace('Z','')
    exp = datetime.fromisoformat(ts).replace(tzinfo=timezone.utc)
    print('yes' if exp < datetime.now(timezone.utc) else 'no')
except: print('unknown')
" 2>/dev/null || echo "unknown")
    if [ "$is_expired" = "yes" ]; then
      warn "lark-cli token expired at $expires. Run: lark-cli auth login"
    fi
  fi
fi

# ──────────────────────────────────────────────
# 3. Check CC_FEISHU_OPEN_ID
# ──────────────────────────────────────────────
if [ -z "${CC_FEISHU_OPEN_ID:-}" ]; then
  error "CC_FEISHU_OPEN_ID not set."
  echo ""
  echo "  1. Run: lark-cli contact +get-user --as user"
  echo "  2. Then add to your shell profile (~/.zshrc or ~/.bashrc):"
  echo "     export CC_FEISHU_OPEN_ID=\"ou_YOUR_OPEN_ID\""
  echo ""
  exit 1
fi

if [[ "$CC_FEISHU_OPEN_ID" == "ou_REPLACE"* ]]; then
  error "CC_FEISHU_OPEN_ID still has placeholder value. Set your real open_id."
  exit 1
fi

# ──────────────────────────────────────────────
# 4. Deploy hook script
# ──────────────────────────────────────────────
if [ ! -f "$HOOK_SCRIPT" ]; then
  error "notify-feishu.sh not found in $SCRIPT_DIR"
  exit 1
fi

mkdir -p "$HOOKS_DIR"
cp "$HOOK_SCRIPT" "$HOOKS_DIR/notify-feishu.sh"
chmod +x "$HOOKS_DIR/notify-feishu.sh"
info "Hook script deployed to $HOOKS_DIR/notify-feishu.sh"

# ──────────────────────────────────────────────
# 5. Configure hooks in settings.json
# ──────────────────────────────────────────────
if [ ! -f "$SETTINGS_FILE" ]; then
  mkdir -p "$(dirname "$SETTINGS_FILE")"
  echo '{}' > "$SETTINGS_FILE"
fi

# Backup settings.json with timestamp
backup_suffix=$(date '+%Y%m%d-%H%M%S')
cp "$SETTINGS_FILE" "${SETTINGS_FILE}.${backup_suffix}.bak"

# Use environment variables to pass paths into Python safely
export _CC_NOTIFY_SETTINGS="$SETTINGS_FILE"
export _CC_NOTIFY_HOOK="$HOOKS_DIR/notify-feishu.sh"

python3 << 'PYEOF'
import json, os

settings_file = os.environ["_CC_NOTIFY_SETTINGS"]
hook_command = os.environ["_CC_NOTIFY_HOOK"]

with open(settings_file, 'r') as f:
    settings = json.load(f)

hooks_config = {
    'Stop': [{'matcher': '', 'hooks': [{'type': 'command', 'command': hook_command}]}],
    'Notification': [
        {'matcher': 'permission_prompt', 'hooks': [{'type': 'command', 'command': hook_command}]},
        {'matcher': 'idle_prompt', 'hooks': [{'type': 'command', 'command': hook_command}]},
        {'matcher': 'auth_success', 'hooks': [{'type': 'command', 'command': hook_command}]}
    ]
}

if 'hooks' not in settings:
    settings['hooks'] = {}

# Warn if overwriting existing hooks with different commands
for event, config in hooks_config.items():
    existing = settings.get('hooks', {}).get(event)
    if existing:
        for entry in existing:
            for h in entry.get('hooks', []):
                if h.get('command') and h['command'] != hook_command:
                    print(f'⚠️  Overwriting existing {event} hook: {h["command"]}')

for event, config in hooks_config.items():
    settings['hooks'][event] = config

with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write('\n')

print('✅ Hooks configured in settings.json')
print('  Stop → notify on task completion (green card)')
print('  Notification (permission_prompt) → notify when confirmation needed (orange card)')
print('  Notification (idle_prompt) → notify when waiting idle (blue card)')
print('  Notification (auth_success) → notify on auth success (green card)')
PYEOF

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🎉 Installation complete!"
echo "  Restart Claude Code for hooks to take effect."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
