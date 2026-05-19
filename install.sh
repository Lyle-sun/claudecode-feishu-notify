#!/usr/bin/env bash
# Install the Feishu notification hook into Claude Code

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_SCRIPT="${SCRIPT_DIR}/notify-feishu.sh"
SETTINGS_FILE="$HOME/.claude/settings.json"
HOOKS_DIR="$HOME/.claude/hooks"

# 0. Check and install dependencies
## lark-cli
if ! command -v lark-cli &>/dev/null; then
  echo "⚠️  lark-cli not found. Installing..."
  if command -v npm &>/dev/null; then
    npm install -g @larksuite/cli
    echo "✅ lark-cli installed"
  else
    echo "❌ npm not found. Please install Node.js first: https://nodejs.org"
    exit 1
  fi
fi

## jq
if ! command -v jq &>/dev/null; then
  echo "⚠️  jq not found. Installing..."
  if command -v brew &>/dev/null; then
    brew install jq
    echo "✅ jq installed"
  elif command -v apt-get &>/dev/null; then
    sudo apt-get install -y jq
    echo "✅ jq installed"
  else
    echo "❌ Cannot auto-install jq. Please install manually: https://jqlang.github.io/jq/download/"
    exit 1
  fi
fi

# 1. Check lark-cli auth
if ! lark-cli auth status &>/dev/null; then
  echo "⚠️  lark-cli not authenticated. Run: lark-cli auth login"
  echo "   See README.md Step 2-3 for details."
fi

# 2. Check USER_OPEN_ID
if grep -q "ou_REPLACE_ME" "$HOOK_SCRIPT"; then
  echo "⚠️  USER_OPEN_ID not configured in notify-feishu.sh"
  echo "   Run: lark-cli contact +get-user --as user"
  echo "   Then replace ou_REPLACE_ME with your open_id"
  exit 1
fi

# 3. Deploy hook script
if [ ! -f "$HOOK_SCRIPT" ]; then
  echo "Error: notify-feishu.sh not found in $SCRIPT_DIR"
  exit 1
fi

mkdir -p "$HOOKS_DIR"
cp "$HOOK_SCRIPT" "$HOOKS_DIR/notify-feishu.sh"
chmod +x "$HOOKS_DIR/notify-feishu.sh"
echo "✅ Hook script deployed to $HOOKS_DIR/notify-feishu.sh"

# 4. Configure hooks in settings.json
if [ ! -f "$SETTINGS_FILE" ]; then
  echo "Error: Claude Code settings not found at $SETTINGS_FILE"
  exit 1
fi

python3 -c "
import json

with open('$SETTINGS_FILE', 'r') as f:
    settings = json.load(f)

hook_command = '$HOOKS_DIR/notify-feishu.sh'

hooks_config = {
    'Stop': [{'matcher': '', 'hooks': [{'type': 'command', 'command': hook_command}]}],
    'Notification': [
        {'matcher': 'permission_prompt', 'hooks': [{'type': 'command', 'command': hook_command}]},
        {'matcher': 'idle_prompt', 'hooks': [{'type': 'command', 'command': hook_command}]}
    ]
}

if 'hooks' not in settings:
    settings['hooks'] = {}

for event, config in hooks_config.items():
    settings['hooks'][event] = config

with open('$SETTINGS_FILE', 'w') as f:
    json.dump(settings, f, indent=2, ensure_ascii=False)
    f.write('\n')

print('✅ Hooks configured in settings.json')
print('  Stop → notify on task completion (green card)')
print('  Notification (permission_prompt) → notify when confirmation needed (orange card)')
print('  Notification (idle_prompt) → notify when waiting idle (blue card)')
"
