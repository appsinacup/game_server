# `GameServer.Friends.Friendship`

Ecto schema representing a friendship/request between two users.

The friendship object stores the requester and the target user together with
a status field which can be "pending", "accepted", "rejected" or
"blocked".

# `t`

```elixir
@type t() :: %GameServer.Friends.Friendship{
  __meta__: term(),
  id: integer() | nil,
  inserted_at: term(),
  requester: term(),
  requester_id: integer() | nil,
  status: String.t(),
  target: term(),
  target_id: integer() | nil,
  updated_at: term()
}
```

A friendship/request record between two users.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
