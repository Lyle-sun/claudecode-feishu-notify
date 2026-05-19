#!/usr/bin/env bash
# Install the Feishu notification hook and skill into Claude Code

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_SCRIPT="${SCRIPT_DIR}/notify-feishu.sh"
SKILL_DIR="${SCRIPT_DIR}/skills/lark-workflow-cc-notify"
SETTINGS_FILE="$HOME/.claude/settings.json"
HOOKS_DIR="$HOME/.claude/hooks"
SKILLS_DIR="$HOME/.claude/skills"

# 1. Deploy hook script
if [ ! -f "$HOOK_SCRIPT" ]; then
  echo "Error: notify-feishu.sh not found in $SCRIPT_DIR"
  exit 1
fi

mkdir -p "$HOOKS_DIR"
cp "$HOOK_SCRIPT" "$HOOKS_DIR/notify-feishu.sh"
chmod +x "$HOOKS_DIR/notify-feishu.sh"
echo "✅ Hook script deployed to $HOOKS_DIR/notify-feishu.sh"

# 2. Deploy skill
if [ -d "$SKILL_DIR" ]; then
  mkdir -p "$SKILLS_DIR/lark-workflow-cc-notify"
  cp "$SKILL_DIR/SKILL.md" "$SKILLS_DIR/lark-workflow-cc-notify/SKILL.md"
  echo "✅ Skill deployed to $SKILLS_DIR/lark-workflow-cc-notify/"
fi

# 3. Configure hooks in settings.json
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
