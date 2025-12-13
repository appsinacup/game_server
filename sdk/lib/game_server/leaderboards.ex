defmodule GameServer.Leaderboards do
  @moduledoc ~S"""
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
  
      # Submit score (server-only): resolve the active leaderboard first and submit by integer ID
      leaderboard = Leaderboards.get_active_leaderboard_by_slug("weekly_kills")
      {:ok, record} = Leaderboards.submit_score(leaderboard.id, user_id, 10)
  
      # List records with rank (use integer leaderboard id)
      records = Leaderboards.list_records(leaderboard.id, page: 1, limit: 25)
  
      # Get user's record (use integer leaderboard id)
      {:ok, record} = Leaderboards.get_user_record(leaderboard.id, user_id)
  

  **Note:** This is an SDK stub. Calling these functions will raise an error.
  The actual implementation runs on the GameServer.
  """

  @doc ~S"""
    Returns a changeset for a leaderboard (used in forms).
    
  """
  def change_leaderboard(_leaderboard) do
    raise "GameServer.Leaderboards.change_leaderboard/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Returns a changeset for a leaderboard (used in forms).
    
  """
  def change_leaderboard(_leaderboard, _attrs) do
    raise "GameServer.Leaderboards.change_leaderboard/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Returns a changeset for a record (used in admin forms).
    
  """
  def change_record(_record) do
    raise "GameServer.Leaderboards.change_record/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Returns a changeset for a record (used in admin forms).
    
  """
  def change_record(_record, _attrs) do
    raise "GameServer.Leaderboards.change_record/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Count all leaderboard records across all leaderboards.
    
  """
  @spec count_all_records() :: non_neg_integer()
  def count_all_records() do
    raise "GameServer.Leaderboards.count_all_records/0 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Counts unique leaderboard slugs.
    
  """
  @spec count_leaderboard_groups() :: non_neg_integer()
  def count_leaderboard_groups() do
    raise "GameServer.Leaderboards.count_leaderboard_groups/0 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Counts leaderboards matching the given filters.
    
    Accepts the same filter options as `list_leaderboards/1`.
    
  """
  def count_leaderboards() do
    raise "GameServer.Leaderboards.count_leaderboards/0 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Counts leaderboards matching the given filters.
    
    Accepts the same filter options as `list_leaderboards/1`.
    
  """
  @spec count_leaderboards(keyword()) :: non_neg_integer()
  def count_leaderboards(_opts) do
    raise "GameServer.Leaderboards.count_leaderboards/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Counts records for a leaderboard.
    
  """
  @spec count_records(integer()) :: non_neg_integer()
  def count_records(_leaderboard_id) do
    raise "GameServer.Leaderboards.count_records/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Creates a new leaderboard.
    
    ## Attributes
    
    See `t:GameServer.Types.leaderboard_create_attrs/0` for available fields.
    
    ## Examples
    
        iex> create_leaderboard(%{slug: "my_lb", title: "My Leaderboard"})
        {:ok, %Leaderboard{}}
    
        iex> create_leaderboard(%{slug: "", title: ""})
        {:error, %Ecto.Changeset{}}
    
  """
  @spec create_leaderboard(GameServer.Types.leaderboard_create_attrs()) ::
  {:ok, GameServer.Leaderboards.Leaderboard.t()} | {:error, Ecto.Changeset.t()}
  def create_leaderboard(_attrs) do
    raise "GameServer.Leaderboards.create_leaderboard/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Deletes a leaderboard and all its records.
    
  """
  @spec delete_leaderboard(GameServer.Leaderboards.Leaderboard.t()) ::
  {:ok, GameServer.Leaderboards.Leaderboard.t()} | {:error, Ecto.Changeset.t()}
  def delete_leaderboard(_leaderboard) do
    raise "GameServer.Leaderboards.delete_leaderboard/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Deletes a record.
    
  """
  def delete_record(_record) do
    raise "GameServer.Leaderboards.delete_record/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Deletes a user's record from a leaderboard.
    Accepts either leaderboard ID (integer) or slug (string).
    
  """
  @spec delete_user_record(integer() | String.t(), integer()) ::
  {:ok, GameServer.Leaderboards.Record.t()} | {:error, :not_found}
  def delete_user_record(_id_or_slug, _user_id) do
    raise "GameServer.Leaderboards.delete_user_record/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Ends a leaderboard by setting `ends_at` to the current time.
    
  """
  def end_leaderboard(_leaderboard) do
    raise "GameServer.Leaderboards.end_leaderboard/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Gets the currently active leaderboard with the given slug.
    Returns `nil` if no active leaderboard exists.
    
    An active leaderboard is one that:
    - Has not ended (`ends_at` is nil or in the future)
    - Has started (`starts_at` is nil or in the past)
    
    If multiple active leaderboards exist with the same slug,
    returns the most recently created one.
    
  """
  @spec get_active_leaderboard_by_slug(String.t()) :: GameServer.Leaderboards.Leaderboard.t() | nil
  def get_active_leaderboard_by_slug(_slug) do
    raise "GameServer.Leaderboards.get_active_leaderboard_by_slug/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Gets a leaderboard by its integer ID.
    
    ## Examples
    
        iex> get_leaderboard(123)
        %Leaderboard{id: 123}
    
        iex> get_leaderboard(999)
        nil
    
  """
  @spec get_leaderboard(integer()) :: GameServer.Leaderboards.Leaderboard.t() | nil
  def get_leaderboard(_id) do
    raise "GameServer.Leaderboards.get_leaderboard/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Gets a leaderboard by its integer ID. Raises if not found.
    
  """
  @spec get_leaderboard!(integer()) :: GameServer.Leaderboards.Leaderboard.t()
  def get_leaderboard!(_id) do
    raise "GameServer.Leaderboards.get_leaderboard!/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Gets a single record by leaderboard ID and user ID.
    
  """
  @spec get_record(integer(), integer()) :: GameServer.Leaderboards.Record.t() | nil
  def get_record(_leaderboard_id, _user_id) do
    raise "GameServer.Leaderboards.get_record/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Gets a user's record with their rank.
    Returns `{:ok, record_with_rank}` or `{:error, :not_found}`.
    
  """
  @spec get_user_record(integer(), integer()) ::
  {:ok, GameServer.Leaderboards.Record.t()} | {:error, :not_found}
  def get_user_record(_leaderboard_id, _user_id) do
    raise "GameServer.Leaderboards.get_user_record/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Lists unique leaderboard slugs with summary info.
    
    Returns a list of maps with:
    - `:slug` - the leaderboard slug
    - `:title` - title from the latest leaderboard
    - `:description` - description from the latest leaderboard
    - `:active_id` - ID of the currently active leaderboard (or nil)
    - `:latest_id` - ID of the most recent leaderboard
    - `:season_count` - total number of leaderboards with this slug
    
  """
  def list_leaderboard_groups() do
    raise "GameServer.Leaderboards.list_leaderboard_groups/0 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Lists unique leaderboard slugs with summary info.
    
    Returns a list of maps with:
    - `:slug` - the leaderboard slug
    - `:title` - title from the latest leaderboard
    - `:description` - description from the latest leaderboard
    - `:active_id` - ID of the currently active leaderboard (or nil)
    - `:latest_id` - ID of the most recent leaderboard
    - `:season_count` - total number of leaderboards with this slug
    
  """
  @spec list_leaderboard_groups(keyword()) :: [map()]
  def list_leaderboard_groups(_opts) do
    raise "GameServer.Leaderboards.list_leaderboard_groups/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
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
    
  """
  def list_leaderboards() do
    raise "GameServer.Leaderboards.list_leaderboards/0 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
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
    
  """
  @spec list_leaderboards(keyword()) :: [GameServer.Leaderboards.Leaderboard.t()]
  def list_leaderboards(_opts) do
    raise "GameServer.Leaderboards.list_leaderboards/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Lists all leaderboards with the given slug (all seasons), ordered by end date.
    
  """
  def list_leaderboards_by_slug(_slug) do
    raise "GameServer.Leaderboards.list_leaderboards_by_slug/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Lists all leaderboards with the given slug (all seasons), ordered by end date.
    
  """
  @spec list_leaderboards_by_slug(
  String.t(),
  keyword()
) :: [GameServer.Leaderboards.Leaderboard.t()]
  def list_leaderboards_by_slug(_slug, _opts) do
    raise "GameServer.Leaderboards.list_leaderboards_by_slug/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Lists records for a leaderboard, ordered by rank.
    
    ## Options
    
    See `t:GameServer.Types.pagination_opts/0` for available options.
    
    Returns records with `rank` field populated.
    
  """
  def list_records(_leaderboard_id) do
    raise "GameServer.Leaderboards.list_records/1 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Lists records for a leaderboard, ordered by rank.
    
    ## Options
    
    See `t:GameServer.Types.pagination_opts/0` for available options.
    
    Returns records with `rank` field populated.
    
  """
  @spec list_records(integer(), GameServer.Types.pagination_opts()) :: [
  GameServer.Leaderboards.Record.t()
]
  def list_records(_leaderboard_id, _opts) do
    raise "GameServer.Leaderboards.list_records/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Lists records around a specific user (centered on their position).
    
    Returns records above and below the user's rank.
    
    ## Options
    
      * `:limit` - Total number of records to return (default 11, centered on user)
    
  """
  def list_records_around_user(_leaderboard_id, _user_id) do
    raise "GameServer.Leaderboards.list_records_around_user/2 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Lists records around a specific user (centered on their position).
    
    Returns records above and below the user's rank.
    
    ## Options
    
      * `:limit` - Total number of records to return (default 11, centered on user)
    
  """
  @spec list_records_around_user(integer(), integer(), keyword()) :: [GameServer.Leaderboards.Record.t()]
  def list_records_around_user(_leaderboard_id, _user_id, _opts) do
    raise "GameServer.Leaderboards.list_records_around_user/3 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
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
    
  """
  def submit_score(_leaderboard_id, _user_id, _score) do
    raise "GameServer.Leaderboards.submit_score/3 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
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
    
  """
  @spec submit_score(integer(), integer(), integer(), map()) ::
  {:ok, GameServer.Leaderboards.Record.t()} | {:error, term()}
  def submit_score(_leaderboard_id, _user_id, _score, _metadata) do
    raise "GameServer.Leaderboards.submit_score/4 is a stub - only available at runtime on GameServer"
  end


  @doc ~S"""
    Updates an existing leaderboard.
    
    Note: `slug`, `sort_order`, and `operator` cannot be changed after creation.
    
    ## Attributes
    
    See `t:GameServer.Types.leaderboard_update_attrs/0` for available fields.
    
  """
  @spec update_leaderboard(
  GameServer.Leaderboards.Leaderboard.t(),
  GameServer.Types.leaderboard_update_attrs()
) :: {:ok, GameServer.Leaderboards.Leaderboard.t()} | {:error, Ecto.Changeset.t()}
  def update_leaderboard(_leaderboard, _attrs) do
    raise "GameServer.Leaderboards.update_leaderboard/2 is a stub - only available at runtime on GameServer"
  end

end
