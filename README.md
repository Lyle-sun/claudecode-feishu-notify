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
- [Node.js](https://nodejs.org) 已安装（lark-cli 依赖）
- Python 3 已安装
- macOS/Linux 需安装 `jq`（install.sh 可自动安装）
- 飞书账号，且有权限创建/管理自建应用

## 安装

### Step 1: 安装 lark-cli

```bash
npm install -g @larksuite/cli
```

### Step 2: 初始化飞书应用

如果你还没有飞书自建应用：

```bash
lark-cli config init --new
```

按提示在浏览器中完成应用创建。**确保应用启用了「机器人」能力**。

### Step 3: 登录授权

```bash
lark-cli auth login
```

按提示在浏览器中完成 OAuth 授权。

### Step 4: 开通应用权限

在[飞书开发者后台](https://open.feishu.cn/app)找到你的应用 → **权限管理**，搜索并开通：

- `im:message`（获取与发送单聊、群组消息）
- `im:message.urgent:app_send`（发送应用内加急消息）

开通后如需管理员审批，提交审批并等待通过。

### Step 5: 获取你的 open_id

```bash
lark-cli contact +get-user --as user
```

记录返回的 `open_id`（格式：`ou_xxxxxxxx`）。

### Step 6: 配置并部署

**macOS / Linux：**

```bash
# 克隆仓库
git clone https://github.com/<your-username>/claude-code-feishu-notify.git
cd claude-code-feishu-notify

# 替换 open_id（跨平台，用 python3 替代 sed）
python3 -c "
with open('notify-feishu.sh') as f:
    t = f.read().replace('ou_REPLACE_ME', 'ou_YOUR_OPEN_ID')
with open('notify-feishu.sh', 'w') as f:
    f.write(t)
"

# 运行安装脚本
chmod +x install.sh
./install.sh
```

**Windows PowerShell：**

```powershell
# 克隆仓库
git clone https://github.com/<your-username>/claude-code-feishu-notify.git
cd claude-code-feishu-notify

# 替换 open_id
(Get-Content notify-feishu.ps1 -Raw) -replace 'ou_REPLACE_ME', 'ou_YOUR_OPEN_ID' | Set-Content notify-feishu.ps1

# 运行安装脚本
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
.\install.ps1
```

### Step 7: 重启 Claude Code

**hooks 配置在重启 Claude Code 会话后生效。** 请退出当前会话并重新打开。

### Step 8: 验证

**macOS / Linux：**

```bash
echo '{"hook_event_name":"Stop","stop_reason":"end_turn"}' | ~/.claude/hooks/notify-feishu.sh
```

**Windows PowerShell：**

```powershell
'{"hook_event_name":"Stop","stop_reason":"end_turn"}' | & "$env:USERPROFILE\.claude\hooks\notify-feishu.ps1"
```

飞书应收到绿色卡片加急通知。

## 项目结构

```
claude-code-feishu-notify/
├── notify-feishu.sh            # 核心脚本（macOS/Linux）
├── notify-feishu.ps1           # 核心脚本（Windows）
├── install.sh                  # 安装脚本（macOS/Linux）
├── install.ps1                 # 安装脚本（Windows）
├── skills/
│   └── lark-workflow-cc-notify/
│       └── SKILL.md            # Claude Code skill 定义
├── README.md
└── LICENSE
```

## Hook 事件

| 事件 | Matcher | 卡片颜色 | 触发时机 |
|------|---------|---------|---------|
| Stop | (all) | 绿色 | Claude Code 完成一个 turn |
| Notification | permission_prompt | 橙色 | 需要用户确认操作 |
| Notification | idle_prompt | 蓝色 | Claude Code 空闲等待 |

## 卸载

编辑 `~/.claude/settings.json`，移除 `hooks` 中的 `Stop` 和 `Notification` 条目。

## 工作原理

1. Claude Code hooks 机制在事件触发时调用通知脚本
2. 脚本从 stdin 读取事件 JSON，根据事件类型生成飞书卡片内容
3. 通过 `lark-cli im +messages-send --msg-type interactive` 发送飞书卡片私聊消息
4. 从发送结果提取 `message_id`，调用 `PATCH /open-apis/im/v1/messages/{message_id}/urgent_app` 加急

## License

MIT
