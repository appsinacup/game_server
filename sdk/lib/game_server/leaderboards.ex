defmodule GameServer.Leaderboards do
  @moduledoc """
  The Leaderboards context.
  
  Provides server-authoritative leaderboard management. Scores can only be
  submitted via server-side code — there is no public API for score submission.
  
  ## Usage
  
      # Create a leaderboard
      {:ok, lb} = Leaderboards.create_leaderboard(%{
        id: "weekly_kills_w49",
        title: "Weekly Kills - Week 49",
        sort_order: :desc,
        operator: :incr
      })
  
      # Submit score (server-only)
      {:ok, record} = Leaderboards.submit_score("weekly_kills_w49", user_id, 10)
  
      # List records with rank
      records = Leaderboards.list_records("weekly_kills_w49", page: 1, limit: 25)
  
      # Get user's record
      {:ok, record} = Leaderboards.get_user_record("weekly_kills_w49", user_id)
  

  **Note:** This is an SDK stub. Calling these functions will raise an error.
  The actual implementation runs on the GameServer.
  """

  @doc """
    Gets a leaderboard by ID. Returns `nil` if not found.
    
  """
  @spec get_leaderboard(String.t()) :: GameServer.Leaderboards.Leaderboard.t() | nil
  def get_leaderboard(_id) do
    raise "GameServer.Leaderboards.get_leaderboard/1 is a stub - only available at runtime on GameServer"
  end


  @doc """
    Creates a new leaderboard.
    
    ## Attributes
    
    See `GameServer.Types.leaderboard_create_attrs/0` for available fields.
    
    ## Examples
    
        iex> create_leaderboard(%{id: "my_lb", title: "My Leaderboard"})
        {:ok, %Leaderboard{}}
    
        iex> create_leaderboard(%{id: "", title: ""})
        {:error, %Ecto.Changeset{}}
    
  """
  @spec create_leaderboard(GameServer.Types.leaderboard_create_attrs()) ::
  {:ok, GameServer.Leaderboards.Leaderboard.t()} | {:error, Ecto.Changeset.t()}
  def create_leaderboard(_attrs) do
    raise "GameServer.Leaderboards.create_leaderboard/1 is a stub - only available at runtime on GameServer"
  end


  @doc """
    Updates an existing leaderboard.
    
    Note: `id`, `sort_order`, and `operator` cannot be changed after creation.
    
    ## Attributes
    
    See `GameServer.Types.leaderboard_update_attrs/0` for available fields.
    
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
    
      * `:active` - If `true`, only active leaderboards. If `false`, only ended.
      * `:page` - Page number (default 1)
      * `:page_size` - Page size (default 25)
    
    ## Examples
    
        iex> list_leaderboards(active: true)
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
    
    ## Examples
    
        iex> submit_score("weekly_kills", user_id, 10)
        {:ok, %Record{score: 10}}
    
        iex> submit_score("weekly_kills", user_id, 5, %{weapon: "sword"})
        {:ok, %Record{score: 15, metadata: %{weapon: "sword"}}}
    
  """
  @spec submit_score(String.t(), integer(), integer(), map()) ::
  {:ok, GameServer.Leaderboards.Record.t()} | {:error, term()}
  def submit_score(_leaderboard_id, _user_id, _score, _metadata) do
    raise "GameServer.Leaderboards.submit_score/4 is a stub - only available at runtime on GameServer"
  end


  @doc """
    Lists records for a leaderboard, ordered by rank.
    
    ## Options
    
    See `GameServer.Types.pagination_opts/0` for available options.
    
    Returns records with `rank` field populated.
    
  """
  @spec list_records(String.t(), GameServer.Types.pagination_opts()) :: [
  GameServer.Leaderboards.Record.t()
]
  def list_records(_leaderboard_id, _opts) do
    raise "GameServer.Leaderboards.list_records/2 is a stub - only available at runtime on GameServer"
  end


  @doc """
    Gets a user's record with their rank.
    Returns `{:ok, record_with_rank}` or `{:error, :not_found}`.
    
  """
  @spec get_user_record(String.t(), integer()) ::
  {:ok, GameServer.Leaderboards.Record.t()} | {:error, :not_found}
  def get_user_record(_leaderboard_id, _user_id) do
    raise "GameServer.Leaderboards.get_user_record/2 is a stub - only available at runtime on GameServer"
  end


  @doc """
    Deletes a user's record from a leaderboard.
    
  """
  @spec delete_user_record(String.t(), integer()) ::
  {:ok, GameServer.Leaderboards.Record.t()} | {:error, :not_found}
  def delete_user_record(_leaderboard_id, _user_id) do
    raise "GameServer.Leaderboards.delete_user_record/2 is a stub - only available at runtime on GameServer"
  end

end
