---
name: lark-workflow-cc-notify
version: 1.0.0
description: "Claude Code 飞书通知：任务完成或需要确认时，通过飞书私聊卡片消息+加急提醒。当用户说'配置通知'、'飞书通知'、'cc通知'、'通知我'时使用。"
metadata:
  requires:
    bins: ["lark-cli", "jq"]
---

# Claude Code 飞书通知

> **前置条件：** 先阅读 [`../lark-shared/SKILL.md`](../lark-shared/SKILL.md)。

## 适用场景

- "配置飞书通知" / "Claude Code 完成后通知我"
- "飞书通知" / "cc通知" / "通知我"
- "帮我设置 Claude Code hooks"

## 前置条件

- 飞书应用需开通以下权限（开发者后台 → 权限管理）：
  - `im:message`（发送消息）
  - `im:message.urgent:app_send`（发送应用内加急）
- 飞书应用需启用**机器人**能力
- 系统需安装 `jq`

## 安装

### Step 1: 获取 open_id

```bash
lark-cli contact +get-user --as user
# 记录返回的 open_id (ou_xxx)
```

### Step 2: 部署 hook 脚本

将 `notify-feishu.sh` 放到 `~/.claude/hooks/` 目录，修改其中的 `USER_OPEN_ID` 为你的 open_id：

```bash
mkdir -p ~/.claude/hooks
cp notify-feishu.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/notify-feishu.sh
# 编辑 USER_OPEN_ID
```

### Step 3: 配置 hooks

在 `~/.claude/settings.json` 中添加 hooks 配置：

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/notify-feishu.sh"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "permission_prompt",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/notify-feishu.sh"
          }
        ]
      },
      {
        "matcher": "idle_prompt",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/notify-feishu.sh"
          }
        ]
      }
    ]
  }
}
```

### Step 4: 验证

```bash
echo '{"hook_event_name":"Stop","stop_reason":"end_turn"}' | ~/.claude/hooks/notify-feishu.sh
```

飞书应收到绿色卡片加急通知。

## Hook 事件

| 事件 | Matcher | 卡片颜色 | 触发时机 |
|------|---------|---------|---------|
| Stop | (all) | 绿色 | Claude Code 完成一个 turn |
| Notification | permission_prompt | 橙色 | 需要用户确认操作 |
| Notification | idle_prompt | 蓝色 | Claude Code 空闲等待 |

## 工作原理

1. Claude Code hooks 在事件触发时调用 `notify-feishu.sh`
2. 脚本从 stdin 读取事件 JSON，根据事件类型生成卡片内容
3. 通过 `lark-cli im +messages-send --msg-type interactive` 发送飞书卡片私聊消息
4. 从发送结果提取 `message_id`，调用 `PATCH /open-apis/im/v1/messages/{message_id}/urgent_app` 加急

## 权限

| 操作 | 所需 scope |
|------|-----------|
| 发送私聊消息 | `im:message` |
| 应用内加急 | `im:message.urgent:app_send` |

## 卸载

编辑 `~/.claude/settings.json`，移除 `hooks` 中的 `Stop` 和 `Notification` 条目。

## 参考

- [lark-shared](../lark-shared/SKILL.md) — 认证、权限（必读）
- [lark-im](../lark-im/SKILL.md) — 消息发送详细用法
