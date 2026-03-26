# `GameServer.Lobbies.SpectatorTracker`

Lightweight ETS-based tracker for lobby spectators.

Spectators are users connected to a lobby channel who are not members.
This module tracks them in-memory (no persistence) so we can show spectator
counts in admin panels and API responses.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `count`

```elixir
@spec count(integer()) :: non_neg_integer()
```

Count spectators in a lobby.

# `counts`

```elixir
@spec counts([integer()]) :: %{required(integer()) =&gt; non_neg_integer()}
```

Count spectators for multiple lobbies at once. Returns `%{lobby_id => count}`.

# `list`

```elixir
@spec list(integer()) :: [integer()]
```

List spectator user IDs for a lobby.

# `start_link`

# `track`

```elixir
@spec track(integer(), integer()) :: true
```

Track a spectator joining a lobby.

# `untrack`

```elixir
@spec untrack(integer(), integer()) :: true
```

Remove a spectator from a lobby.

# `untrack_all`

```elixir
@spec untrack_all(integer()) :: true
```

Remove all spectators for a given lobby (e.g. when lobby is deleted).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
