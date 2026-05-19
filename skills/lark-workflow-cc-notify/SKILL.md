---
name: lark-workflow-cc-notify
version: 1.2.0
description: "Claude Code 飞书通知：任务完成或需要确认时，通过飞书私聊卡片消息+加急提醒。当用户说'配置通知'、'飞书通知'、'cc通知'、'通知我'时使用。"
metadata:
  requires:
    bins: ["lark-cli"]
---

# Claude Code 飞书通知

通过飞书私聊卡片消息 + 加急，在 Claude Code 任务完成或需要确认时通知你。

## 适用人群

长时间使用 Claude Code 且需要离开终端的开发者。

## 适用场景

- "配置飞书通知" / "Claude Code 完成后通知我"
- "飞书通知" / "cc通知" / "通知我"
- "帮我设置 Claude Code hooks"

## 前置条件

- lark-cli 已安装并完成认证（`lark-cli auth login`）
- 飞书应用需开通权限：`im:message`（发送消息）、`im:message.urgent:app_send`（加急）
- 飞书应用需启用**机器人**能力
- 环境变量 `CC_FEISHU_OPEN_ID` 已设置（你的飞书 open_id）
- macOS/Linux 需安装 `jq` 和 `python3`（install.sh 可自动安装）
- Windows 无需 jq/python3（PowerShell 原生 JSON 支持）

## 安装

1. 获取你的 open_id：
   ```bash
   lark-cli contact +get-user --as user
   ```

2. 设置环境变量：
   - macOS/Linux：`export CC_FEISHU_OPEN_ID="ou_xxxx"`（加到 `~/.zshrc` 或 `~/.bashrc`）
   - Windows：`[Environment]::SetEnvironmentVariable("CC_FEISHU_OPEN_ID", "ou_xxxx", "User")`

3. 运行安装脚本：
   - macOS/Linux：`chmod +x install.sh && ./install.sh`
   - Windows PowerShell：`Set-ExecutionPolicy RemoteSigned -Scope CurrentUser; .\install.ps1`

4. 重启 Claude Code 会话

详细步骤见 [README.md](../README.md)。

## 环境变量

| 变量 | 必填 | 说明 |
|------|------|------|
| `CC_FEISHU_OPEN_ID` | 是 | 你的飞书 open_id |
| `CC_FEISHU_NOTIFY` | 否 | 设为 `0` 时关闭通知（默认 `1` 开启） |

## Hook 事件

| 事件 | Matcher | 卡片颜色 | 触发时机 |
|------|---------|---------|---------|
| Stop | (all) | 绿色 / 红色（异常） | Claude Code 完成一个 turn |
| Notification | permission_prompt | 橙色 | 需要用户确认操作 |
| Notification | idle_prompt | 蓝色 | Claude Code 空闲等待 |
| Notification | auth_success | 绿色 | 认证成功 |

## 权限

| 操作 | 所需 scope |
|------|-----------|
| 发送私聊消息 | `im:message` |
| 应用内加急 | `im:message.urgent:app_send` |

## 卸载

编辑 `~/.claude/settings.json`，移除 `hooks` 中的 `Stop` 和 `Notification` 条目。
