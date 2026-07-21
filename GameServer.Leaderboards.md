# `GameServer.Leaderboards`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/leaderboards.ex#L1)

The Leaderboards context.

Provides server-authoritative leaderboard management. Scores can only be
submitted via server-side code — there is no public API for score submission.

## Usage

    # Create a leaderboard
    {:ok, lb} = Leaderboards.create_leaderboard(%{
      slug: "weekly_kills",
      title: "Weekly Kills",
      sort_order: :desc,
      operator: :incr
    })

    # Submit score (server-only): resolve the active leaderboard first and submit by ID
    leaderboard = Leaderboards.get_active_leaderboard_by_slug("weekly_kills")
    {:ok, record} = Leaderboards.submit_score(leaderboard.id, user_id, 10)

    # List records with rank (use leaderboard id)
    records = Leaderboards.list_records(leaderboard.id, page: 1, limit: 25)

    # Get user's record (use leaderboard id)
    {:ok, record} = Leaderboards.get_user_record(leaderboard.id, user_id)

# `change_leaderboard`

```elixir
@spec change_leaderboard(GameServer.Leaderboards.Leaderboard.t(), map()) ::
  Ecto.Changeset.t()
```

Returns a changeset for a leaderboard (used in forms).

# `change_record`

```elixir
@spec change_record(GameServer.Leaderboards.Record.t(), map()) :: Ecto.Changeset.t()
```

Returns a changeset for a record (used in admin forms).

# `count_all_records`

```elixir
@spec count_all_records() :: non_neg_integer()
```

Count all leaderboard records across all leaderboards.

# `count_leaderboard_groups`

```elixir
@spec count_leaderboard_groups() :: non_neg_integer()
```

Counts unique leaderboard slugs.

# `count_leaderboards`

```elixir
@spec count_leaderboards(keyword()) :: non_neg_integer()
```

Counts leaderboards matching the given filters.

Accepts the same filter options as `list_leaderboards/1`.

# `count_records`

```elixir
@spec count_records(
  Ecto.UUID.t(),
  keyword()
) :: non_neg_integer()
```

Counts records for a leaderboard.

# `create_leaderboard`

```elixir
@spec create_leaderboard(GameServer.Types.leaderboard_create_attrs()) ::
  {:ok, GameServer.Leaderboards.Leaderboard.t()} | {:error, Ecto.Changeset.t()}
```

Creates a new leaderboard.

## Attributes

See `t:GameServer.Types.leaderboard_create_attrs/0` for available fields.

## Examples

    iex> create_leaderboard(%{slug: "my_lb", title: "My Leaderboard"})
    {:ok, %Leaderboard{}}

    iex> create_leaderboard(%{slug: "", title: ""})
    {:error, %Ecto.Changeset{}}

# `delete_leaderboard`

```elixir
@spec delete_leaderboard(GameServer.Leaderboards.Leaderboard.t()) ::
  {:ok, GameServer.Leaderboards.Leaderboard.t()} | {:error, Ecto.Changeset.t()}
```

Deletes a leaderboard and all its records.

# `delete_record`

```elixir
@spec delete_record(GameServer.Leaderboards.Record.t()) ::
  {:ok, GameServer.Leaderboards.Record.t()} | {:error, Ecto.Changeset.t()}
```

Deletes a record.

# `delete_user_record`

```elixir
@spec delete_user_record(String.t(), Ecto.UUID.t()) ::
  {:ok, GameServer.Leaderboards.Record.t()} | {:error, :not_found}
```

Deletes a user's record from a leaderboard.
Accepts either leaderboard ID or slug (both strings).

# `end_leaderboard`

```elixir
@spec end_leaderboard(GameServer.Leaderboards.Leaderboard.t() | String.t()) ::
  {:ok, GameServer.Leaderboards.Leaderboard.t()}
  | {:error, Ecto.Changeset.t() | :not_found}
```

Ends a leaderboard by setting `ends_at` to the current time.

# `get_active_leaderboard_by_slug`

```elixir
@spec get_active_leaderboard_by_slug(String.t()) ::
  GameServer.Leaderboards.Leaderboard.t() | nil
```

Gets the currently active leaderboard with the given slug.
Returns `nil` if no active leaderboard exists.

An active leaderboard is one that:
- Has not ended (`ends_at` is nil or in the future)
- Has started (`starts_at` is nil or in the past)

If multiple active leaderboards exist with the same slug,
returns the most recently created one.

# `get_label_record`

```elixir
@spec get_label_record(Ecto.UUID.t(), String.t()) ::
  GameServer.Leaderboards.Record.t() | nil
```

Gets a single record by leaderboard ID and label.

# `get_leaderboard`

```elixir
@spec get_leaderboard(String.t()) :: GameServer.Leaderboards.Leaderboard.t() | nil
```

Gets a leaderboard by its UUID, or the active leaderboard by slug.

## Examples

    iex> get_leaderboard("0198c0de-...")
    %Leaderboard{}

    iex> get_leaderboard(Ecto.UUID.generate())
    nil

# `get_leaderboard!`

```elixir
@spec get_leaderboard!(String.t()) :: GameServer.Leaderboards.Leaderboard.t()
```

Gets a leaderboard by its ID. Raises if not found.

# `get_record`

```elixir
@spec get_record(Ecto.UUID.t(), Ecto.UUID.t()) ::
  GameServer.Leaderboards.Record.t() | nil
```

Gets a single record by leaderboard ID and user ID.

# `get_record!`

```elixir
@spec get_record!(Ecto.UUID.t()) :: GameServer.Leaderboards.Record.t()
```

Gets a record by its ID. Raises if not found.

Intended for internal/admin usage.

# `get_user_record`

```elixir
@spec get_user_record(Ecto.UUID.t(), Ecto.UUID.t()) ::
  {:ok, GameServer.Leaderboards.Record.t()} | {:error, :not_found}
```

Gets a user's record with their rank.
Returns `{:ok, record_with_rank}` or `{:error, :not_found}`.

# `list_leaderboard_groups`

```elixir
@spec list_leaderboard_groups(keyword()) :: [map()]
```

Lists unique leaderboard slugs with summary info.

Returns a list of maps with:
- `:slug` - the leaderboard slug
- `:title` - title from the latest leaderboard
- `:description` - description from the latest leaderboard
- `:active_id` - ID of the currently active leaderboard (or nil)
- `:latest_id` - ID of the most recent leaderboard
- `:season_count` - total number of leaderboards with this slug

# `list_leaderboards`

```elixir
@spec list_leaderboards(keyword()) :: [GameServer.Leaderboards.Leaderboard.t()]
```

Lists leaderboards with optional filters.

## Options

  * `:slug` - Filter by slug (returns all seasons of that leaderboard)
  * `:active` - If `true`, only active leaderboards. If `false`, only ended.
  * `:order_by` - Order by field: `:ends_at` or `:inserted_at` (default)
  * `:starts_after` - Only leaderboards that started after this DateTime
  * `:starts_before` - Only leaderboards that started before this DateTime
  * `:ends_after` - Only leaderboards that end after this DateTime
  * `:ends_before` - Only leaderboards that end before this DateTime
  * `:page` - Page number (default 1)
  * `:page_size` - Page size (default 25)

## Examples

    iex> list_leaderboards(active: true)
    [%Leaderboard{}, ...]

    iex> list_leaderboards(slug: "weekly_kills")
    [%Leaderboard{}, ...]

    iex> list_leaderboards(starts_after: ~U[2025-01-01 00:00:00Z])
    [%Leaderboard{}, ...]

# `list_leaderboards_by_slug`

```elixir
@spec list_leaderboards_by_slug(
  String.t(),
  keyword()
) :: [GameServer.Leaderboards.Leaderboard.t()]
```

Lists all leaderboards with the given slug (all seasons), ordered by end date.

# `list_records`

```elixir
@spec list_records(String.t(), GameServer.Types.pagination_opts()) :: [
  GameServer.Leaderboards.Record.t()
]
```

Lists records for a leaderboard, ordered by rank.

## Options

See `t:GameServer.Types.pagination_opts/0` for available options.

Returns records with `rank` field populated.

# `list_records_around_user`

```elixir
@spec list_records_around_user(String.t(), Ecto.UUID.t(), keyword()) :: [
  GameServer.Leaderboards.Record.t()
]
```

Lists records around a specific user (centered on their position).

Returns records above and below the user's rank.

## Options

  * `:limit` - Total number of records to return (default 11, centered on user)

# `resolve_slugs`

```elixir
@spec resolve_slugs([String.t()]) :: %{
  required(String.t()) =&gt; GameServer.Leaderboards.Leaderboard.t()
}
```

Resolves multiple slugs to their currently active leaderboards in a single query.

Returns a map of `slug => %Leaderboard{}` for each slug that has an active
leaderboard. Slugs with no active leaderboard are omitted from the result.

## Examples

    iex> resolve_slugs(["weekly_kills", "monthly_score", "nonexistent"])
    %{
      "weekly_kills" => %Leaderboard{id: 1, slug: "weekly_kills", ...},
      "monthly_score" => %Leaderboard{id: 5, slug: "monthly_score", ...}
    }

# `submit_label_score`

```elixir
@spec submit_label_score(String.t(), String.t(), integer(), map()) ::
  {:ok, GameServer.Leaderboards.Record.t()} | {:error, term()}
```

Submit a score for a label-based (non-user) record.

Works just like `submit_score/4` but uses a string label instead of a user ID.
This is useful for statistics, rankings by category, etc.

## Examples

    iex> submit_label_score(leaderboard_id, "English", 42)
    {:ok, %Record{label: "English", score: 42}}

# `submit_score`

```elixir
@spec submit_score(String.t(), Ecto.UUID.t(), integer(), map()) ::
  {:ok, GameServer.Leaderboards.Record.t()} | {:error, term()}
```

Submits a score for a user on a leaderboard.

This is a server-only function — there is no public API for score submission.
The score is processed according to the leaderboard's operator:

  * `:set` — Always replace with new score
  * `:best` — Only update if new score is better (respects sort_order)
  * `:incr` — Add to existing score
  * `:decr` — Subtract from existing score

To submit to a leaderboard by slug, first get the active leaderboard ID:

    leaderboard = Leaderboards.get_active_leaderboard_by_slug("weekly_kills")
    Leaderboards.submit_score(leaderboard.id, user_id, 10)

## Examples

    iex> submit_score(123, user_id, 10)
    {:ok, %Record{score: 10}}

    iex> submit_score(123, user_id, 5, %{weapon: "sword"})
    {:ok, %Record{score: 15, metadata: %{weapon: "sword"}}}

# `update_leaderboard`

```elixir
@spec update_leaderboard(
  GameServer.Leaderboards.Leaderboard.t(),
  GameServer.Types.leaderboard_update_attrs()
) ::
  {:ok, GameServer.Leaderboards.Leaderboard.t()} | {:error, Ecto.Changeset.t()}
```

Updates an existing leaderboard.

Note: `slug`, `sort_order`, and `operator` cannot be changed after creation.

## Attributes

See `t:GameServer.Types.leaderboard_update_attrs/0` for available fields.

# `update_record`

```elixir
@spec update_record(GameServer.Leaderboards.Record.t(), map()) ::
  {:ok, GameServer.Leaderboards.Record.t()} | {:error, Ecto.Changeset.t()}
```

Updates an existing record.

Intended for internal/admin usage.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
