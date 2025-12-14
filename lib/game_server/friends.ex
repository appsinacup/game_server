defmodule GameServer.Friends do
  @moduledoc """
  Friends context - handles friend requests and relationships.

  Basic semantics:
  - A single `friendships` row represents a directed request from requester -> target.
  - status: "pending" | "accepted" | "rejected" | "blocked"
  - When a user accepts a pending incoming request, that request becomes `accepted`.
    If a reverse pending request exists, it will be removed to avoid duplicate rows.
  - Listing friends returns the other user from rows with status `accepted` in either
    direction.

  ## Usage

      # Create a friend request (requester -> target)
      {:ok, friendship} = GameServer.Friends.create_request(requester_id, target_id)

      # Accept a pending incoming request (performed by the target)
      {:ok, accepted} = GameServer.Friends.accept_friend_request(friendship.id, %GameServer.Accounts.User{id: target_id})

      # List accepted friends for a user (paginated)
      friends = GameServer.Friends.list_friends_for_user(user_id, page: 1, page_size: 25)

      # Count accepted friends for a user
      count = GameServer.Friends.count_friends_for_user(user_id)

      # Remove a friendship (either direction)
      {:ok, _} = GameServer.Friends.remove_friend(user_id, friend_id)

  """

  import Ecto.Query, warn: false
  use Nebulex.Caching, cache: GameServer.Cache
  alias GameServer.Accounts.User
  alias GameServer.Friends.Friendship
  alias GameServer.Repo
  alias GameServer.Types
  @friends_topic "friends"

  @friends_cache_ttl_ms 30_000

  @type user_id :: integer()

  defp friends_cache_version(user_id) when is_integer(user_id) do
    GameServer.Cache.get({:friends, :version, user_id}) || 1
  end

  defp invalidate_friends_cache(user_id) when is_integer(user_id) do
    _ = GameServer.Cache.incr({:friends, :version, user_id}, 1, default: 1)
    :ok
  end

  defp invalidate_friends_cache_pair(a, b) when is_integer(a) and is_integer(b) do
    _ = invalidate_friends_cache(a)
    _ = invalidate_friends_cache(b)
    :ok
  end

  @decorate cacheable(
              key:
                {:friends, :pair, friends_cache_version(requester_id),
                 friends_cache_version(target_id), requester_id, target_id},
              opts: [ttl: @friends_cache_ttl_ms]
            )
  defp get_by_pair_cached(requester_id, target_id)
       when is_integer(requester_id) and is_integer(target_id) do
    Repo.get_by(Friendship, requester_id: requester_id, target_id: target_id)
  end

  @spec subscribe_user(user_id()) :: :ok
  def subscribe_user(user_id) when is_integer(user_id) do
    Phoenix.PubSub.subscribe(GameServer.PubSub, "friends:user:#{user_id}")
  end

  @spec unsubscribe_user(user_id()) :: :ok
  def unsubscribe_user(user_id) when is_integer(user_id) do
    Phoenix.PubSub.unsubscribe(GameServer.PubSub, "friends:user:#{user_id}")
  end

  defp broadcast_user(user_id, event) when is_integer(user_id) do
    # keep existing PubSub behavior (server-side consumers)
    Phoenix.PubSub.broadcast(GameServer.PubSub, "friends:user:#{user_id}", event)

    # also push a channel-friendly version to the per-user Phoenix channel
    # so clients joined to "user:<id>" receive realtime updates via sockets.
    case event do
      {name, %Friendship{} = f} when is_atom(name) ->
        payload = %{
          id: f.id,
          requester_id: f.requester_id,
          target_id: f.target_id,
          status: f.status
        }

        # broadcast event name as string, payload as simple map
        GameServerWeb.Endpoint.broadcast("user:#{user_id}", Atom.to_string(name), payload)

      _ ->
        :ok
    end
  end

  defp broadcast_all(event) do
    Phoenix.PubSub.broadcast(GameServer.PubSub, @friends_topic, event)
  end

  @doc "Create a friend request from requester -> target.
  If a reverse pending request exists (target -> requester) it will be accepted instead.
  Returns {:ok, friendship} on success or {:error, reason}.
  "
  @spec create_request(User.t() | user_id(), user_id()) ::
          {:ok, Friendship.t()}
          | {:error,
             :cannot_friend_self | :blocked | :already_friends | :already_requested | term()}
  def create_request(%User{id: requester_id}, target_id),
    do: create_request(requester_id, target_id)

  def create_request(requester_id, target_id)
      when is_integer(requester_id) and is_integer(target_id) do
    if requester_id == target_id do
      {:error, :cannot_friend_self}
    else
      # clean up any rejected same-direction rows to allow fresh request creation
      remove_rejected_same_direction(requester_id, target_id)

      cond do
        blocked?(requester_id, target_id) ->
          {:error, :blocked}

        already_friends?(requester_id, target_id) ->
          {:error, :already_friends}

        same_direction_pending?(requester_id, target_id) ->
          {:error, :already_requested}

        pending_reverse = find_pending_reverse(requester_id, target_id) ->
          accept_friend_request(pending_reverse.id, %User{id: requester_id})

        true ->
          create_new_friend_request(requester_id, target_id)
      end
    end
  end

  defp remove_rejected_same_direction(requester_id, target_id) do
    case get_by_pair(requester_id, target_id) do
      %Friendship{status: "rejected"} = f ->
        _ = Repo.delete(f)
        _ = invalidate_friends_cache_pair(requester_id, target_id)
        :ok

      _ ->
        :ok
    end
  end

  defp blocked?(requester_id, target_id) do
    existing_same = get_by_pair(requester_id, target_id)
    existing_reverse = get_by_pair(target_id, requester_id)

    (existing_same && existing_same.status == "blocked") ||
      (existing_reverse && existing_reverse.status == "blocked")
  end

  defp already_friends?(requester_id, target_id) do
    case get_by_pair(requester_id, target_id) do
      %Friendship{status: "accepted"} = f ->
        f

      _ ->
        case get_by_pair(target_id, requester_id) do
          %Friendship{status: "accepted"} = f -> f
          _ -> nil
        end
    end
  end

  defp same_direction_pending?(requester_id, target_id) do
    match?(%Friendship{status: "pending"}, get_by_pair(requester_id, target_id))
  end

  defp find_pending_reverse(requester_id, target_id) do
    case get_by_pair(target_id, requester_id) do
      %Friendship{status: "pending"} = f -> f
      _ -> nil
    end
  end

  defp create_new_friend_request(requester_id, target_id) do
    case %Friendship{}
         |> Friendship.changeset(%{requester_id: requester_id, target_id: target_id})
         |> Repo.insert() do
      {:ok, f} = ok ->
        _ = invalidate_friends_cache_pair(requester_id, target_id)
        broadcast_user(target_id, {:incoming_request, f})
        broadcast_user(requester_id, {:outgoing_request, f})
        broadcast_all({:friend_created, f})
        ok

      err ->
        err
    end
  end

  @doc "Accept a friend request (only the target may accept). Returns {:ok, friendship}."
  @spec accept_friend_request(integer(), User.t()) :: {:ok, Friendship.t()} | {:error, term()}
  def accept_friend_request(friendship_id, %User{id: user_id}) when is_integer(friendship_id) do
    Repo.transaction(fn ->
      with %Friendship{} = f <- Repo.get(Friendship, friendship_id),
           true <- f.target_id == user_id,
           true <- f.status == "pending",
           {:ok, accepted} <- f |> Ecto.Changeset.change(status: "accepted") |> Repo.update() do
        # remove any reverse pending request if present
        Repo.delete_all(
          from ff in Friendship,
            where:
              ff.requester_id == ^f.target_id and ff.target_id == ^f.requester_id and
                ff.status == "pending"
        )

        _ = invalidate_friends_cache_pair(accepted.requester_id, accepted.target_id)

        # broadcast accepted to both users
        broadcast_user(accepted.requester_id, {:friend_accepted, accepted})
        broadcast_user(accepted.target_id, {:friend_accepted, accepted})
        broadcast_all({:friend_accepted, accepted})

        accepted
      else
        nil -> Repo.rollback(:not_found)
        false -> Repo.rollback(:not_authorized)
      end
    end)
  end

  @doc "Reject a friend request (only the target may reject). Returns {:ok, friendship}."
  @spec reject_friend_request(integer(), User.t()) :: {:ok, Friendship.t()} | {:error, term()}
  def reject_friend_request(friendship_id, %User{id: user_id}) when is_integer(friendship_id) do
    with %Friendship{} = f <- Repo.get(Friendship, friendship_id),
         true <- f.target_id == user_id,
         true <- f.status == "pending",
         {:ok, rejected} <- f |> Ecto.Changeset.change(status: "rejected") |> Repo.update() do
      _ = invalidate_friends_cache_pair(rejected.requester_id, rejected.target_id)

      # broadcast rejection
      broadcast_user(rejected.requester_id, {:friend_rejected, rejected})
      broadcast_user(rejected.target_id, {:friend_rejected, rejected})
      broadcast_all({:friend_rejected, rejected})

      {:ok, rejected}
    else
      nil -> {:error, :not_found}
      false -> {:error, :not_authorized}
      err -> err
    end
  end

  @doc "Cancel an outgoing friend request (only the requester may cancel)."
  @spec cancel_request(integer(), User.t()) ::
          {:ok, :cancelled} | {:error, :not_found | :not_authorized | term()}
  def cancel_request(friendship_id, %User{id: user_id}) when is_integer(friendship_id) do
    with %Friendship{} = f <- Repo.get(Friendship, friendship_id),
         true <- f.requester_id == user_id,
         {:ok, _} <- Repo.delete(f) do
      _ = invalidate_friends_cache_pair(f.requester_id, f.target_id)

      # broadcast cancellation
      broadcast_user(f.requester_id, {:request_cancelled, f})
      broadcast_user(f.target_id, {:request_cancelled, f})
      broadcast_all({:request_cancelled, f})

      {:ok, :cancelled}
    else
      nil -> {:error, :not_found}
      false -> {:error, :not_authorized}
      err -> err
    end
  end

  @doc "Remove a friendship (either direction) - only participating users may call this."
  @spec remove_friend(integer(), integer()) :: {:ok, Friendship.t()} | {:error, term()}
  def remove_friend(user_id, friend_id) when is_integer(user_id) and is_integer(friend_id) do
    case Repo.one(
           from f in Friendship,
             where:
               (f.requester_id == ^user_id and f.target_id == ^friend_id) or
                 (f.requester_id == ^friend_id and f.target_id == ^user_id),
             limit: 1
         ) do
      %Friendship{} = f ->
        result = Repo.delete(f)

        case result do
          {:ok, _} ->
            _ = invalidate_friends_cache_pair(user_id, friend_id)

            # broadcast removal
            broadcast_user(user_id, {:friend_removed, f})
            broadcast_user(friend_id, {:friend_removed, f})
            broadcast_all({:friend_removed, f})
            result

          err ->
            err
        end

      nil ->
        {:error, :not_found}
    end
  end

  @doc "Block an incoming request (only the target may block). Returns {:ok, friendship} with status \"blocked\"."
  @spec block_friend_request(integer(), User.t()) :: {:ok, Friendship.t()} | {:error, term()}
  def block_friend_request(friendship_id, %User{id: user_id}) when is_integer(friendship_id) do
    with %Friendship{} = f <- Repo.get(Friendship, friendship_id),
         true <- f.target_id == user_id,
         true <- f.status in ["pending", "rejected"],
         {:ok, blocked} <- f |> Ecto.Changeset.change(status: "blocked") |> Repo.update() do
      _ = invalidate_friends_cache_pair(blocked.requester_id, blocked.target_id)

      # broadcast blocked
      broadcast_user(blocked.requester_id, {:friend_blocked, blocked})
      broadcast_user(blocked.target_id, {:friend_blocked, blocked})
      broadcast_all({:friend_blocked, blocked})

      {:ok, blocked}
    else
      nil -> {:error, :not_found}
      false -> {:error, :not_authorized}
    end
  end

  @doc "List blocked friendships for a user (Friendship structs where the user is the blocker / target)."
  @spec list_blocked_for_user(user_id() | User.t()) :: [Friendship.t()]
  @spec list_blocked_for_user(user_id() | User.t(), Types.pagination_opts()) :: [Friendship.t()]
  def list_blocked_for_user(user_id, opts \\ [])
  def list_blocked_for_user(%User{id: id}, opts), do: list_blocked_for_user(id, opts)

  def list_blocked_for_user(user_id, opts) when is_integer(user_id) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 25)

    list_blocked_for_user_cached(user_id, page, page_size)
  end

  @decorate cacheable(
              key:
                {:friends, :list_blocked, friends_cache_version(user_id), user_id, page,
                 page_size},
              opts: [ttl: @friends_cache_ttl_ms]
            )
  defp list_blocked_for_user_cached(user_id, page, page_size) do
    offset = (page - 1) * page_size

    Repo.all(
      from f in Friendship,
        where: f.target_id == ^user_id and f.status == "blocked",
        preload: [:requester],
        limit: ^page_size,
        offset: ^offset
    )
  end

  @doc "Count blocked friendships for a user (number of blocked rows where user is target)."
  @spec count_blocked_for_user(user_id() | User.t()) :: non_neg_integer()
  def count_blocked_for_user(%User{id: id}), do: count_blocked_for_user(id)

  def count_blocked_for_user(user_id) when is_integer(user_id) do
    count_blocked_for_user_cached(user_id)
  end

  @decorate cacheable(
              key: {:friends, :count_blocked, friends_cache_version(user_id), user_id},
              opts: [ttl: @friends_cache_ttl_ms]
            )
  defp count_blocked_for_user_cached(user_id) do
    Repo.one(
      from f in Friendship,
        where: f.target_id == ^user_id and f.status == "blocked",
        select: count(f.id)
    ) || 0
  end

  @doc "Unblock a previously-blocked friendship (only the user who blocked may unblock). Returns {:ok, :unblocked} on success."
  @spec unblock_friendship(integer(), User.t()) :: {:ok, :unblocked} | {:error, term()}
  def unblock_friendship(friendship_id, %User{id: user_id}) when is_integer(friendship_id) do
    with %Friendship{} = f <- Repo.get(Friendship, friendship_id),
         true <- f.target_id == user_id,
         true <- f.status == "blocked",
         {:ok, _} <- Repo.delete(f) do
      _ = invalidate_friends_cache_pair(f.requester_id, f.target_id)

      # broadcast unblocked so UI/SDK can refresh
      broadcast_user(f.requester_id, {:friend_unblocked, f})
      broadcast_user(f.target_id, {:friend_unblocked, f})
      broadcast_all({:friend_unblocked, f})

      {:ok, :unblocked}
    else
      nil -> {:error, :not_found}
      false -> {:error, :not_authorized}
      err -> err
    end
  end

  @doc """
  List accepted friends for a given user id - returns list of User structs.

  ## Options

  See `t:GameServer.Types.pagination_opts/0` for available options.
  """
  @spec list_friends_for_user(integer() | User.t()) :: [User.t()]
  @spec list_friends_for_user(integer() | User.t(), Types.pagination_opts()) :: [User.t()]
  def list_friends_for_user(user_id, opts \\ [])
  def list_friends_for_user(%User{id: id}, opts), do: list_friends_for_user(id, opts)

  def list_friends_for_user(user_id, opts) when is_integer(user_id) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 25)

    list_friends_for_user_cached(user_id, page, page_size)
  end

  @decorate cacheable(
              key:
                {:friends, :list_friends, friends_cache_version(user_id), user_id, page,
                 page_size},
              opts: [ttl: @friends_cache_ttl_ms]
            )
  defp list_friends_for_user_cached(user_id, page, page_size) do
    offset = (page - 1) * page_size

    q1 =
      from f in Friendship,
        where: f.status == "accepted" and f.requester_id == ^user_id,
        select: %{id: f.target_id}

    q2 =
      from f in Friendship,
        where: f.status == "accepted" and f.target_id == ^user_id,
        select: %{id: f.requester_id}

    union_q = union_all(q1, ^q2)

    # union the two sets and paginate
    ids =
      Repo.all(
        from id_row in subquery(union_q),
          select: id_row.id,
          distinct: true,
          limit: ^page_size,
          offset: ^offset
      )

    Repo.all(from u in User, where: u.id in ^ids)
  end

  @doc "Count accepted friends for a given user (distinct other user ids)."
  @spec count_friends_for_user(user_id() | User.t()) :: non_neg_integer()
  def count_friends_for_user(%User{id: id}), do: count_friends_for_user(id)

  def count_friends_for_user(user_id) when is_integer(user_id) do
    count_friends_for_user_cached(user_id)
  end

  @decorate cacheable(
              key: {:friends, :count_friends, friends_cache_version(user_id), user_id},
              opts: [ttl: @friends_cache_ttl_ms]
            )
  defp count_friends_for_user_cached(user_id) do
    q1 =
      from f in Friendship,
        where: f.status == "accepted" and f.requester_id == ^user_id,
        select: %{id: f.target_id}

    q2 =
      from f in Friendship,
        where: f.status == "accepted" and f.target_id == ^user_id,
        select: %{id: f.requester_id}

    union_q = union_all(q1, ^q2)

    Repo.one(from id_row in subquery(union_q), select: count(id_row.id, :distinct)) || 0
  end

  @doc """
  List incoming pending friend requests for a user (Friendship structs).

  ## Options

  See `t:GameServer.Types.pagination_opts/0` for available options.
  """
  @spec list_incoming_requests(integer() | User.t()) :: [Friendship.t()]
  @spec list_incoming_requests(integer() | User.t(), Types.pagination_opts()) :: [Friendship.t()]
  def list_incoming_requests(user_id, opts \\ [])
  def list_incoming_requests(%User{id: id}, opts), do: list_incoming_requests(id, opts)

  def list_incoming_requests(user_id, opts) when is_integer(user_id) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 25)

    list_incoming_requests_cached(user_id, page, page_size)
  end

  @decorate cacheable(
              key:
                {:friends, :list_incoming, friends_cache_version(user_id), user_id, page,
                 page_size},
              opts: [ttl: @friends_cache_ttl_ms]
            )
  defp list_incoming_requests_cached(user_id, page, page_size) do
    offset = (page - 1) * page_size

    Repo.all(
      from f in Friendship,
        where: f.target_id == ^user_id and f.status == "pending",
        preload: [:requester],
        limit: ^page_size,
        offset: ^offset
    )
  end

  @doc "Count incoming pending friend requests for a user."
  @spec count_incoming_requests(user_id() | User.t()) :: non_neg_integer()
  def count_incoming_requests(%User{id: id}), do: count_incoming_requests(id)

  def count_incoming_requests(user_id) when is_integer(user_id) do
    count_incoming_requests_cached(user_id)
  end

  @decorate cacheable(
              key: {:friends, :count_incoming, friends_cache_version(user_id), user_id},
              opts: [ttl: @friends_cache_ttl_ms]
            )
  defp count_incoming_requests_cached(user_id) do
    Repo.one(
      from f in Friendship,
        where: f.target_id == ^user_id and f.status == "pending",
        select: count(f.id)
    ) || 0
  end

  @doc """
  List outgoing pending friend requests for a user (Friendship structs).

  ## Options

  See `t:GameServer.Types.pagination_opts/0` for available options.
  """
  @spec list_outgoing_requests(integer() | User.t()) :: [Friendship.t()]
  @spec list_outgoing_requests(integer() | User.t(), Types.pagination_opts()) :: [Friendship.t()]
  def list_outgoing_requests(user_id, opts \\ [])
  def list_outgoing_requests(%User{id: id}, opts), do: list_outgoing_requests(id, opts)

  def list_outgoing_requests(user_id, opts) when is_integer(user_id) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 25)

    list_outgoing_requests_cached(user_id, page, page_size)
  end

  @decorate cacheable(
              key:
                {:friends, :list_outgoing, friends_cache_version(user_id), user_id, page,
                 page_size},
              opts: [ttl: @friends_cache_ttl_ms]
            )
  defp list_outgoing_requests_cached(user_id, page, page_size) do
    offset = (page - 1) * page_size

    Repo.all(
      from f in Friendship,
        where: f.requester_id == ^user_id and f.status == "pending",
        preload: [:target],
        limit: ^page_size,
        offset: ^offset
    )
  end

  @doc "Count outgoing pending friend requests for a user."
  @spec count_outgoing_requests(user_id() | User.t()) :: non_neg_integer()
  def count_outgoing_requests(%User{id: id}), do: count_outgoing_requests(id)

  def count_outgoing_requests(user_id) when is_integer(user_id) do
    count_outgoing_requests_cached(user_id)
  end

  @decorate cacheable(
              key: {:friends, :count_outgoing, friends_cache_version(user_id), user_id},
              opts: [ttl: @friends_cache_ttl_ms]
            )
  defp count_outgoing_requests_cached(user_id) do
    Repo.one(
      from f in Friendship,
        where: f.requester_id == ^user_id and f.status == "pending",
        select: count(f.id)
    ) || 0
  end

  @doc "Get friendship by id"
  @spec get_friendship!(integer()) :: Friendship.t()
  def get_friendship!(id), do: Repo.get!(Friendship, id)

  @doc "Get friendship by id (returns nil when not found)"
  @spec get_friendship(integer()) :: Friendship.t() | nil
  def get_friendship(id) when is_integer(id), do: Repo.get(Friendship, id)

  @doc "Get friendship between two users (ordered requester->target) if exists"
  @spec get_by_pair(user_id(), user_id()) :: Friendship.t() | nil
  def get_by_pair(requester_id, target_id) do
    get_by_pair_cached(requester_id, target_id)
  end
end
