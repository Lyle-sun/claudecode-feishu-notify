# claudecode-feishu-notify

Claude Code 飞书通知 Skill —— 任务完成或需要确认时，通过飞书私聊卡片消息 + 加急提醒你。

**适用人群**：长时间使用 Claude Code 且需要离开终端的开发者。让 Claude 跑一个耗时任务（代码重构、批量修改），去做别的事，完成时飞书通知你回来。

## 功能

- **任务完成通知**：Claude Code 每个 turn 结束时，飞书绿色卡片 + 加急，显示项目名和 Claude 最后的回复摘要
- **异常检测**：消息含 API Error / Traceback 等关键词时，自动变红色卡片
- **确认提醒**：Claude Code 需要你确认操作时，飞书橙色卡片 + 加急
- **空闲提醒**：Claude Code 空闲等待时，飞书蓝色卡片 + 加急
- **认证成功通知**：Claude Code 认证成功时，飞书绿色卡片 + 加急
- **静音模式**：`CC_FEISHU_NOTIFY=0` 可临时关闭所有通知

## 通知样式

| 事件 | 卡片颜色 | 示例 |
|------|---------|------|
| Stop（任务完成） | 🟢 绿色 | ✅ Claude Code 任务完成 |
| Stop（异常） | 🔴 红色 | ❌ Claude Code 任务异常 |
| Notification（需要确认） | 🟠 橙色 | ⚠️ Claude Code 需要确认 |
| Notification（空闲等待） | 🔵 蓝色 | ⏳ Claude Code 等待中 |
| Notification（认证成功） | 🟢 绿色 | ✅ Claude Code 认证成功 |

## 安装

```bash
git clone https://github.com/Lyle-sun/claudecode-feishu-notify.git
cp -r claudecode-feishu-notify/skills/lark-workflow-cc-notify ~/.claude/skills/
```

然后在 Claude Code 中说：

> 帮我配置飞书通知

Claude Code 会引导你完成配置（全程交互式）：

1. 安装 lark-cli（自动）
2. 创建飞书自建应用 + 启用机器人能力
3. 完成 OAuth 授权
4. 开通应用权限（`im:message` + `im:message.urgent:app_send`）
5. 获取你的 open_id 并设置环境变量 `CC_FEISHU_OPEN_ID`
6. 部署 hook 脚本并配置 settings.json

**安装完成后重启 Claude Code 会话即可生效。**

### 不使用 Skill 引导

如果不想通过 Skill 引导，也可以直接运行安装脚本：

```bash
git clone https://github.com/Lyle-sun/claudecode-feishu-notify.git
cd claudecode-feishu-notify/skills/lark-workflow-cc-notify

# 设置环境变量
export CC_FEISHU_OPEN_ID="ou_YOUR_OPEN_ID"

# 运行安装（macOS/Linux）
chmod +x scripts/install.sh && ./scripts/install.sh

# 运行安装（Windows PowerShell）
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser; .\scripts\install.ps1
```

## 环境变量

| 变量 | 必填 | 说明 |
|------|------|------|
| `CC_FEISHU_OPEN_ID` | 是 | 你的飞书 open_id（格式 `ou_xxxx`） |
| `CC_FEISHU_NOTIFY` | 否 | 设为 `0` 时关闭通知（默认 `1` 开启） |

## 验证

```bash
# 验证 Stop 事件（绿色卡片）
echo '{"hook_event_name":"Stop","last_assistant_message":"Hello, task done!","cwd":"/path/to/project"}' | ~/.claude/hooks/notify-feishu.sh

# 验证 Notification 事件（橙色卡片）
echo '{"hook_event_name":"Notification","notification_type":"permission_prompt","message":"Allow tool execution?"}' | ~/.claude/hooks/notify-feishu.sh
```

飞书应收到对应的加急卡片通知。

## 项目结构

```
claudecode-feishu-notify/
├── skills/
│   └── lark-workflow-cc-notify/
│       ├── SKILL.md                     # Skill 定义
│       ├── scripts/
│       │   ├── notify-feishu.sh         # 核心脚本（macOS/Linux）
│       │   ├── notify-feishu.ps1        # 核心脚本（Windows）
│       │   ├── install.sh              # 安装脚本（macOS/Linux）
│       │   └── install.ps1             # 安装脚本（Windows）
│       └── references/
│           ├── claude-code-hooks.md     # Hooks 事件说明
│           └── feishu-message-api.md    # 飞书 API 参考
├── .gitignore
├── README.md
└── LICENSE
```

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

## License

MIT
