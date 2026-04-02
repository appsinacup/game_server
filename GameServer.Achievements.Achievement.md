# `GameServer.Achievements.Achievement`

Ecto schema for the `achievements` table.

An achievement is a goal or milestone that players can unlock.

## Fields
- `slug` — unique identifier (e.g., "first_lobby_join")
- `title` — display name
- `description` — human-readable description
- `icon_url` — optional icon path/URL
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
  progress_target: term(),
  slug: term(),
  sort_order: term(),
  title: term(),
  updated_at: term(),
  user_achievements: term()
}
```

# `localized_description`

Returns the localized description for the given locale.

Looks up `metadata["descriptions"][locale]`, falling back to `description`.

# `localized_title`

Returns the localized title for the given locale.

Looks up `metadata["titles"][locale]`, falling back to `title`.

## Examples

    iex> a = %Achievement{title: "First Kill", metadata: %{"titles" => %{"es" => "Primera Baja"}}}
    iex> Achievement.localized_title(a, "es")
    "Primera Baja"
    iex> Achievement.localized_title(a, "en")
    "First Kill"

---

*Consult [api-reference.md](api-reference.md) for complete listing*
