# Claude Code Hooks 事件

## Stop 事件

Claude Code 完成一个 turn 时触发。

stdin JSON 字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| `hook_event_name` | string | `"Stop"` |
| `session_id` | string | 当前会话 ID |
| `transcript_path` | string | 对话记录 JSONL 文件路径 |
| `cwd` | string | 当前工作目录 |
| `permission_mode` | string | 权限模式 |
| `stop_hook_active` | boolean | hook 是否激活 |
| `last_assistant_message` | string | Claude 最后一条回复文本 |

## Notification 事件

各类通知场景触发。

stdin JSON 字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| `hook_event_name` | string | `"Notification"` |
| `session_id` | string | 当前会话 ID |
| `transcript_path` | string | 对话记录 JSONL 文件路径 |
| `cwd` | string | 当前工作目录 |
| `message` | string | 通知消息文本 |
| `title` | string | 通知标题 |
| `notification_type` | string | 通知类型（也是 matcher 值） |

### notification_type 取值

| 值 | 说明 |
|----|------|
| `permission_prompt` | 需要用户确认操作 |
| `idle_prompt` | Claude Code 空闲等待 |
| `auth_success` | 认证成功 |
| `elicitation_dialog` | MCP 对话框 |
| `elicitation_complete` | MCP 对话完成 |
| `elicitation_response` | MCP 对话响应 |
