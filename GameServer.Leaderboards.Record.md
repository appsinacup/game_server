# `GameServer.Leaderboards.Record`

Ecto schema for the `leaderboard_records` table.

A record represents a single user's score entry in a leaderboard.
Each user can have at most one record per leaderboard.

# `t`

```elixir
@type t() :: %GameServer.Leaderboards.Record{
  __meta__: term(),
  id: term(),
  inserted_at: term(),
  leaderboard: term(),
  leaderboard_id: term(),
  metadata: term(),
  rank: term(),
  score: term(),
  updated_at: term(),
  user: term(),
  user_id: term()
}
```

# `changeset`

Changeset for creating a new record.

# `update_changeset`

Changeset for updating an existing record's score.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
