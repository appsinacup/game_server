# `GameServer.Chat.Message`

Ecto schema for the `chat_messages` table.

Represents a single chat message in a lobby, group, or friend conversation.

## Fields

  * `content` — message text
  * `metadata` — arbitrary JSON metadata (e.g. message type, attachments)
  * `sender_id` — user who sent the message
  * `chat_type` — "lobby", "group", or "friend"
  * `chat_ref_id` — reference ID (lobby_id, group_id, or the other user's id for DMs)

# `t`

```elixir
@type t() :: %GameServer.Chat.Message{
  __meta__: term(),
  chat_ref_id: term(),
  chat_type: term(),
  content: term(),
  id: term(),
  inserted_at: term(),
  metadata: term(),
  sender: term(),
  sender_id: term(),
  updated_at: term()
}
```

# `changeset`

Changeset for creating/updating a chat message.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
