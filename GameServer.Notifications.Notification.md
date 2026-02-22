# `GameServer.Notifications.Notification`

Ecto schema representing a notification sent from one user to another.

Notifications are persisted in the database and remain until the recipient
explicitly deletes them. Fields:

- `sender_id` – the user who sent the notification (must be a friend)
- `recipient_id` – the user who receives the notification
- `title` – required short summary
- `content` – optional longer body text
- `metadata` – optional arbitrary key/value map

# `t`

```elixir
@type t() :: %GameServer.Notifications.Notification{
  __meta__: term(),
  content: String.t() | nil,
  id: integer() | nil,
  inserted_at: DateTime.t() | nil,
  metadata: map(),
  recipient: term(),
  recipient_id: integer() | nil,
  sender: term(),
  sender_id: integer() | nil,
  title: String.t() | nil,
  updated_at: term()
}
```

A notification record.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
