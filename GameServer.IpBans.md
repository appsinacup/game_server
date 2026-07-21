# `GameServer.IpBans`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/ip_bans.ex#L1)

Persistence for IP bans.

`GameServerWeb.Plugs.IpBan` keeps the hot-path check in ETS; this context
is the durable source of truth so bans survive restarts and can be shared
across instances (each instance loads them at boot and applies PubSub
updates).

# `delete_ban`

```elixir
@spec delete_ban(String.t()) :: :ok
```

Deletes the ban for `ip` (no-op if none exists).

# `list_active`

```elixir
@spec list_active() :: [GameServer.IpBans.IpBan.t()]
```

Lists all bans that are permanent or not yet expired.

# `purge_expired`

```elixir
@spec purge_expired() :: non_neg_integer()
```

Deletes expired bans. Returns the number of rows removed.

# `upsert_ban`

```elixir
@spec upsert_ban(String.t(), DateTime.t() | nil) ::
  {:ok, GameServer.IpBans.IpBan.t()} | {:error, Ecto.Changeset.t()}
```

Creates or updates a ban for `ip`. `expires_at` is `nil` for a permanent ban.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
