# `GameServer.Groups.GroupJoinRequest`

Ecto schema for the `group_join_requests` table.

Tracks pending, approved and rejected join requests for **private** groups.
Public groups don't need join requests (direct join). Hidden groups use
invitations instead.

## Statuses

- `"pending"` – waiting for an admin to decide
- `"accepted"` – approved (user is added to members)
- `"rejected"` – declined by an admin

# `t`

```elixir
@type t() :: %GameServer.Groups.GroupJoinRequest{
  __meta__: term(),
  group: term(),
  group_id: term(),
  id: term(),
  inserted_at: term(),
  status: term(),
  updated_at: term(),
  user: term(),
  user_id: term()
}
```

# `changeset`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
