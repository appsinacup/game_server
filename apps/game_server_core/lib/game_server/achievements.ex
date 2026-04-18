defmodule GameServer.Achievements do
  @moduledoc """
  The Achievements context.

  Manages achievement definitions and user progress/unlocks.

  ## Usage

      # Create an achievement (admin)
      {:ok, ach} = Achievements.create_achievement(%{
        slug: "first_lobby",
        title: "Welcome!",
        description: "Join your first lobby",
        progress_target: 1
      })

      # Unlock a one-shot achievement
      {:ok, ua} = Achievements.unlock_achievement(user_id, "first_lobby")

      # Increment progress on a multi-step achievement
      {:ok, ua} = Achievements.increment_progress(user_id, "chat_100", 1)
      # auto-unlocks when progress >= progress_target

      # List achievements (with user progress if user_id provided)
      achievements = Achievements.list_achievements(user_id: user_id, page: 1, page_size: 25)
  """

  import Ecto.Query, warn: false
  require Logger

  use Nebulex.Caching, cache: GameServer.Cache

  alias GameServer.Achievements.Achievement
  alias GameServer.Achievements.UserAchievement
  alias GameServer.Repo

  # ---------------------------------------------------------------------------
  # Cache helpers
  # ---------------------------------------------------------------------------

  @achievements_cache_ttl_ms 60_000

  defp achievements_version do
    GameServer.Cache.get({:achievements, :version}) || 1
  end

  defp invalidate_achievements_cache do
    GameServer.Async.run(fn ->
      _ = GameServer.Cache.incr({:achievements, :version}, 1, default: 1)
      :ok
    end)

    :ok
  end

  # ---------------------------------------------------------------------------
  # PubSub
  # ---------------------------------------------------------------------------

  @pubsub GameServer.PubSub

  @doc "Subscribe to global achievement events (new definitions, updates, unlocks)."
  @spec subscribe_achievements() :: :ok | {:error, term()}
  def subscribe_achievements do
    Phoenix.PubSub.subscribe(@pubsub, "achievements")
  end

  defp broadcast_achievement_unlocked(user_id, user_achievement) do
    Phoenix.PubSub.broadcast(@pubsub, "user:#{user_id}", {
      :achievement_unlocked,
      user_achievement
    })

    Phoenix.PubSub.broadcast(@pubsub, "achievements", {
      :achievement_unlocked,
      user_id,
      user_achievement
    })
  end

  defp broadcast_achievement_change do
    invalidate_achievements_cache()
    Phoenix.PubSub.broadcast(@pubsub, "achievements", {:achievements_changed})
  end

  # ---------------------------------------------------------------------------
  # Achievement CRUD (admin)
  # ---------------------------------------------------------------------------

  @doc "Creates a new achievement definition."
  @spec create_achievement(map()) :: {:ok, Achievement.t()} | {:error, Ecto.Changeset.t()}
  def create_achievement(attrs) do
    attrs = normalize_params(attrs)

    case %Achievement{} |> Achievement.changeset(attrs) |> Repo.insert() do
      {:ok, _achievement} = result ->
        broadcast_achievement_change()
        result

      error ->
        error
    end
  end

  @doc "Updates an achievement definition."
  @spec update_achievement(Achievement.t(), map()) ::
          {:ok, Achievement.t()} | {:error, Ecto.Changeset.t()}
  def update_achievement(%Achievement{} = achievement, attrs) do
    attrs = normalize_params(attrs)

    case achievement |> Achievement.changeset(attrs) |> Repo.update() do
      {:ok, _} = result ->
        broadcast_achievement_change()
        result

      error ->
        error
    end
  end

  @doc "Deletes an achievement and all related user progress."
  @spec delete_achievement(Achievement.t()) ::
          {:ok, Achievement.t()} | {:error, Ecto.Changeset.t()}
  def delete_achievement(%Achievement{} = achievement) do
    case Repo.delete(achievement) do
      {:ok, _} = result ->
        broadcast_achievement_change()
        result

      error ->
        error
    end
  end

  @doc "Get an achievement by ID."
  @spec get_achievement(integer()) :: Achievement.t() | nil
  def get_achievement(id) when is_integer(id), do: Repo.get(Achievement, id)

  @doc "Get an achievement by slug."
  @spec get_achievement_by_slug(String.t()) :: Achievement.t() | nil
  def get_achievement_by_slug(slug) when is_binary(slug) do
    Repo.get_by(Achievement, slug: slug)
  end

  @doc "Returns a changeset for tracking achievement changes (used by forms)."
  @spec change_achievement(Achievement.t()) :: Ecto.Changeset.t()
  @spec change_achievement(Achievement.t(), map()) :: Ecto.Changeset.t()
  def change_achievement(%Achievement{} = achievement, attrs \\ %{}) do
    Achievement.changeset(achievement, attrs)
  end

  # ---------------------------------------------------------------------------
  # Listing achievements
  # ---------------------------------------------------------------------------

  @doc """
  Lists all achievements, optionally with user progress.

  ## Options
  - `:user_id` — if provided, includes user progress/unlock status
  - `:page` — page number (default: 1)
  - `:page_size` — items per page (default: 25)
  - `:include_hidden` — if true, include hidden achievements (default: false)
  """
  @spec list_achievements() :: [map()]
  @spec list_achievements(keyword()) :: [map()]
  def list_achievements(opts \\ []) do
    user_id = Keyword.get(opts, :user_id)
    page = max(Keyword.get(opts, :page, 1), 1)
    page_size = min(max(Keyword.get(opts, :page_size, 25), 1), 200)
    include_hidden = Keyword.get(opts, :include_hidden, false)
    filter = Keyword.get(opts, :filter, "all")

    # When a user-specific filter is active we must JOIN user_achievements in
    # SQL so pagination is correct.  The "all" filter can still use the cached
    # path for the base achievement list.
    achievements =
      cond do
        filter != "all" && user_id != nil ->
          do_list_achievements_user_filtered(user_id, filter, include_hidden, page, page_size)

        include_hidden ->
          do_list_achievements_all(page, page_size)

        true ->
          do_list_achievements_filtered(user_id, page, page_size)
      end

    if user_id do
      achievement_ids = Enum.map(achievements, & &1.id)

      user_progress =
        from(ua in UserAchievement,
          where: ua.user_id == ^user_id and ua.achievement_id in ^achievement_ids
        )
        |> Repo.all()
        |> Map.new(fn ua -> {ua.achievement_id, ua} end)

      Enum.map(achievements, fn a ->
        ua = Map.get(user_progress, a.id)
        %{achievement: a, progress: (ua && ua.progress) || 0, unlocked_at: ua && ua.unlocked_at}
      end)
    else
      Enum.map(achievements, fn a ->
        %{achievement: a, progress: 0, unlocked_at: nil}
      end)
    end
  end

  # Cached: all achievements (include_hidden: true). Key includes page params
  # and the version counter so it's invalidated when achievements change.
  @decorate cacheable(
              key: {:achievements, :list_all, page, page_size, achievements_version()},
              opts: [ttl: @achievements_cache_ttl_ms]
            )
  defp do_list_achievements_all(page, page_size) do
    offset = (page - 1) * page_size

    from(a in Achievement, order_by: [asc: a.sort_order, asc: a.title])
    |> limit(^page_size)
    |> offset(^offset)
    |> Repo.all()
  end

  # Not cached: when include_hidden is false, the query may depend on user_id
  # (LEFT JOIN to show hidden achievements the user has unlocked).
  defp do_list_achievements_filtered(user_id, page, page_size) do
    query = from(a in Achievement, order_by: [asc: a.sort_order, asc: a.title])

    query =
      if user_id do
        from a in query,
          left_join: ua in UserAchievement,
          on: ua.achievement_id == a.id and ua.user_id == ^user_id,
          where: a.hidden == false or not is_nil(ua.unlocked_at)
      else
        from a in query, where: a.hidden == false
      end

    offset = (page - 1) * page_size

    query
    |> limit(^page_size)
    |> offset(^offset)
    |> Repo.all()
  end

  # Not cached: user-specific filtered queries (unlocked/locked/in_progress).
  # These JOIN user_achievements so pagination counts are correct.
  defp do_list_achievements_user_filtered(user_id, filter, include_hidden, page, page_size) do
    offset = (page - 1) * page_size

    base =
      from(a in Achievement,
        left_join: ua in UserAchievement,
        on: ua.achievement_id == a.id and ua.user_id == ^user_id,
        order_by: [asc: a.sort_order, asc: a.title],
        select: a
      )

    base =
      if include_hidden do
        base
      else
        from([a, ua] in base, where: a.hidden == false or not is_nil(ua.unlocked_at))
      end

    query =
      case filter do
        "unlocked" ->
          from [a, ua] in base, where: not is_nil(ua.unlocked_at)

        "locked" ->
          from [a, ua] in base, where: is_nil(ua.unlocked_at)

        "in_progress" ->
          from [a, ua] in base, where: ua.progress > 0 and is_nil(ua.unlocked_at)

        _ ->
          base
      end

    query
    |> limit(^page_size)
    |> offset(^offset)
    |> Repo.all()
  end

  @doc "Count achievements (for pagination). Supports `:include_hidden`, `:filter`, and `:user_id`."
  @spec count_achievements() :: non_neg_integer()
  @spec count_achievements(keyword()) :: non_neg_integer()
  def count_achievements(opts \\ []) do
    include_hidden = Keyword.get(opts, :include_hidden, false)
    filter = Keyword.get(opts, :filter, "all")
    user_id = Keyword.get(opts, :user_id)

    cond do
      filter != "all" && user_id != nil ->
        do_count_achievements_user_filtered(user_id, filter, include_hidden)

      include_hidden ->
        do_count_achievements_all()

      true ->
        do_count_achievements_public()
    end
  end

  @decorate cacheable(
              key: {:achievements, :count_all, achievements_version()},
              opts: [ttl: @achievements_cache_ttl_ms]
            )
  defp do_count_achievements_all do
    Repo.aggregate(Achievement, :count)
  end

  @decorate cacheable(
              key: {:achievements, :count_public, achievements_version()},
              opts: [ttl: @achievements_cache_ttl_ms]
            )
  defp do_count_achievements_public do
    from(a in Achievement, where: a.hidden == false)
    |> Repo.aggregate(:count)
  end

  # Not cached: count with user-specific filter (unlocked/locked/in_progress).
  defp do_count_achievements_user_filtered(user_id, filter, include_hidden) do
    base =
      from(a in Achievement,
        left_join: ua in UserAchievement,
        on: ua.achievement_id == a.id and ua.user_id == ^user_id
      )

    base =
      if include_hidden,
        do: base,
        else: from([a, ua] in base, where: a.hidden == false or not is_nil(ua.unlocked_at))

    query =
      case filter do
        "unlocked" -> from([a, ua] in base, where: not is_nil(ua.unlocked_at))
        "locked" -> from([a, ua] in base, where: is_nil(ua.unlocked_at))
        "in_progress" -> from([a, ua] in base, where: ua.progress > 0 and is_nil(ua.unlocked_at))
        _ -> base
      end

    Repo.aggregate(query, :count)
  end

  @doc "Count all achievements (including hidden), for admin dashboard."
  @spec count_all_achievements() :: non_neg_integer()
  def count_all_achievements do
    Repo.aggregate(Achievement, :count)
  end

  @doc "Count all user achievement unlock records."
  @spec count_all_unlocks() :: non_neg_integer()
  def count_all_unlocks do
    from(ua in UserAchievement, where: not is_nil(ua.unlocked_at))
    |> Repo.aggregate(:count)
  end

  @doc "Count hidden achievements."
  @spec count_hidden_achievements() :: non_neg_integer()
  def count_hidden_achievements do
    from(a in Achievement, where: a.hidden == true)
    |> Repo.aggregate(:count)
  end

  @doc "Count distinct users who have unlocked at least one achievement."
  @spec count_users_with_unlocks() :: non_neg_integer()
  def count_users_with_unlocks do
    from(ua in UserAchievement,
      where: not is_nil(ua.unlocked_at),
      select: count(ua.user_id, :distinct)
    )
    |> Repo.one()
  end

  @doc """
  Returns achievement statistics for the admin dashboard.

  Returns a map with:
  - `hidden` — number of hidden achievements
  - `users_with_unlocks` — users who unlocked at least one
  - `avg_unlocks_per_user` — average unlocks per user (among users who have any)
  - `most_unlocked` — `{slug, title, count}` of the most-unlocked achievement
  - `least_unlocked` — `{slug, title, count}` of the least-unlocked achievement (with at least 1 unlock)
  """
  @spec dashboard_stats() :: map()
  def dashboard_stats do
    hidden = count_hidden_achievements()
    users_with = count_users_with_unlocks()
    total_unlocks = count_all_unlocks()

    avg_unlocks =
      if users_with > 0,
        do: Float.round(total_unlocks / users_with, 1),
        else: 0.0

    most_unlocked = most_unlocked_achievement()
    least_unlocked = least_unlocked_achievement()

    %{
      hidden: hidden,
      users_with_unlocks: users_with,
      avg_unlocks_per_user: avg_unlocks,
      most_unlocked: most_unlocked,
      least_unlocked: least_unlocked
    }
  end

  defp most_unlocked_achievement do
    from(ua in UserAchievement,
      where: not is_nil(ua.unlocked_at),
      join: a in Achievement,
      on: a.id == ua.achievement_id,
      group_by: [a.id, a.slug, a.title],
      order_by: [desc: count(ua.id)],
      limit: 1,
      select: {a.slug, a.title, count(ua.id)}
    )
    |> Repo.one()
  end

  defp least_unlocked_achievement do
    from(ua in UserAchievement,
      where: not is_nil(ua.unlocked_at),
      join: a in Achievement,
      on: a.id == ua.achievement_id,
      group_by: [a.id, a.slug, a.title],
      order_by: [asc: count(ua.id)],
      limit: 1,
      select: {a.slug, a.title, count(ua.id)}
    )
    |> Repo.one()
  end

  @doc "Lists all achievements unlocked by a user."
  @spec list_user_achievements(integer()) :: [UserAchievement.t()]
  @spec list_user_achievements(integer(), keyword()) :: [UserAchievement.t()]
  def list_user_achievements(user_id, opts \\ []) when is_integer(user_id) do
    page = max(Keyword.get(opts, :page, 1), 1)
    page_size = min(max(Keyword.get(opts, :page_size, 25), 1), 200)
    offset = (page - 1) * page_size

    from(ua in UserAchievement,
      where: ua.user_id == ^user_id and not is_nil(ua.unlocked_at),
      join: a in assoc(ua, :achievement),
      preload: [achievement: a],
      order_by: [desc: ua.unlocked_at]
    )
    |> limit(^page_size)
    |> offset(^offset)
    |> Repo.all()
  end

  @doc "Count unlocked achievements for a user."
  @spec count_user_achievements(integer()) :: non_neg_integer()
  def count_user_achievements(user_id) when is_integer(user_id) do
    from(ua in UserAchievement,
      where: ua.user_id == ^user_id and not is_nil(ua.unlocked_at)
    )
    |> Repo.aggregate(:count)
  end

  # ---------------------------------------------------------------------------
  # Unlocking & progress
  # ---------------------------------------------------------------------------

  @doc """
  Unlock an achievement for a user by slug. If it's a progress-based achievement,
  sets progress to the target and marks it as unlocked.

  Returns `{:ok, user_achievement}` or `{:error, reason}`.
  """
  @spec unlock_achievement(integer(), String.t() | integer()) ::
          {:ok, UserAchievement.t()} | {:error, atom()}
  def unlock_achievement(user_id, slug) when is_integer(user_id) and is_binary(slug) do
    case get_achievement_by_slug(slug) do
      nil ->
        {:error, :achievement_not_found}

      achievement ->
        do_unlock(user_id, achievement)
    end
  end

  def unlock_achievement(user_id, achievement_id)
      when is_integer(user_id) and is_integer(achievement_id) do
    case get_achievement(achievement_id) do
      nil ->
        {:error, :achievement_not_found}

      achievement ->
        do_unlock(user_id, achievement)
    end
  end

  defp do_unlock(user_id, achievement) do
    now = DateTime.utc_now(:second)

    case get_user_achievement(user_id, achievement.id) do
      %UserAchievement{unlocked_at: unlocked_at} when unlocked_at != nil ->
        {:error, :already_unlocked}

      %UserAchievement{} = ua ->
        ua
        |> Ecto.Changeset.change(%{
          progress: achievement.progress_target,
          unlocked_at: now
        })
        |> Repo.update()
        |> tap_ok(fn ua -> on_unlock(user_id, ua, achievement) end)

      nil ->
        %UserAchievement{
          user_id: user_id,
          achievement_id: achievement.id,
          progress: achievement.progress_target,
          unlocked_at: now
        }
        |> Repo.insert()
        |> tap_ok(fn ua -> on_unlock(user_id, ua, achievement) end)
    end
  end

  @doc """
  Increment progress on an achievement for a user. Automatically unlocks
  when progress reaches the target.

  Returns `{:ok, user_achievement}`.
  """
  @spec increment_progress(integer(), String.t()) :: {:ok, UserAchievement.t()} | {:error, atom()}
  @spec increment_progress(integer(), String.t(), pos_integer()) ::
          {:ok, UserAchievement.t()} | {:error, atom()}
  def increment_progress(user_id, slug, amount \\ 1)
      when is_integer(user_id) and is_binary(slug) and is_integer(amount) and amount > 0 do
    case get_achievement_by_slug(slug) do
      nil ->
        {:error, :achievement_not_found}

      achievement ->
        do_increment(user_id, achievement, amount)
    end
  end

  defp do_increment(user_id, achievement, amount) do
    # Ensure a user_achievement row exists (upsert with on_conflict: :nothing)
    _ =
      %UserAchievement{
        user_id: user_id,
        achievement_id: achievement.id,
        progress: 0
      }
      |> Repo.insert(on_conflict: :nothing, conflict_target: [:user_id, :achievement_id])

    # Atomic increment to avoid lost updates under concurrency.
    # Only increment if not already unlocked.
    target = achievement.progress_target
    now = DateTime.utc_now(:second)

    {_updated_count, updated_rows} =
      from(ua in UserAchievement,
        where: ua.user_id == ^user_id and ua.achievement_id == ^achievement.id,
        where: is_nil(ua.unlocked_at),
        update: [
          set: [
            progress:
              fragment(
                "CASE WHEN progress + ? > ? THEN ? ELSE progress + ? END",
                ^amount,
                ^target,
                ^target,
                ^amount
              ),
            unlocked_at:
              fragment(
                "CASE WHEN progress + ? >= ? THEN ? ELSE unlocked_at END",
                ^amount,
                ^target,
                ^now
              ),
            updated_at: ^now
          ]
        ],
        select: ua
      )
      |> Repo.update_all([])

    case updated_rows do
      [updated_ua] ->
        if updated_ua.unlocked_at do
          on_unlock(user_id, updated_ua, achievement)
        end

        {:ok, updated_ua}

      [] ->
        # Already unlocked — return current state
        ua = get_user_achievement(user_id, achievement.id)
        {:ok, ua}
    end
  end

  @doc "Get a user's progress on a specific achievement."
  @spec get_user_achievement(integer(), integer()) :: UserAchievement.t() | nil
  def get_user_achievement(user_id, achievement_id)
      when is_integer(user_id) and is_integer(achievement_id) do
    Repo.get_by(UserAchievement, user_id: user_id, achievement_id: achievement_id)
  end

  @doc "Reset a user's progress on a specific achievement (admin use)."
  @spec reset_user_achievement(integer(), integer()) ::
          {:ok, UserAchievement.t() | :not_found} | {:error, Ecto.Changeset.t()}
  def reset_user_achievement(user_id, achievement_id)
      when is_integer(user_id) and is_integer(achievement_id) do
    case get_user_achievement(user_id, achievement_id) do
      nil -> {:ok, :not_found}
      ua -> Repo.delete(ua)
    end
  end

  @doc "Grant achievement to user by slug (admin convenience, calls unlock_achievement)."
  @spec grant_achievement(integer(), String.t()) :: {:ok, UserAchievement.t()} | {:error, atom()}
  def grant_achievement(user_id, slug) when is_integer(user_id) and is_binary(slug) do
    unlock_achievement(user_id, slug)
  end

  @doc """
  Revoke an achievement from a user. Deletes the user_achievement record entirely.
  """
  @spec revoke_achievement(integer(), integer()) :: {:ok, UserAchievement.t()} | {:error, atom()}
  def revoke_achievement(user_id, achievement_id)
      when is_integer(user_id) and is_integer(achievement_id) do
    case get_user_achievement(user_id, achievement_id) do
      nil -> {:error, :not_found}
      ua -> Repo.delete(ua)
    end
  end

  # ---------------------------------------------------------------------------
  # Rarity / stats
  # ---------------------------------------------------------------------------

  @doc "Get unlock percentage for an achievement (0.0 to 100.0)."
  @spec unlock_percentage(integer()) :: float()
  def unlock_percentage(achievement_id) when is_integer(achievement_id) do
    total_users = GameServer.Repo.aggregate(GameServer.Accounts.User, :count)

    if total_users == 0 do
      0.0
    else
      unlocked =
        from(ua in UserAchievement,
          where: ua.achievement_id == ^achievement_id and not is_nil(ua.unlocked_at)
        )
        |> Repo.aggregate(:count)

      Float.round(unlocked / total_users * 100, 1)
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp on_unlock(user_id, user_achievement, achievement) do
    broadcast_achievement_unlocked(user_id, user_achievement)

    # Send notification (sender = recipient for system notifications)
    notification_title =
      if achievement.hidden do
        "Secret achievement unlocked"
      else
        "Achievement unlocked: #{achievement.title}"
      end

    GameServer.Async.run(fn ->
      GameServer.Notifications.admin_create_notification(user_id, user_id, %{
        title: notification_title,
        content: "",
        metadata: %{
          type: "achievement_unlocked",
          achievement_id: achievement.id,
          achievement_slug: achievement.slug
        }
      })
    end)

    # Fire after hook
    GameServer.Async.run(fn ->
      GameServer.Hooks.internal_call(:after_achievement_unlocked, [user_id, achievement])
    end)
  end

  defp tap_ok({:ok, value} = result, fun) do
    fun.(value)
    result
  end

  defp tap_ok(error, _fun), do: error

  defp normalize_params(attrs) when is_map(attrs) do
    Map.new(attrs, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end
end
