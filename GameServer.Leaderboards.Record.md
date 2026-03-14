# `GameServer.Leaderboards.Record`

Ecto schema for the `leaderboard_records` table.

A record represents a single score entry in a leaderboard.
Records can be either **user-based** (one per user per leaderboard)
or **label-based** (one per label per leaderboard, no user required).

- User-based: `user_id` is set, `label` is nil. Uniqueness on `(leaderboard_id, user_id)`.
- Label-based: `label` is set, `user_id` is nil. Uniqueness on `(leaderboard_id, label)`.

# `t`

```elixir
@type t() :: %GameServer.Leaderboards.Record{
  __meta__: term(),
  id: term(),
  inserted_at: term(),
  label: term(),
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
Either `user_id` or `label` must be provided (but not both).

# `update_changeset`

Changeset for updating an existing record's score.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
