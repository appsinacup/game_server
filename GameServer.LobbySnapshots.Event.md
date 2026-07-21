# `GameServer.LobbySnapshots.Event`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/lobby_snapshots/event.ex#L1)

A decision worth explaining, recorded between two snapshots.

Snapshots record *what* changed; they cannot record *why*. A snapshot shows
`speed: 100 -> 50`; only an event carries the `gap` and `targets_ahead` that
produced it.

Which interval an event falls in is derived at read time by `timeline/1` —
the latest snapshot at or before the event — rather than stored. See the
migration.

# `t`

```elixir
@type t() :: %GameServer.LobbySnapshots.Event{
  __meta__: term(),
  id: term(),
  inserted_at: term(),
  kind: term(),
  lobby_id: term(),
  payload: term(),
  user: term(),
  user_id: term()
}
```

# `changeset`

```elixir
@spec changeset(t(), map()) :: Ecto.Changeset.t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
