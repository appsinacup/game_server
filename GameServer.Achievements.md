# `GameServer.Achievements`

The Achievements context.

Manages achievement definitions and user progress/unlocks.

## Usage

    # Create an achievement (admin)
    {:ok, ach} = Achievements.create_achievement(%{
      slug: "first_lobby",
      title: "Welcome!",
      description: "Join your first lobby",
      points: 10,
      progress_target: 1
    })

    # Unlock a one-shot achievement
    {:ok, ua} = Achievements.unlock_achievement(user_id, "first_lobby")

    # Increment progress on a multi-step achievement
    {:ok, ua} = Achievements.increment_progress(user_id, "chat_100", 1)
    # auto-unlocks when progress >= progress_target

    # List achievements (with user progress if user_id provided)
    achievements = Achievements.list_achievements(user_id: user_id, page: 1, page_size: 25)

# `change_achievement`

```elixir
@spec change_achievement(GameServer.Achievements.Achievement.t(), map()) ::
  Ecto.Changeset.t()
```

Returns a changeset for tracking achievement changes (used by forms).

# `count_achievements`

```elixir
@spec count_achievements(keyword()) :: non_neg_integer()
```

Count achievements (for pagination).

# `count_all_achievements`

```elixir
@spec count_all_achievements() :: non_neg_integer()
```

Count all achievements (including hidden), for admin dashboard.

# `count_all_unlocks`

```elixir
@spec count_all_unlocks() :: non_neg_integer()
```

Count all user achievement unlock records.

# `count_user_achievements`

```elixir
@spec count_user_achievements(integer()) :: non_neg_integer()
```

Count unlocked achievements for a user.

# `create_achievement`

```elixir
@spec create_achievement(map()) ::
  {:ok, GameServer.Achievements.Achievement.t()} | {:error, Ecto.Changeset.t()}
```

Creates a new achievement definition.

# `delete_achievement`

```elixir
@spec delete_achievement(GameServer.Achievements.Achievement.t()) ::
  {:ok, GameServer.Achievements.Achievement.t()} | {:error, Ecto.Changeset.t()}
```

Deletes an achievement and all related user progress.

# `get_achievement`

```elixir
@spec get_achievement(integer()) :: GameServer.Achievements.Achievement.t() | nil
```

Get an achievement by ID.

# `get_achievement_by_slug`

```elixir
@spec get_achievement_by_slug(String.t()) ::
  GameServer.Achievements.Achievement.t() | nil
```

Get an achievement by slug.

# `get_user_achievement`

```elixir
@spec get_user_achievement(integer(), integer()) ::
  GameServer.Achievements.UserAchievement.t() | nil
```

Get a user's progress on a specific achievement.

# `get_user_points`

```elixir
@spec get_user_points(integer()) :: non_neg_integer()
```

Get total points earned by a user.

# `grant_achievement`

```elixir
@spec grant_achievement(integer(), String.t()) ::
  {:ok, GameServer.Achievements.UserAchievement.t()} | {:error, atom()}
```

Grant achievement to user by slug (admin convenience, calls unlock_achievement).

# `increment_progress`

```elixir
@spec increment_progress(integer(), String.t(), pos_integer()) ::
  {:ok, GameServer.Achievements.UserAchievement.t()} | {:error, atom()}
```

Increment progress on an achievement for a user. Automatically unlocks
when progress reaches the target.

Returns `{:ok, user_achievement}`.

# `list_achievements`

```elixir
@spec list_achievements(keyword()) :: [map()]
```

Lists all achievements, optionally with user progress.

## Options
- `:user_id` — if provided, includes user progress/unlock status
- `:page` — page number (default: 1)
- `:page_size` — items per page (default: 25)
- `:include_hidden` — if true, include hidden achievements (default: false)

# `list_user_achievements`

```elixir
@spec list_user_achievements(
  integer(),
  keyword()
) :: [GameServer.Achievements.UserAchievement.t()]
```

Lists all achievements unlocked by a user.

# `reset_user_achievement`

```elixir
@spec reset_user_achievement(integer(), integer()) ::
  {:ok, GameServer.Achievements.UserAchievement.t() | :not_found}
  | {:error, Ecto.Changeset.t()}
```

Reset a user's progress on a specific achievement (admin use).

# `revoke_achievement`

```elixir
@spec revoke_achievement(integer(), integer()) ::
  {:ok, GameServer.Achievements.UserAchievement.t()} | {:error, atom()}
```

Revoke an achievement from a user. Deletes the user_achievement record entirely.

# `subscribe_achievements`

```elixir
@spec subscribe_achievements() :: :ok | {:error, term()}
```

Subscribe to global achievement events (new definitions, updates, unlocks).

# `unlock_achievement`

```elixir
@spec unlock_achievement(integer(), String.t() | integer()) ::
  {:ok, GameServer.Achievements.UserAchievement.t()} | {:error, atom()}
```

Unlock an achievement for a user by slug. If it's a progress-based achievement,
sets progress to the target and marks it as unlocked.

Returns `{:ok, user_achievement}` or `{:error, reason}`.

# `unlock_percentage`

```elixir
@spec unlock_percentage(integer()) :: float()
```

Get unlock percentage for an achievement (0.0 to 100.0).

# `update_achievement`

```elixir
@spec update_achievement(GameServer.Achievements.Achievement.t(), map()) ::
  {:ok, GameServer.Achievements.Achievement.t()} | {:error, Ecto.Changeset.t()}
```

Updates an achievement definition.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
