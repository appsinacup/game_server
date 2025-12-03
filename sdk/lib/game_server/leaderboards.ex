defmodule GameServer.Leaderboards do
  @moduledoc """
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

  @doc """
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


  @doc """
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


  @doc """
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


  @doc """
    Deletes a leaderboard and all its records.

  """
  @spec delete_leaderboard(GameServer.Leaderboards.Leaderboard.t()) ::
  {:ok, GameServer.Leaderboards.Leaderboard.t()} | {:error, Ecto.Changeset.t()}
  def delete_leaderboard(_leaderboard) do
    raise "GameServer.Leaderboards.delete_leaderboard/1 is a stub - only available at runtime on GameServer"
  end


  @doc """
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


  @doc """
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


  @doc """
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


  @doc """
    Gets a user's record with their rank.
    Returns `{:ok, record_with_rank}` or `{:error, :not_found}`.

  """
  @spec get_user_record(integer(), integer()) ::
  {:ok, GameServer.Leaderboards.Record.t()} | {:error, :not_found}
  def get_user_record(_leaderboard_id, _user_id) do
    raise "GameServer.Leaderboards.get_user_record/2 is a stub - only available at runtime on GameServer"
  end


  @doc """
    Deletes a user's record from a leaderboard.
    Accepts either leaderboard ID (integer) or slug (string).

  """
  @spec delete_user_record(integer() | String.t(), integer()) ::
  {:ok, GameServer.Leaderboards.Record.t()} | {:error, :not_found}
  def delete_user_record(_id_or_slug, _user_id) do
    raise "GameServer.Leaderboards.delete_user_record/2 is a stub - only available at runtime on GameServer"
  end

end
