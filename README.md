# claude-code-feishu-notify

飞书通知 Claude Code 事件 —— 任务完成或需要确认时，通过飞书私聊加急提醒你。

## 功能

- **任务完成通知**：Claude Code 每个 turn 结束时，飞书私聊通知你
- **确认提醒**：Claude Code 需要你确认操作时，飞书加急通知
- **空闲提醒**：Claude Code 空闲等待时，飞书通知

## 前置条件

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 已安装
- [lark-cli](https://github.com/larksuite/lark-cli) 已安装并完成认证
- 飞书应用需开通以下权限：
  - `im:message`（发送消息）
  - `im:message.urgent` 或 `im:message.urgent:app_send`（发送应用内加急）
- 飞书应用需启用**机器人**能力

## 安装

```bash
# 1. 克隆仓库
git clone https://github.com/你的用户名/claude-code-feishu-notify.git
cd claude-code-feishu-notify

# 2. 修改 notify-feishu.sh 中的 USER_OPEN_ID 为你的飞书 open_id
#    获取方式：lark-cli contact +get-user --as user

# 3. 运行安装脚本
chmod +x install.sh
./install.sh
```

## 配置说明

### 修改通知目标

编辑 `notify-feishu.sh`，将 `USER_OPEN_ID` 改为你的飞书 open_id：

```bash
USER_OPEN_ID="ou_xxxxxx"
```

获取你的 open_id：

```bash
lark-cli contact +get-user --as user
```

### Hook 事件

| 事件 | Matcher | 触发时机 |
|------|---------|---------|
| Stop | (all) | Claude Code 完成一个 turn |
| Notification | permission_prompt | 需要用户确认操作 |
| Notification | idle_prompt | Claude Code 空闲等待 |

### 卸载

编辑 `~/.claude/settings.json`，移除 `hooks` 中的 `Stop` 和 `Notification` 条目。

## 工作原理

1. Claude Code hooks 机制在事件触发时调用 `notify-feishu.sh`
2. 脚本通过 stdin 接收事件 JSON 数据
3. 根据事件类型生成消息内容，通过 `lark-cli` 发送飞书私聊消息
4. 发送成功后调用加急 API（`PATCH /open-apis/im/v1/messages/{message_id}/urgent_app`），确保你会收到提醒

## License

MIT
