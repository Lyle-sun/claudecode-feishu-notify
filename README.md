# claude-code-feishu-notify

飞书通知 Claude Code 事件 —— 任务完成或需要确认时，通过飞书私聊卡片消息 + 加急提醒你。

**适用人群**：长时间使用 Claude Code 且需要离开终端的开发者。让 Claude 跑一个耗时任务（代码重构、批量修改），去做别的事，完成时飞书通知你回来。

## 功能

- **任务完成通知**：Claude Code 每个 turn 结束时，飞书绿色卡片 + 加急，显示项目名和 Claude 最后的回复摘要
- **确认提醒**：Claude Code 需要你确认操作时，飞书橙色卡片 + 加急
- **空闲提醒**：Claude Code 空闲等待时，飞书蓝色卡片 + 加急
- **认证成功通知**：Claude Code 认证成功时，飞书绿色卡片 + 加急
- **静音模式**：设置 `CC_FEISHU_NOTIFY=0` 可临时关闭所有通知

## 通知样式

| 事件 | 卡片颜色 | 示例 |
|------|---------|------|
| Stop（任务完成） | 🟢 绿色 | ✅ Claude Code 任务完成 |
| Stop（异常） | 🔴 红色 | ❌ Claude Code 任务异常 |
| Notification（需要确认） | 🟠 橙色 | ⚠️ Claude Code 需要确认 |
| Notification（空闲等待） | 🔵 蓝色 | ⏳ Claude Code 等待中 |
| Notification（认证成功） | 🟢 绿色 | ✅ Claude Code 认证成功 |

## 前置条件

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 已安装
- Python 3 已安装
- macOS/Linux 需安装 `jq`（install.sh 可自动安装）

> Node.js 和 lark-cli 会由安装脚本自动安装（如未安装）。macOS/Linux 通过 brew/apt/dnf 等包管理器安装 Node.js，Windows 通过 winget 安装。

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

### Step 6: 配置环境变量

**macOS / Linux**（添加到 `~/.zshrc` 或 `~/.bashrc`）：

```bash
export CC_FEISHU_OPEN_ID="ou_YOUR_OPEN_ID"
```

**Windows PowerShell**（永久设置用户环境变量）：

```powershell
[Environment]::SetEnvironmentVariable("CC_FEISHU_OPEN_ID", "ou_YOUR_OPEN_ID", "User")
```

设置后重启终端，或执行 `source ~/.zshrc` 使环境变量生效。

### Step 7: 运行安装脚本

**macOS / Linux：**

```bash
git clone https://github.com/Lyle-sun/claudecode-feishu-notify.git
cd claudecode-feishu-notify
chmod +x install.sh
./install.sh
```

**Windows PowerShell：**

```powershell
git clone https://github.com/Lyle-sun/claudecode-feishu-notify.git
cd claudecode-feishu-notify
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
.\install.ps1
```

### Step 8: 重启 Claude Code

**hooks 配置在重启 Claude Code 会话后生效。** 请退出当前会话并重新打开。

### Step 9: 验证

**macOS / Linux：**

```bash
echo '{"hook_event_name":"Stop","last_assistant_message":"Hello, task done!","cwd":"/path/to/project"}' | ~/.claude/hooks/notify-feishu.sh
```

**Windows PowerShell：**

```powershell
'{"hook_event_name":"Stop","last_assistant_message":"Hello, task done!","cwd":"C:\path\to\project"}' | & "$env:USERPROFILE\.claude\hooks\notify-feishu.ps1"
```

飞书应收到绿色卡片加急通知，显示项目名和消息摘要。

也可以验证 Notification 事件：

```bash
echo '{"hook_event_name":"Notification","message":"需要确认操作","notification_type":"permission_prompt"}' | ~/.claude/hooks/notify-feishu.sh
```

飞书应收到橙色卡片加急通知。

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
├── .gitignore
├── README.md
└── LICENSE
```

## 环境变量

| 变量 | 必填 | 说明 |
|------|------|------|
| `CC_FEISHU_OPEN_ID` | 是 | 你的飞书 open_id（格式 `ou_xxxx`） |
| `CC_FEISHU_NOTIFY` | 否 | 设为 `0` 时关闭所有通知（默认 `1` 开启） |

## Hook 事件

| 事件 | Matcher | 卡片颜色 | 触发时机 |
|------|---------|---------|---------|
| Stop | (all) | 绿色 | Claude Code 完成一个 turn |
| Stop（含错误） | (all) | 红色 | 消息中包含 API Error / Traceback 等关键词 |
| Notification | permission_prompt | 橙色 | 需要用户确认操作 |
| Notification | idle_prompt | 蓝色 | Claude Code 空闲等待 |
| Notification | auth_success | 绿色 | 认证成功 |

## 卸载

编辑 `~/.claude/settings.json`，移除 `hooks` 中的 `Stop` 和 `Notification` 条目。

## 工作原理

1. Claude Code hooks 机制在事件触发时调用通知脚本
2. 脚本从 stdin 读取事件 JSON，根据事件类型生成飞书卡片内容
3. 通过 `lark-cli im +messages-send --msg-type interactive` 发送飞书卡片私聊消息
4. 从发送结果提取 `message_id`，调用 `PATCH /open-apis/im/v1/messages/{message_id}/urgent_app` 加急

## License

MIT
