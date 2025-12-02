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
  """

  import Ecto.Query, warn: false
  alias GameServer.Repo
  alias GameServer.Types

  alias GameServer.Leaderboards.Leaderboard
  alias GameServer.Leaderboards.Record

  # ---------------------------------------------------------------------------
  # Leaderboard CRUD
  # ---------------------------------------------------------------------------

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
  @spec create_leaderboard(Types.leaderboard_create_attrs()) ::
          {:ok, Leaderboard.t()} | {:error, Ecto.Changeset.t()}
  def create_leaderboard(attrs) do
    %Leaderboard{}
    |> Leaderboard.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing leaderboard.

  Note: `id`, `sort_order`, and `operator` cannot be changed after creation.

  ## Attributes

  See `GameServer.Types.leaderboard_update_attrs/0` for available fields.
  """
  @spec update_leaderboard(Leaderboard.t(), Types.leaderboard_update_attrs()) ::
          {:ok, Leaderboard.t()} | {:error, Ecto.Changeset.t()}
  def update_leaderboard(%Leaderboard{} = leaderboard, attrs) do
    leaderboard
    |> Leaderboard.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a leaderboard and all its records.
  """
  @spec delete_leaderboard(Leaderboard.t()) ::
          {:ok, Leaderboard.t()} | {:error, Ecto.Changeset.t()}
  def delete_leaderboard(%Leaderboard{} = leaderboard) do
    Repo.delete(leaderboard)
  end

  @doc """
  Gets a leaderboard by ID. Returns `nil` if not found.
  """
  @spec get_leaderboard(String.t()) :: Leaderboard.t() | nil
  def get_leaderboard(id) when is_binary(id) do
    Repo.get(Leaderboard, id)
  end

  @doc """
  Gets a leaderboard by ID. Raises if not found.
  """
  def get_leaderboard!(id) when is_binary(id) do
    Repo.get!(Leaderboard, id)
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
  @spec list_leaderboards(keyword()) :: [Leaderboard.t()]
  def list_leaderboards(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 25)
    offset = (page - 1) * page_size

    base = from(lb in Leaderboard)

    base =
      case Keyword.get(opts, :active) do
        true ->
          from lb in base, where: is_nil(lb.ends_at) or lb.ends_at > ^DateTime.utc_now()

        false ->
          from lb in base, where: not is_nil(lb.ends_at) and lb.ends_at <= ^DateTime.utc_now()

        nil ->
          base
      end

    from(lb in base, order_by: [desc: lb.inserted_at], offset: ^offset, limit: ^page_size)
    |> Repo.all()
  end

  @doc """
  Counts leaderboards matching the given filters.
  """
  def count_leaderboards(opts \\ []) do
    base = from(lb in Leaderboard)

    base =
      case Keyword.get(opts, :active) do
        true ->
          from lb in base, where: is_nil(lb.ends_at) or lb.ends_at > ^DateTime.utc_now()

        false ->
          from lb in base, where: not is_nil(lb.ends_at) and lb.ends_at <= ^DateTime.utc_now()

        nil ->
          base
      end

    Repo.aggregate(base, :count, :id)
  end

  @doc """
  Ends a leaderboard by setting `ends_at` to the current time.
  """
  def end_leaderboard(%Leaderboard{} = leaderboard) do
    update_leaderboard(leaderboard, %{ends_at: DateTime.utc_now(:second)})
  end

  def end_leaderboard(id) when is_binary(id) do
    case get_leaderboard(id) do
      nil -> {:error, :not_found}
      lb -> end_leaderboard(lb)
    end
  end

  @doc """
  Returns a changeset for a leaderboard (used in forms).
  """
  def change_leaderboard(%Leaderboard{} = leaderboard, attrs \\ %{}) do
    Leaderboard.changeset(leaderboard, attrs)
  end

  # ---------------------------------------------------------------------------
  # Score Submission (Server-Only)
  # ---------------------------------------------------------------------------

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
          {:ok, Record.t()} | {:error, term()}
  def submit_score(leaderboard_id, user_id, score, metadata \\ %{})
      when is_binary(leaderboard_id) and is_integer(user_id) and is_integer(score) do
    case get_leaderboard(leaderboard_id) do
      nil ->
        {:error, :leaderboard_not_found}

      leaderboard ->
        # Check if leaderboard is still active
        if Leaderboard.ended?(leaderboard) do
          {:error, :leaderboard_ended}
        else
          do_submit_score(leaderboard, user_id, score, metadata)
        end
    end
  end

  defp do_submit_score(leaderboard, user_id, score, metadata) do
    case get_record(leaderboard.id, user_id) do
      nil ->
        # Create new record
        %Record{}
        |> Record.changeset(%{
          leaderboard_id: leaderboard.id,
          user_id: user_id,
          score: score,
          metadata: metadata
        })
        |> Repo.insert()

      existing ->
        # Update existing record based on operator
        new_score = calculate_new_score(leaderboard, existing.score, score)
        new_metadata = if metadata == %{}, do: existing.metadata, else: metadata

        existing
        |> Record.update_changeset(%{score: new_score, metadata: new_metadata})
        |> Repo.update()
    end
  end

  defp calculate_new_score(leaderboard, current_score, new_score) do
    case leaderboard.operator do
      :set ->
        new_score

      :best ->
        case leaderboard.sort_order do
          :desc -> max(current_score, new_score)
          :asc -> min(current_score, new_score)
        end

      :incr ->
        current_score + new_score

      :decr ->
        current_score - new_score
    end
  end

  # ---------------------------------------------------------------------------
  # Record Queries
  # ---------------------------------------------------------------------------

  @doc """
  Gets a single record by leaderboard and user ID.
  """
  def get_record(leaderboard_id, user_id) do
    from(r in Record,
      where: r.leaderboard_id == ^leaderboard_id and r.user_id == ^user_id,
      preload: [:user]
    )
    |> Repo.one()
  end

  @doc """
  Gets a user's record with their rank.
  Returns `{:ok, record_with_rank}` or `{:error, :not_found}`.
  """
  @spec get_user_record(String.t(), integer()) :: {:ok, Record.t()} | {:error, :not_found}
  def get_user_record(leaderboard_id, user_id) do
    case get_record(leaderboard_id, user_id) do
      nil ->
        {:error, :not_found}

      record ->
        rank = calculate_rank(leaderboard_id, record.score)
        {:ok, %{record | rank: rank}}
    end
  end

  defp calculate_rank(leaderboard_id, score) do
    leaderboard = get_leaderboard!(leaderboard_id)

    # Count how many records have a better score
    query =
      case leaderboard.sort_order do
        :desc ->
          from r in Record,
            where: r.leaderboard_id == ^leaderboard_id and r.score > ^score,
            select: count(r.id)

        :asc ->
          from r in Record,
            where: r.leaderboard_id == ^leaderboard_id and r.score < ^score,
            select: count(r.id)
      end

    Repo.one(query) + 1
  end

  @doc """
  Lists records for a leaderboard, ordered by rank.

  ## Options

  See `GameServer.Types.pagination_opts/0` for available options.

  Returns records with `rank` field populated.
  """
  @spec list_records(String.t(), Types.pagination_opts()) :: [Record.t()]
  def list_records(leaderboard_id, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 25)
    offset = (page - 1) * page_size

    leaderboard = get_leaderboard!(leaderboard_id)

    order_by =
      case leaderboard.sort_order do
        :desc -> [desc: :score, asc: :updated_at]
        :asc -> [asc: :score, asc: :updated_at]
      end

    records =
      from(r in Record,
        where: r.leaderboard_id == ^leaderboard_id,
        order_by: ^order_by,
        offset: ^offset,
        limit: ^page_size,
        preload: [:user]
      )
      |> Repo.all()

    # Add rank to each record
    records
    |> Enum.with_index(offset + 1)
    |> Enum.map(fn {record, rank} -> %{record | rank: rank} end)
  end

  @doc """
  Counts records for a leaderboard.
  """
  def count_records(leaderboard_id) do
    from(r in Record, where: r.leaderboard_id == ^leaderboard_id)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Lists records around a specific user (centered on their position).

  Returns records above and below the user's rank.

  ## Options

    * `:limit` - Total number of records to return (default 11, centered on user)
  """
  def list_records_around_user(leaderboard_id, user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 11)
    half = div(limit, 2)

    case get_user_record(leaderboard_id, user_id) do
      {:error, :not_found} ->
        []

      {:ok, user_record} ->
        user_rank = user_record.rank

        # Calculate offset to center on user
        start_rank = max(1, user_rank - half)
        offset = start_rank - 1

        leaderboard = get_leaderboard!(leaderboard_id)

        order_by =
          case leaderboard.sort_order do
            :desc -> [desc: :score, asc: :updated_at]
            :asc -> [asc: :score, asc: :updated_at]
          end

        records =
          from(r in Record,
            where: r.leaderboard_id == ^leaderboard_id,
            order_by: ^order_by,
            offset: ^offset,
            limit: ^limit,
            preload: [:user]
          )
          |> Repo.all()

        # Add rank to each record
        records
        |> Enum.with_index(start_rank)
        |> Enum.map(fn {record, rank} -> %{record | rank: rank} end)
    end
  end

  @doc """
  Deletes a record.
  """
  def delete_record(%Record{} = record) do
    Repo.delete(record)
  end

  @doc """
  Deletes a user's record from a leaderboard.
  """
  @spec delete_user_record(String.t(), integer()) :: {:ok, Record.t()} | {:error, :not_found}
  def delete_user_record(leaderboard_id, user_id) do
    case get_record(leaderboard_id, user_id) do
      nil -> {:error, :not_found}
      record -> delete_record(record)
    end
  end

  @doc """
  Returns a changeset for a record (used in admin forms).
  """
  def change_record(%Record{} = record, attrs \\ %{}) do
    Record.changeset(record, attrs)
  end
end
