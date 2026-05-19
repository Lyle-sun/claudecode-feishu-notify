# 飞书消息发送 API

## 发送消息

```bash
lark-cli im +messages-send --as bot --user-id <open_id> --content <card_json> --msg-type interactive
```

- `--as bot`：使用 bot 身份（tenant_access_token），加急 API 必须用 bot 身份
- `--user-id`：接收者的 open_id
- `--msg-type interactive`：发送卡片消息
- `--content`：卡片 JSON 字符串

## 卡片 2.0 格式

```json
{
  "schema": "2.0",
  "header": {
    "title": {"tag": "plain_text", "content": "标题"},
    "template": "green|red|orange|blue|purple|grey",
    "padding": "12px 12px 12px 12px"
  },
  "body": {
    "direction": "vertical",
    "padding": "12px 12px 12px 12px",
    "elements": [{
      "tag": "markdown",
      "content": "正文内容",
      "text_align": "left",
      "text_size": "normal"
    }]
  }
}
```

## 加急消息

```bash
lark-cli api PATCH "/open-apis/im/v1/messages/<message_id>/urgent_app" \
  --as bot \
  --params '{"user_id_type":"open_id"}' \
  --data '{"user_id_list": ["<open_id>"]}'
```

- 必须使用 bot 身份（`--as bot`），user access token 不支持加急 API
- 需要权限：`im:message.urgent:app_send`
