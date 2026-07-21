# `GameServer.LobbySnapshots.Snapshot`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/lobby_snapshots/snapshot.ex#L1)

One capture of a lobby's state at a mutation entry point.

`section_hashes` maps section name to a `Blob` hash; the blobs hold the
content. Sections whose content did not change resolve to the hash already
stored, so an unchanged section costs one map entry and no blob row.

Ordered by `(inserted_at, id)` — `id` is UUIDv7 and therefore time-ordered, so
it breaks ties without a stored counter. `lobby_id` has no foreign key. See
the migration for both.

# `t`

```elixir
@type t() :: %GameServer.LobbySnapshots.Snapshot{
  __meta__: term(),
  flagged: term(),
  id: term(),
  inserted_at: term(),
  lobby_id: term(),
  section_hashes: term(),
  trigger: term(),
  user: term(),
  user_id: term()
}
```

# `changeset`

```elixir
@spec changeset(t(), map()) :: Ecto.Changeset.t()
```

# `sections`

```elixir
@spec sections() :: [String.t()]
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
