#!/usr/bin/env bash
# Install the Feishu notification hook into Claude Code settings

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_SCRIPT="${SCRIPT_DIR}/notify-feishu.sh"
SETTINGS_FILE="$HOME/.claude/settings.json"

if [ ! -f "$HOOK_SCRIPT" ]; then
  echo "Error: notify-feishu.sh not found in $SCRIPT_DIR"
  exit 1
fi

chmod +x "$HOOK_SCRIPT"

if [ ! -f "$SETTINGS_FILE" ]; then
  echo "Error: Claude Code settings not found at $SETTINGS_FILE"
  exit 1
fi

# Use python3 to merge hooks into settings.json (preserves existing config)
python3 -c "
import json, sys

with open('$SETTINGS_FILE', 'r') as f:
    settings = json.load(f)

hook_command = '$HOOK_SCRIPT'

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

print('Hooks installed successfully!')
print('  Stop → notify on task completion')
print('  Notification (permission_prompt) → notify when confirmation needed')
print('  Notification (idle_prompt) → notify when waiting idle')
"
