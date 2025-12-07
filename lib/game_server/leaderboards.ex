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

  See `t:GameServer.Types.leaderboard_create_attrs/0` for available fields.

  ## Examples

      iex> create_leaderboard(%{slug: "my_lb", title: "My Leaderboard"})
      {:ok, %Leaderboard{}}

      iex> create_leaderboard(%{slug: "", title: ""})
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

  Note: `slug`, `sort_order`, and `operator` cannot be changed after creation.

  ## Attributes

  See `t:GameServer.Types.leaderboard_update_attrs/0` for available fields.
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
  Gets a leaderboard by its integer ID.

  ## Examples

      iex> get_leaderboard(123)
      %Leaderboard{id: 123}

      iex> get_leaderboard(999)
      nil
  """
  @spec get_leaderboard(integer()) :: Leaderboard.t() | nil
  def get_leaderboard(id) when is_integer(id) do
    Repo.get(Leaderboard, id)
  end

  @doc """
  Gets a leaderboard by its integer ID. Raises if not found.
  """
  @spec get_leaderboard!(integer()) :: Leaderboard.t()
  def get_leaderboard!(id) when is_integer(id) do
    Repo.get!(Leaderboard, id)
  end

  @doc """
  Gets the currently active leaderboard with the given slug.
  Returns `nil` if no active leaderboard exists.

  An active leaderboard is one that:
  - Has not ended (`ends_at` is nil or in the future)
  - Has started (`starts_at` is nil or in the past)

  If multiple active leaderboards exist with the same slug,
  returns the most recently created one.
  """
  @spec get_active_leaderboard_by_slug(String.t()) :: Leaderboard.t() | nil
  def get_active_leaderboard_by_slug(slug) when is_binary(slug) do
    now = DateTime.utc_now()

    from(lb in Leaderboard,
      where: lb.slug == ^slug,
      where: is_nil(lb.ends_at) or lb.ends_at > ^now,
      where: is_nil(lb.starts_at) or lb.starts_at <= ^now,
      order_by: [desc: lb.inserted_at, desc: lb.id],
      limit: 1
    )
    |> Repo.one()
  end

  @doc """
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
  def list_leaderboard_groups(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 25)
    offset = (page - 1) * page_size

    # Get unique slugs ordered by most recent end date (nulls first = still active)
    slugs_query =
      from lb in Leaderboard,
        select: lb.slug,
        group_by: lb.slug,
        order_by: [desc_nulls_first: max(lb.ends_at)],
        offset: ^offset,
        limit: ^page_size

    slugs = Repo.all(slugs_query)

    # For each slug, get the group info
    Enum.map(slugs, fn slug ->
      build_group_info(slug)
    end)
  end

  defp build_group_info(slug) do
    now = DateTime.utc_now()

    # Get the latest leaderboard by end date (nulls first = active/permanent ones)
    latest =
      from(lb in Leaderboard,
        where: lb.slug == ^slug,
        order_by: [desc_nulls_first: lb.ends_at],
        limit: 1
      )
      |> Repo.one()

    # Get the active leaderboard (if any)
    active =
      from(lb in Leaderboard,
        where: lb.slug == ^slug,
        where: is_nil(lb.ends_at) or lb.ends_at > ^now,
        where: is_nil(lb.starts_at) or lb.starts_at <= ^now,
        order_by: [desc_nulls_first: lb.ends_at],
        limit: 1
      )
      |> Repo.one()

    # Count seasons
    season_count =
      from(lb in Leaderboard, where: lb.slug == ^slug)
      |> Repo.aggregate(:count, :id)

    %{
      slug: slug,
      title: latest.title,
      description: latest.description,
      active_id: active && active.id,
      latest_id: latest.id,
      season_count: season_count
    }
  end

  @doc """
  Counts unique leaderboard slugs.
  """
  @spec count_leaderboard_groups() :: non_neg_integer()
  def count_leaderboard_groups do
    from(lb in Leaderboard,
      select: count(lb.slug, :distinct)
    )
    |> Repo.one()
  end

  @doc """
  Lists all leaderboards with the given slug (all seasons), ordered by end date.
  """
  @spec list_leaderboards_by_slug(String.t(), keyword()) :: [Leaderboard.t()]
  def list_leaderboards_by_slug(slug, opts \\ []) when is_binary(slug) do
    opts
    |> Keyword.put(:slug, slug)
    |> Keyword.put_new(:order_by, :ends_at)
    |> list_leaderboards()
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
  @spec list_leaderboards(keyword()) :: [Leaderboard.t()]
  def list_leaderboards(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 25)
    offset = (page - 1) * page_size
    order_by = Keyword.get(opts, :order_by, :inserted_at)

    opts
    |> build_leaderboard_query()
    |> apply_order_by(order_by)
    |> offset(^offset)
    |> limit(^page_size)
    |> Repo.all()
  end

  @doc """
  Counts leaderboards matching the given filters.

  Accepts the same filter options as `list_leaderboards/1`.
  """
  @spec count_leaderboards(keyword()) :: non_neg_integer()
  def count_leaderboards(opts \\ []) do
    opts
    |> build_leaderboard_query()
    |> Repo.aggregate(:count, :id)
  end

  defp apply_order_by(query, :ends_at) do
    order_by(query, [lb], desc_nulls_first: lb.ends_at)
  end

  defp apply_order_by(query, :inserted_at) do
    order_by(query, [lb], desc: lb.inserted_at)
  end

  defp apply_order_by(query, _), do: order_by(query, [lb], desc: lb.inserted_at)

  defp build_leaderboard_query(opts) do
    now = DateTime.utc_now()
    base = from(lb in Leaderboard)

    base
    |> maybe_filter_slug(Keyword.get(opts, :slug))
    |> maybe_filter_active(Keyword.get(opts, :active), now)
    |> maybe_filter_starts_after(Keyword.get(opts, :starts_after))
    |> maybe_filter_starts_before(Keyword.get(opts, :starts_before))
    |> maybe_filter_ends_after(Keyword.get(opts, :ends_after))
    |> maybe_filter_ends_before(Keyword.get(opts, :ends_before))
  end

  defp maybe_filter_slug(query, nil), do: query
  defp maybe_filter_slug(query, slug), do: from(lb in query, where: lb.slug == ^slug)

  defp maybe_filter_active(query, nil, _now), do: query

  defp maybe_filter_active(query, true, now) do
    from(lb in query, where: is_nil(lb.ends_at) or lb.ends_at > ^now)
  end

  defp maybe_filter_active(query, false, now) do
    from(lb in query, where: not is_nil(lb.ends_at) and lb.ends_at <= ^now)
  end

  defp maybe_filter_starts_after(query, nil), do: query

  defp maybe_filter_starts_after(query, datetime) do
    from(lb in query, where: lb.starts_at > ^datetime)
  end

  defp maybe_filter_starts_before(query, nil), do: query

  defp maybe_filter_starts_before(query, datetime) do
    from(lb in query, where: lb.starts_at <= ^datetime)
  end

  defp maybe_filter_ends_after(query, nil), do: query

  defp maybe_filter_ends_after(query, datetime) do
    from(lb in query, where: lb.ends_at > ^datetime)
  end

  defp maybe_filter_ends_before(query, nil), do: query

  defp maybe_filter_ends_before(query, datetime) do
    from(lb in query, where: lb.ends_at <= ^datetime)
  end

  @doc """
  Ends a leaderboard by setting `ends_at` to the current time.
  """
  def end_leaderboard(%Leaderboard{} = leaderboard) do
    update_leaderboard(leaderboard, %{ends_at: DateTime.utc_now(:second)})
  end

  def end_leaderboard(id_or_slug) when is_integer(id_or_slug) or is_binary(id_or_slug) do
    case get_leaderboard(id_or_slug) do
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
          {:ok, Record.t()} | {:error, term()}
  def submit_score(leaderboard_id, user_id, score, metadata \\ %{})
      when is_integer(leaderboard_id) and is_integer(user_id) and is_integer(score) do
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
  Gets a single record by leaderboard ID and user ID.
  """
  @spec get_record(integer(), integer()) :: Record.t() | nil
  def get_record(leaderboard_id, user_id) when is_integer(leaderboard_id) do
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
  @spec get_user_record(integer(), integer()) ::
          {:ok, Record.t()} | {:error, :not_found}
  def get_user_record(leaderboard_id, user_id) when is_integer(leaderboard_id) do
    case get_leaderboard(leaderboard_id) do
      nil ->
        {:error, :not_found}

      leaderboard ->
        case get_record(leaderboard.id, user_id) do
          nil ->
            {:error, :not_found}

          record ->
            rank = calculate_rank(leaderboard.id, record.score)
            {:ok, %{record | rank: rank}}
        end
    end
  end

  defp calculate_rank(leaderboard_id, score) when is_integer(leaderboard_id) do
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

  See `t:GameServer.Types.pagination_opts/0` for available options.

  Returns records with `rank` field populated.
  """
  @spec list_records(integer(), Types.pagination_opts()) :: [Record.t()]
  def list_records(leaderboard_id, opts \\ []) when is_integer(leaderboard_id) do
    case get_leaderboard(leaderboard_id) do
      nil ->
        []

      leaderboard ->
        page = Keyword.get(opts, :page, 1)
        page_size = Keyword.get(opts, :page_size, 25)
        offset = (page - 1) * page_size

        order_by =
          case leaderboard.sort_order do
            :desc -> [desc: :score, asc: :updated_at]
            :asc -> [asc: :score, asc: :updated_at]
          end

        records =
          from(r in Record,
            where: r.leaderboard_id == ^leaderboard.id,
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
  end

  @doc """
  Counts records for a leaderboard.
  """
  @spec count_records(integer()) :: non_neg_integer()
  def count_records(leaderboard_id) when is_integer(leaderboard_id) do
    from(r in Record, where: r.leaderboard_id == ^leaderboard_id)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Count all leaderboard records across all leaderboards.
  """
  @spec count_all_records() :: non_neg_integer()
  def count_all_records do
    from(r in Record)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Lists records around a specific user (centered on their position).

  Returns records above and below the user's rank.

  ## Options

    * `:limit` - Total number of records to return (default 11, centered on user)
  """
  @spec list_records_around_user(integer(), integer(), keyword()) :: [Record.t()]
  def list_records_around_user(leaderboard_id, user_id, opts \\ [])
      when is_integer(leaderboard_id) do
    case get_leaderboard(leaderboard_id) do
      nil ->
        []

      leaderboard ->
        limit = Keyword.get(opts, :limit, 11)
        half = div(limit, 2)

        case get_user_record(leaderboard.id, user_id) do
          {:error, :not_found} ->
            []

          {:ok, user_record} ->
            user_rank = user_record.rank

            # Calculate offset to center on user
            start_rank = max(1, user_rank - half)
            offset = start_rank - 1

            order_by =
              case leaderboard.sort_order do
                :desc -> [desc: :score, asc: :updated_at]
                :asc -> [asc: :score, asc: :updated_at]
              end

            records =
              from(r in Record,
                where: r.leaderboard_id == ^leaderboard.id,
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
  end

  @doc """
  Deletes a record.
  """
  def delete_record(%Record{} = record) do
    Repo.delete(record)
  end

  @doc """
  Deletes a user's record from a leaderboard.
  Accepts either leaderboard ID (integer) or slug (string).
  """
  @spec delete_user_record(integer() | String.t(), integer()) ::
          {:ok, Record.t()} | {:error, :not_found}
  def delete_user_record(id_or_slug, user_id) do
    case get_leaderboard(id_or_slug) do
      nil ->
        {:error, :not_found}

      leaderboard ->
        case get_record(leaderboard.id, user_id) do
          nil -> {:error, :not_found}
          record -> delete_record(record)
        end
    end
  end

  @doc """
  Returns a changeset for a record (used in admin forms).
  """
  def change_record(%Record{} = record, attrs \\ %{}) do
    Record.changeset(record, attrs)
  end
end
