# `GameServer.LobbySnapshots.Blob`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/lobby_snapshots/blob.ex#L1)

Content-addressed storage for one snapshot section.

The hash is the primary key, so identical content stores a single row however
many sections, snapshots or lobbies reference it. This subsumes per-section
change detection: an unchanged section hashes to the value already stored.

`last_referenced_at` is what retention prunes on — see the migration for why
`inserted_at` cannot be used for that.

# `t`

```elixir
@type t() :: %GameServer.LobbySnapshots.Blob{
  __meta__: term(),
  byte_size: term(),
  content: term(),
  hash: term(),
  inserted_at: term(),
  last_referenced_at: term()
}
```

# `changeset`

```elixir
@spec changeset(t(), map()) :: Ecto.Changeset.t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
