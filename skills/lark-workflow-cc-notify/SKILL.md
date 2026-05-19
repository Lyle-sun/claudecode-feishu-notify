---
name: lark-workflow-cc-notify
version: 1.0.0
description: "Claude Code 飞书通知：任务完成或需要确认时，通过飞书私聊卡片消息+加急提醒。当用户说'配置通知'、'飞书通知'、'cc通知'、'通知我'时使用。"
---

# Claude Code 飞书通知

通过飞书私聊卡片消息 + 加急，在 Claude Code 任务完成或需要确认时通知你。

## 适用场景

- "配置飞书通知" / "Claude Code 完成后通知我"
- "飞书通知" / "cc通知" / "通知我"
- "帮我设置 Claude Code hooks"

## 前置条件

- lark-cli 已安装并完成认证（`lark-cli auth login`）
- 飞书应用需开通权限：`im:message`（发送消息）、`im:message.urgent:app_send`（加急）
- 飞书应用需启用**机器人**能力
- macOS/Linux 需安装 `jq` 和 `python3`

## 安装

1. 修改 `notify-feishu.sh`（macOS/Linux）或 `notify-feishu.ps1`（Windows）中的 `USER_OPEN_ID`
   - 获取方式：`lark-cli contact +get-user --as user`
2. 运行安装脚本：
   - macOS/Linux：`chmod +x install.sh && ./install.sh`
   - Windows PowerShell：`Set-ExecutionPolicy RemoteSigned -Scope CurrentUser; .\install.ps1`
3. 重启 Claude Code 会话

详细步骤见 [README.md](../README.md)。

## Hook 事件

| 事件 | Matcher | 卡片颜色 | 触发时机 |
|------|---------|---------|---------|
| Stop | (all) | 绿色 | Claude Code 完成一个 turn |
| Notification | permission_prompt | 橙色 | 需要用户确认操作 |
| Notification | idle_prompt | 蓝色 | Claude Code 空闲等待 |

## 工作原理

1. Claude Code hooks 在事件触发时调用通知脚本
2. 脚本从 stdin 读取事件 JSON，根据事件类型生成飞书卡片内容
3. 通过 `lark-cli im +messages-send --msg-type interactive` 发送飞书卡片私聊消息
4. 从发送结果提取 `message_id`，调用 `PATCH /open-apis/im/v1/messages/{message_id}/urgent_app` 加急

## 权限

| 操作 | 所需 scope |
|------|-----------|
| 发送私聊消息 | `im:message` |
| 应用内加急 | `im:message.urgent:app_send` |

## 卸载

编辑 `~/.claude/settings.json`，移除 `hooks` 中的 `Stop` 和 `Notification` 条目。
