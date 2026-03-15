# `GameServer.Achievements.UserAchievement`

Ecto schema for the `user_achievements` table.

Tracks a user's progress toward (and unlock status of) an achievement.

## Fields
- `user_id` — the user
- `achievement_id` — the achievement
- `progress` — current progress (0..progress_target)
- `unlocked_at` — nil if not yet unlocked, timestamp when unlocked
- `metadata` — arbitrary JSON data

# `t`

```elixir
@type t() :: %GameServer.Achievements.UserAchievement{
  __meta__: term(),
  achievement: term(),
  achievement_id: term(),
  id: term(),
  inserted_at: term(),
  metadata: term(),
  progress: term(),
  unlocked_at: term(),
  updated_at: term(),
  user: term(),
  user_id: term()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
