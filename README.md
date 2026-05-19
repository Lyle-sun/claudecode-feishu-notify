# claude-code-feishu-notify

飞书通知 Claude Code 事件 —— 任务完成或需要确认时，通过飞书私聊卡片消息 + 加急提醒你。

## 功能

- **任务完成通知**：Claude Code 每个 turn 结束时，飞书绿色卡片 + 加急
- **确认提醒**：Claude Code 需要你确认操作时，飞书橙色卡片 + 加急
- **空闲提醒**：Claude Code 空闲等待时，飞书蓝色卡片 + 加急

## 通知样式

| 事件 | 卡片颜色 | 示例 |
|------|---------|------|
| Stop（任务完成） | 🟢 绿色 | ✅ Claude Code 任务完成 |
| Notification（需要确认） | 🟠 橙色 | ⚠️ Claude Code 需要确认 |
| Notification（空闲等待） | 🔵 蓝色 | ⏳ Claude Code 等待中 |

## 前置条件

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 已安装
- [lark-cli](https://github.com/larksuite/lark-cli) 已安装并完成认证
- 系统需安装 `jq`
- 飞书应用需开通以下权限：
  - `im:message`（发送消息）
  - `im:message.urgent:app_send`（发送应用内加急）
- 飞书应用需启用**机器人**能力

## 安装

```bash
# 1. 克隆仓库
git clone https://github.com/你的用户名/claude-code-feishu-notify.git
cd claude-code-feishu-notify

# 2. 修改 notify-feishu.sh 中的 USER_OPEN_ID 为你的飞书 open_id
#    获取方式：lark-cli contact +get-user --as user

# 3. 运行安装脚本（部署 hook 脚本 + skill + 配置 hooks）
chmod +x install.sh
./install.sh
```

## 项目结构

```
claude-code-feishu-notify/
├── notify-feishu.sh                        # 核心脚本：发飞书卡片消息 + 加急
├── install.sh                              # 安装脚本：部署 hook + skill + 配置 settings
├── skills/
│   └── lark-workflow-cc-notify/
│       └── SKILL.md                        # Claude Code skill 定义
├── README.md
└── LICENSE
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

| 事件 | Matcher | 卡片颜色 | 触发时机 |
|------|---------|---------|---------|
| Stop | (all) | 绿色 | Claude Code 完成一个 turn |
| Notification | permission_prompt | 橙色 | 需要用户确认操作 |
| Notification | idle_prompt | 蓝色 | Claude Code 空闲等待 |

### 卸载

编辑 `~/.claude/settings.json`，移除 `hooks` 中的 `Stop` 和 `Notification` 条目。

## 工作原理

1. Claude Code hooks 机制在事件触发时调用 `notify-feishu.sh`
2. 脚本从 stdin 读取事件 JSON，根据事件类型生成飞书卡片内容
3. 通过 `lark-cli im +messages-send --msg-type interactive` 发送飞书卡片私聊消息
4. 从发送结果提取 `message_id`，调用 `PATCH /open-apis/im/v1/messages/{message_id}/urgent_app` 加急

## License

MIT
