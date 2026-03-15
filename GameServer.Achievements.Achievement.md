# `GameServer.Achievements.Achievement`

Ecto schema for the `achievements` table.

An achievement is a goal or milestone that players can unlock.

## Fields
- `slug` — unique identifier (e.g., "first_lobby_join")
- `title` — display name
- `description` — human-readable description
- `icon_url` — optional icon path/URL
- `points` — point value for this achievement
- `sort_order` — display ordering (lower = first)
- `hidden` — if true, not shown until unlocked
- `progress_target` — number of steps to complete (1 = one-shot, >1 = incremental)
- `metadata` — arbitrary JSON data

# `t`

```elixir
@type t() :: %GameServer.Achievements.Achievement{
  __meta__: term(),
  description: term(),
  hidden: term(),
  icon_url: term(),
  id: term(),
  inserted_at: term(),
  metadata: term(),
  points: term(),
  progress_target: term(),
  slug: term(),
  sort_order: term(),
  title: term(),
  updated_at: term(),
  user_achievements: term()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
