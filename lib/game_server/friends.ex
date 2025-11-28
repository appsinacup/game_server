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
  """

  import Ecto.Query, warn: false
  alias GameServer.Accounts.User
  alias GameServer.Friends.Friendship
  alias GameServer.Repo
  @friends_topic "friends"
  def subscribe_user(user_id) when is_integer(user_id) do
    Phoenix.PubSub.subscribe(GameServer.PubSub, "friends:user:#{user_id}")
  end

  def unsubscribe_user(user_id) when is_integer(user_id) do
    Phoenix.PubSub.unsubscribe(GameServer.PubSub, "friends:user:#{user_id}")
  end

  defp broadcast_user(user_id, event) when is_integer(user_id) do
    Phoenix.PubSub.broadcast(GameServer.PubSub, "friends:user:#{user_id}", event)
  end

  defp broadcast_all(event) do
    Phoenix.PubSub.broadcast(GameServer.PubSub, @friends_topic, event)
  end

  @doc "Create a friend request from requester -> target.
  If a reverse pending request exists (target -> requester) it will be accepted instead.
  Returns {:ok, friendship} on success or {:error, reason}.
  "
  @spec create_request(User.t() | integer(), integer()) :: {:ok, Friendship.t()} | {:error, any()}
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
    case Repo.get_by(Friendship, requester_id: requester_id, target_id: target_id) do
      %Friendship{status: "rejected"} = f -> Repo.delete(f)
      _ -> :ok
    end
  end

  defp blocked?(requester_id, target_id) do
    existing_same = Repo.get_by(Friendship, requester_id: requester_id, target_id: target_id)
    existing_reverse = Repo.get_by(Friendship, requester_id: target_id, target_id: requester_id)

    (existing_same && existing_same.status == "blocked") ||
      (existing_reverse && existing_reverse.status == "blocked")
  end

  defp already_friends?(requester_id, target_id) do
    Repo.get_by(Friendship, requester_id: requester_id, target_id: target_id, status: "accepted") ||
      Repo.get_by(Friendship,
        requester_id: target_id,
        target_id: requester_id,
        status: "accepted"
      )
  end

  defp same_direction_pending?(requester_id, target_id) do
    Repo.get_by(Friendship, requester_id: requester_id, target_id: target_id, status: "pending")
  end

  defp find_pending_reverse(requester_id, target_id) do
    Repo.get_by(Friendship, requester_id: target_id, target_id: requester_id, status: "pending")
  end

  defp create_new_friend_request(requester_id, target_id) do
    case %Friendship{}
         |> Friendship.changeset(%{requester_id: requester_id, target_id: target_id})
         |> Repo.insert() do
      {:ok, f} = ok ->
        broadcast_user(target_id, {:incoming_request, f})
        broadcast_user(requester_id, {:outgoing_request, f})
        broadcast_all({:friend_created, f})
        ok

      err ->
        err
    end
  end

  @doc "Accept a friend request (only the target may accept). Returns {:ok, friendship}."
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
  def reject_friend_request(friendship_id, %User{id: user_id}) when is_integer(friendship_id) do
    with %Friendship{} = f <- Repo.get(Friendship, friendship_id),
         true <- f.target_id == user_id,
         true <- f.status == "pending",
         {:ok, rejected} <- f |> Ecto.Changeset.change(status: "rejected") |> Repo.update() do
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
  def cancel_request(friendship_id, %User{id: user_id}) when is_integer(friendship_id) do
    with %Friendship{} = f <- Repo.get(Friendship, friendship_id),
         true <- f.requester_id == user_id,
         {:ok, _} <- Repo.delete(f) do
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
  def block_friend_request(friendship_id, %User{id: user_id}) when is_integer(friendship_id) do
    with %Friendship{} = f <- Repo.get(Friendship, friendship_id),
         true <- f.target_id == user_id,
         true <- f.status in ["pending", "rejected"],
         {:ok, blocked} <- f |> Ecto.Changeset.change(status: "blocked") |> Repo.update() do
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
  def list_blocked_for_user(user_id, opts \\ [])
  def list_blocked_for_user(%User{id: id}, opts), do: list_blocked_for_user(id, opts)

  def list_blocked_for_user(user_id, opts) when is_integer(user_id) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 25)
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
  def count_blocked_for_user(%User{id: id}), do: count_blocked_for_user(id)

  def count_blocked_for_user(user_id) when is_integer(user_id) do
    Repo.one(
      from f in Friendship,
        where: f.target_id == ^user_id and f.status == "blocked",
        select: count(f.id)
    ) || 0
  end

  @doc "Unblock a previously-blocked friendship (only the user who blocked may unblock). Returns {:ok, :unblocked} on success."
  def unblock_friendship(friendship_id, %User{id: user_id}) when is_integer(friendship_id) do
    with %Friendship{} = f <- Repo.get(Friendship, friendship_id),
         true <- f.target_id == user_id,
         true <- f.status == "blocked",
         {:ok, _} <- Repo.delete(f) do
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

  @doc "List accepted friends for a given user id - returns list of User structs."
  def list_friends_for_user(user_id, opts \\ [])
  def list_friends_for_user(%User{id: id}, opts), do: list_friends_for_user(id, opts)

  def list_friends_for_user(user_id, opts) when is_integer(user_id) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 25)
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
  def count_friends_for_user(%User{id: id}), do: count_friends_for_user(id)

  def count_friends_for_user(user_id) when is_integer(user_id) do
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

  @doc "List incoming pending friend requests for a user (Friendship structs)."
  def list_incoming_requests(user_id, opts \\ [])
  def list_incoming_requests(%User{id: id}, opts), do: list_incoming_requests(id, opts)

  def list_incoming_requests(user_id, opts) when is_integer(user_id) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 25)
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
  def count_incoming_requests(%User{id: id}), do: count_incoming_requests(id)

  def count_incoming_requests(user_id) when is_integer(user_id) do
    Repo.one(
      from f in Friendship,
        where: f.target_id == ^user_id and f.status == "pending",
        select: count(f.id)
    ) || 0
  end

  @doc "List outgoing pending friend requests for a user (Friendship structs)."
  def list_outgoing_requests(user_id, opts \\ [])
  def list_outgoing_requests(%User{id: id}, opts), do: list_outgoing_requests(id, opts)

  def list_outgoing_requests(user_id, opts) when is_integer(user_id) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 25)
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
  def count_outgoing_requests(%User{id: id}), do: count_outgoing_requests(id)

  def count_outgoing_requests(user_id) when is_integer(user_id) do
    Repo.one(
      from f in Friendship,
        where: f.requester_id == ^user_id and f.status == "pending",
        select: count(f.id)
    ) || 0
  end

  @doc "Get friendship by id"
  def get_friendship!(id), do: Repo.get!(Friendship, id)

  @doc "Get friendship between two users (ordered requester->target) if exists"
  def get_by_pair(requester_id, target_id) do
    Repo.get_by(Friendship, requester_id: requester_id, target_id: target_id)
  end
end
