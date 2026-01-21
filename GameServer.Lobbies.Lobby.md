# `GameServer.Lobbies.Lobby`

Ecto schema for the `lobbies` table and changeset helpers.

A lobby represents a game room with basic settings (title, host, capacity,
visibility, lock/password and arbitrary metadata).

# `t`

```elixir
@type t() :: %GameServer.Lobbies.Lobby{
  __meta__: term(),
  host: term(),
  host_id: term(),
  hostless: term(),
  id: term(),
  inserted_at: term(),
  is_hidden: term(),
  is_locked: term(),
  max_users: term(),
  memberships: term(),
  metadata: term(),
  password_hash: term(),
  title: term(),
  updated_at: term(),
  users: term()
}
```

# `changeset`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
