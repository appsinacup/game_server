# `GameServer.Lobbies.SpectatorTracker`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/lobbies/spectator_tracker.ex#L1)

Lightweight ETS-based tracker for lobby spectators.

Spectators are users connected to a lobby channel who are not members.
This module tracks them in-memory (no persistence) so we can show spectator
counts in admin panels and API responses.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `count`

```elixir
@spec count(Ecto.UUID.t()) :: non_neg_integer()
```

Count spectators in a lobby.

# `counts`

```elixir
@spec counts([Ecto.UUID.t()]) :: %{required(Ecto.UUID.t()) =&gt; non_neg_integer()}
```

Count spectators for multiple lobbies at once. Returns `%{lobby_id => count}`.

# `list`

```elixir
@spec list(Ecto.UUID.t()) :: [Ecto.UUID.t()]
```

List spectator user IDs for a lobby.

# `start_link`

# `track`

```elixir
@spec track(Ecto.UUID.t(), Ecto.UUID.t()) :: true
```

Track a spectator joining a lobby.

# `untrack`

```elixir
@spec untrack(Ecto.UUID.t(), Ecto.UUID.t()) :: true
```

Remove a spectator from a lobby.

# `untrack_all`

```elixir
@spec untrack_all(Ecto.UUID.t()) :: true
```

Remove all spectators for a given lobby (e.g. when lobby is deleted).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
