# `GameServer.IpBans.IpBan`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/ip_bans/ip_ban.ex#L1)

A persisted IP ban. `expires_at` is `nil` for permanent bans.

# `t`

```elixir
@type t() :: %GameServer.IpBans.IpBan{
  __meta__: term(),
  expires_at: DateTime.t() | nil,
  id: integer() | nil,
  inserted_at: term(),
  ip: String.t() | nil,
  updated_at: term()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
