defmodule GameServer.Parties do
  @moduledoc """
  Context module for party management.

  A party is a pre-lobby grouping mechanism. Players form a party before
  creating or joining a lobby together.

  ## Usage

      # Create a party (user becomes leader and first member)
      {:ok, party} = GameServer.Parties.create_party(user, %{max_size: 4})

      # Leader invites a friend or shared-group member by user_id
      {:ok, _notification} = GameServer.Parties.invite_to_party(leader, target_user_id)

      # Target accepts the invite
      {:ok, party} = GameServer.Parties.accept_party_invite(target, party_id)

      # Or declines
      :ok = GameServer.Parties.decline_party_invite(target, party_id)

      # Leave a party (if leader leaves, party is disbanded)
      {:ok, _} = GameServer.Parties.leave_party(user)

      # Party leader creates a lobby — all members join atomically
      {:ok, lobby} = GameServer.Parties.create_lobby_with_party(user, lobby_attrs)

      # Party leader joins an existing lobby — all members join atomically
      {:ok, lobby} = GameServer.Parties.join_lobby_with_party(user, lobby_id, opts)

  ## PubSub Events

  This module broadcasts the following events:

  - `"party:<party_id>"` topic:
    - `{:party_member_joined, party_id, user_id}`
    - `{:party_member_left, party_id, user_id}`
    - `{:party_disbanded, party_id}`
    - `{:party_updated, party}`
  """

  import Ecto.Query, warn: false
  use Nebulex.Caching, cache: GameServer.Cache

  require Logger

  alias Ecto.Multi
  alias GameServer.Accounts
  alias GameServer.Accounts.User
  alias GameServer.Friends
  alias GameServer.Groups
  alias GameServer.Lobbies
  alias GameServer.Parties.Party
  alias GameServer.Parties.PartyInvite
  alias GameServer.Repo
  alias GameServer.Repo.AdvisoryLock

  # ---------------------------------------------------------------------------
  # PubSub
  # ---------------------------------------------------------------------------

  @doc "Subscribe to events for a specific party."
  @spec subscribe_party(integer()) :: :ok | {:error, term()}
  def subscribe_party(party_id) do
    Phoenix.PubSub.subscribe(GameServer.PubSub, "party:#{party_id}")
  end

  @doc "Unsubscribe from a party's events."
  @spec unsubscribe_party(integer()) :: :ok
  def unsubscribe_party(party_id) do
    Phoenix.PubSub.unsubscribe(GameServer.PubSub, "party:#{party_id}")
  end

  defp broadcast_party(party_id, event) do
    Phoenix.PubSub.broadcast(GameServer.PubSub, "party:#{party_id}", event)
  end

  # ---------------------------------------------------------------------------
  # Cache helpers
  # ---------------------------------------------------------------------------

  @party_invite_cache_ttl_ms 60_000

  defp party_invite_cache_version(user_id) when is_integer(user_id) do
    GameServer.Cache.get({:party_invites, :version, user_id}) || 1
  end

  defp invalidate_party_invite_cache(user_id) when is_integer(user_id) do
    GameServer.Async.run(fn ->
      _ = GameServer.Cache.incr({:party_invites, :version, user_id}, 1, default: 1)
      :ok
    end)

    :ok
  end

  # ---------------------------------------------------------------------------
  # Queries
  # ---------------------------------------------------------------------------

  @doc "Get a party by ID. Returns nil if not found."
  @spec get_party(integer()) :: Party.t() | nil
  def get_party(id) when is_integer(id), do: Repo.get(Party, id)

  @doc "Get a party by ID. Raises if not found."
  @spec get_party!(integer()) :: Party.t()
  def get_party!(id) when is_integer(id), do: Repo.get!(Party, id)

  @doc "Get all members of a party."
  @spec get_party_members(Party.t() | integer()) :: [User.t()]
  def get_party_members(%Party{id: party_id}), do: get_party_members(party_id)

  def get_party_members(party_id) when is_integer(party_id) do
    Repo.all(
      from u in User,
        where: u.party_id == ^party_id,
        order_by: [asc: u.inserted_at]
    )
  end

  @doc "Count members in a party."
  @spec count_party_members(integer()) :: non_neg_integer()
  def count_party_members(party_id) when is_integer(party_id) do
    Repo.one(from u in User, where: u.party_id == ^party_id, select: count(u.id)) || 0
  end

  @doc "Count total members across all parties."
  @spec count_all_party_members() :: non_neg_integer()
  def count_all_party_members do
    Repo.one(from u in User, where: not is_nil(u.party_id), select: count(u.id)) || 0
  end

  @doc "Get the party the user is currently in, or nil."
  @spec get_user_party(User.t()) :: Party.t() | nil
  def get_user_party(%User{party_id: nil}), do: nil

  def get_user_party(%User{party_id: party_id}) when is_integer(party_id) do
    get_party(party_id)
  end

  # ---------------------------------------------------------------------------
  # Create
  # ---------------------------------------------------------------------------

  @doc """
  Create a new party. The user becomes the leader and first member.

  Returns `{:error, :already_in_party}` if the user is already in a party.
  """
  @spec create_party(User.t(), map()) :: {:ok, Party.t()} | {:error, term()}
  def create_party(%User{} = user, attrs \\ %{}) do
    # Reload latest state
    user = Accounts.get_user(user.id)

    if user.party_id != nil do
      {:error, :already_in_party}
    else
      attrs =
        attrs
        |> normalize_params()
        |> Map.put("leader_id", user.id)

      Multi.new()
      |> Multi.insert(:party, Party.changeset(%Party{}, attrs))
      |> Multi.run(:membership, fn repo, %{party: party} ->
        user
        |> Ecto.Changeset.change(%{party_id: party.id})
        |> repo.update()
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{party: party, membership: _user}} ->
          invalidate_user_cache(user.id)
          broadcast_parties({:party_created, party.id})
          {:ok, party}

        {:error, :party, changeset, _} ->
          {:error, changeset}

        {:error, _op, reason, _} ->
          {:error, reason}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Invitations
  # ---------------------------------------------------------------------------

  @doc """
  Invite a user to join the party. Only the party leader may invite.

  The target user must be a friend of the leader, or share at least one group
  with the leader. A `PartyInvite` record is created and an informational
  notification is sent. The invite is independent of the notification —
  deleting notifications does not affect pending invites.

  Returns `{:error, :not_in_party}` if the caller is not in a party.
  Returns `{:error, :not_leader}` if the caller is not the party leader.
  Returns `{:error, :not_connected}` if the target is not a friend or shared group member.
  Returns `{:error, :already_in_party}` if the target is already in a party.
  Returns `{:error, :already_invited}` if a pending invite already exists.
  """
  @spec invite_to_party(User.t(), integer()) :: {:ok, PartyInvite.t()} | {:error, atom()}
  def invite_to_party(%User{} = leader, target_user_id) when is_integer(target_user_id) do
    leader = Accounts.get_user(leader.id)

    with :ok <- check_in_party(leader),
         {:ok, party} <- fetch_party(leader.party_id),
         :ok <- check_is_leader(party, leader),
         {:ok, target} <- fetch_invite_target(target_user_id),
         :ok <- check_not_already_in_party(target),
         :ok <- check_leader_connected_to_target(leader.id, target_user_id),
         :ok <- check_no_pending_invite(leader.id, target_user_id),
         :ok <- check_max_pending_invites(target_user_id) do
      case %PartyInvite{}
           |> PartyInvite.changeset(%{
             party_id: party.id,
             sender_id: leader.id,
             recipient_id: target_user_id
           })
           |> Repo.insert() do
        {:ok, invite} ->
          # Send an informational notification (independent of the invite record)
          GameServer.Notifications.admin_create_notification(leader.id, target_user_id, %{
            "title" => "party_invite",
            "content" => "You have been invited to join a party",
            "metadata" => %{
              "party_id" => party.id,
              "sender_name" => leader.display_name || "",
              "recipient_name" => target.display_name || ""
            }
          })

          invalidate_party_invite_cache(leader.id)
          invalidate_party_invite_cache(target_user_id)

          {:ok, invite}

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Cancel a previously sent party invite. Only the original sender (leader) can cancel.
  """
  @spec cancel_party_invite(User.t(), integer()) :: :ok | {:error, atom()}
  def cancel_party_invite(%User{} = leader, target_user_id) when is_integer(target_user_id) do
    leader = Accounts.get_user(leader.id)

    with :ok <- check_in_party(leader),
         {:ok, party} <- fetch_party(leader.party_id),
         :ok <- check_is_leader(party, leader) do
      from(i in PartyInvite,
        where:
          i.sender_id == ^leader.id and i.recipient_id == ^target_user_id and
            i.status == "pending"
      )
      |> Repo.delete_all()

      invalidate_party_invite_cache(leader.id)
      invalidate_party_invite_cache(target_user_id)

      :ok
    end
  end

  @doc """
  Accept a party invite. Joins the party and marks the invite as accepted.

  Returns `{:error, :no_invite}` if no pending invite exists for that party.
  Returns `{:error, :already_in_party}` if the user is already in another party.
  """
  @spec accept_party_invite(User.t(), integer()) :: {:ok, Party.t()} | {:error, atom()}
  def accept_party_invite(%User{} = user, party_id) when is_integer(party_id) do
    user = Accounts.get_user(user.id)

    invite =
      Repo.one(
        from i in PartyInvite,
          where:
            i.recipient_id == ^user.id and i.party_id == ^party_id and
              i.status == "pending",
          limit: 1
      )

    if is_nil(invite) do
      {:error, :no_invite}
    else
      with :ok <- check_user_not_in_party(user),
           {:ok, party} <- fetch_party(party_id),
           {:ok, _updated_user} <- do_join_party(user, party_id) do
        # Mark all pending invites for this user + party as accepted
        from(i in PartyInvite,
          where:
            i.recipient_id == ^user.id and i.party_id == ^party_id and
              i.status == "pending"
        )
        |> Repo.update_all(set: [status: "accepted", updated_at: DateTime.utc_now()])

        invalidate_party_invite_cache(user.id)
        invalidate_party_invite_cache(invite.sender_id)

        {:ok, party}
      end
    end
  end

  @doc """
  Decline a party invite. Marks the invite as declined.
  """
  @spec decline_party_invite(User.t(), integer()) :: :ok | {:error, atom()}
  def decline_party_invite(%User{} = user, party_id) when is_integer(party_id) do
    user = Accounts.get_user(user.id)

    # Fetch sender_ids before updating so we can invalidate their caches
    sender_ids =
      from(i in PartyInvite,
        where:
          i.recipient_id == ^user.id and i.party_id == ^party_id and
            i.status == "pending",
        select: i.sender_id
      )
      |> Repo.all()

    from(i in PartyInvite,
      where:
        i.recipient_id == ^user.id and i.party_id == ^party_id and
          i.status == "pending"
    )
    |> Repo.update_all(set: [status: "declined", updated_at: DateTime.utc_now()])

    invalidate_party_invite_cache(user.id)
    Enum.each(sender_ids, &invalidate_party_invite_cache/1)

    :ok
  end

  @doc """
  List pending party invites for the given user.
  """
  @spec list_party_invitations(User.t()) :: [map()]
  def list_party_invitations(%User{} = user) do
    do_list_party_invitations(user.id)
  end

  @decorate cacheable(
              key: {:party_invites, :list, party_invite_cache_version(user_id), user_id},
              opts: [ttl: @party_invite_cache_ttl_ms]
            )
  defp do_list_party_invitations(user_id) do
    from(i in PartyInvite,
      where: i.recipient_id == ^user_id and i.status == "pending",
      join: s in assoc(i, :sender),
      join: r in assoc(i, :recipient),
      order_by: [desc: i.inserted_at],
      preload: [sender: s, recipient: r]
    )
    |> Repo.all()
    |> Enum.map(&serialize_party_invite/1)
  end

  @doc """
  List pending party invites sent by the given leader.

  Returns invitations the leader has sent that have not yet been accepted or declined.
  """
  @spec list_sent_party_invitations(User.t()) :: [map()]
  def list_sent_party_invitations(%User{} = leader) do
    do_list_sent_party_invitations(leader.id)
  end

  @decorate cacheable(
              key: {:party_invites, :list_sent, party_invite_cache_version(leader_id), leader_id},
              opts: [ttl: @party_invite_cache_ttl_ms]
            )
  defp do_list_sent_party_invitations(leader_id) do
    from(i in PartyInvite,
      where: i.sender_id == ^leader_id and i.status == "pending",
      join: s in assoc(i, :sender),
      join: r in assoc(i, :recipient),
      order_by: [desc: i.inserted_at],
      preload: [sender: s, recipient: r]
    )
    |> Repo.all()
    |> Enum.map(&serialize_party_invite/1)
  end

  defp serialize_party_invite(invite) do
    %{
      id: invite.id,
      party_id: invite.party_id,
      sender_id: invite.sender_id,
      sender_name: invite.sender.display_name || "",
      recipient_id: invite.recipient_id,
      recipient_name: invite.recipient.display_name || "",
      status: invite.status,
      inserted_at: invite.inserted_at
    }
  end

  defp fetch_invite_target(target_user_id) do
    case Accounts.get_user(target_user_id) do
      nil -> {:error, :user_not_found}
      user -> {:ok, user}
    end
  end

  defp check_not_already_in_party(%User{party_id: nil}), do: :ok
  defp check_not_already_in_party(%User{}), do: {:error, :already_in_party}

  defp check_leader_connected_to_target(leader_id, target_user_id) do
    if Friends.friends?(leader_id, target_user_id) ||
         Groups.shared_group_member?(leader_id, target_user_id) do
      :ok
    else
      {:error, :not_connected}
    end
  end

  defp check_no_pending_invite(leader_id, target_user_id) do
    exists =
      Repo.exists?(
        from i in PartyInvite,
          where:
            i.sender_id == ^leader_id and i.recipient_id == ^target_user_id and
              i.status == "pending"
      )

    if exists, do: {:error, :already_invited}, else: :ok
  end

  defp check_max_pending_invites(target_user_id) do
    max = GameServer.Limits.get(:max_party_pending_invites)

    count =
      Repo.one(
        from(i in PartyInvite,
          where: i.recipient_id == ^target_user_id and i.status == "pending",
          select: count(i.id)
        )
      ) || 0

    if count >= max, do: {:error, :too_many_pending_invites}, else: :ok
  end

  # ---------------------------------------------------------------------------
  # Join (internal — used by accept_party_invite)
  # ---------------------------------------------------------------------------

  defp check_user_not_in_party(%User{party_id: nil}), do: :ok
  defp check_user_not_in_party(%User{}), do: {:error, :already_in_party}

  defp fetch_party(party_id) do
    case get_party(party_id) do
      nil -> {:error, :party_not_found}
      %Party{} = party -> {:ok, party}
    end
  end

  defp do_join_party(user, party_id) do
    # Wrap in a transaction with advisory lock to prevent TOCTOU race
    # conditions on PostgreSQL (two concurrent joins both passing the
    # count check before either updates).
    Repo.transaction(fn ->
      AdvisoryLock.lock(:party, party_id)

      # Re-check space inside the lock
      count = count_party_members(party_id)
      party = get_party(party_id)

      if party && count >= party.max_size do
        Repo.rollback(:party_full)
      else
        case user
             |> Ecto.Changeset.change(%{party_id: party_id})
             |> Repo.update() do
          {:ok, updated_user} ->
            invalidate_user_cache(updated_user.id)
            _ = Accounts.broadcast_user_update(updated_user)
            broadcast_party(party_id, {:party_member_joined, party_id, updated_user.id})
            updated_user

          {:error, reason} ->
            Repo.rollback(reason)
        end
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Leave
  # ---------------------------------------------------------------------------

  @doc """
  Leave the current party.

  If the user is the party leader, the party is disbanded (all members removed,
  party deleted). Regular members are simply removed.
  """
  @spec leave_party(User.t()) :: {:ok, :left | :disbanded} | {:error, term()}
  def leave_party(%User{} = user) do
    user = Accounts.get_user(user.id)

    if is_nil(user.party_id) do
      {:error, :not_in_party}
    else
      party = get_party(user.party_id)

      if is_nil(party) do
        # Stale reference, just clear it
        clear_party_id(user)
        {:ok, :left}
      else
        if party.leader_id == user.id do
          disband_party(party)
        else
          remove_member(user, party.id)
        end
      end
    end
  end

  @doc """
  Kick a member from the party. Only the leader can kick.
  """
  @spec kick_member(User.t(), integer()) :: {:ok, User.t()} | {:error, term()}
  def kick_member(%User{} = leader, target_user_id) when is_integer(target_user_id) do
    leader = Accounts.get_user(leader.id)

    with :ok <- check_in_party(leader),
         {:ok, party} <- fetch_party(leader.party_id),
         :ok <- check_is_leader(party, leader),
         :ok <- check_not_self_kick(leader, target_user_id),
         {:ok, target} <- fetch_kick_target(target_user_id, party) do
      do_kick_member(target, party)
    end
  end

  defp check_in_party(%User{party_id: nil}), do: {:error, :not_in_party}
  defp check_in_party(%User{}), do: :ok

  defp check_is_leader(%Party{leader_id: leader_id}, %User{id: user_id})
       when leader_id != user_id,
       do: {:error, :not_leader}

  defp check_is_leader(%Party{}, %User{}), do: :ok

  defp check_no_members_in_lobby(members) do
    if Enum.any?(members, fn m -> m.lobby_id != nil end) do
      {:error, :member_in_lobby}
    else
      :ok
    end
  end

  defp check_not_self_kick(%User{id: id}, id), do: {:error, :cannot_kick_self}
  defp check_not_self_kick(%User{}, _target_id), do: :ok

  defp fetch_kick_target(target_user_id, party) do
    case Accounts.get_user(target_user_id) do
      nil -> {:error, :user_not_found}
      %User{party_id: party_id} when party_id != party.id -> {:error, :not_in_party}
      %User{} = target -> {:ok, target}
    end
  end

  defp do_kick_member(target, party) do
    result =
      target
      |> Ecto.Changeset.change(%{party_id: nil})
      |> Repo.update()

    case result do
      {:ok, updated} ->
        invalidate_user_cache(updated.id)
        _ = Accounts.broadcast_user_update(updated)
        broadcast_party(party.id, {:party_member_left, party.id, updated.id})
        {:ok, updated}

      error ->
        error
    end
  end

  # ---------------------------------------------------------------------------
  # Update party
  # ---------------------------------------------------------------------------

  @doc """
  Update party settings. Only the leader can update.
  """
  @spec update_party(User.t(), map()) :: {:ok, Party.t()} | {:error, term()}
  def update_party(%User{} = user, attrs) do
    user = Accounts.get_user(user.id)

    with :ok <- check_in_party(user),
         {:ok, party} <- fetch_party(user.party_id),
         :ok <- check_is_leader(party, user) do
      attrs = normalize_params(attrs)
      validate_and_update_party(party, attrs)
    end
  end

  defp validate_and_update_party(party, attrs) do
    new_max = Map.get(attrs, "max_size")

    if new_max do
      count = count_party_members(party.id)
      new_max_int = if is_binary(new_max), do: String.to_integer(new_max), else: new_max

      if new_max_int < count do
        {:error, :too_small}
      else
        do_update_party(party, attrs)
      end
    else
      do_update_party(party, attrs)
    end
  end

  defp do_update_party(party, attrs) do
    result =
      party
      |> Party.changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated} ->
        broadcast_party(updated.id, {:party_updated, updated})
        {:ok, updated}

      error ->
        error
    end
  end

  # ---------------------------------------------------------------------------
  # Lobby integration: create lobby with party
  # ---------------------------------------------------------------------------

  @doc """
  The party leader creates a new lobby, and all party members join it
  atomically. The party is kept intact.

  The lobby's `max_users` must be >= party member count.
  """
  @spec create_lobby_with_party(User.t(), map()) :: {:ok, map()} | {:error, term()}
  def create_lobby_with_party(%User{} = user, lobby_attrs \\ %{}) do
    user = Accounts.get_user(user.id)

    with :ok <- check_in_party(user),
         {:ok, party} <- fetch_party(user.party_id),
         :ok <- check_is_leader(party, user) do
      members = get_party_members(party.id)
      lobby_attrs = normalize_params(lobby_attrs)

      with :ok <- check_no_members_in_lobby(members),
           :ok <- check_lobby_fits_party(lobby_attrs, length(members)) do
        do_create_lobby_with_party(user, party, members, lobby_attrs)
      end
    end
  end

  defp check_lobby_fits_party(lobby_attrs, member_count) do
    lobby_max =
      case Map.get(lobby_attrs, "max_users") do
        nil -> 8
        v when is_binary(v) -> String.to_integer(v)
        v when is_integer(v) -> v
      end

    if lobby_max < member_count, do: {:error, :lobby_too_small_for_party}, else: :ok
  end

  defp do_create_lobby_with_party(user, _party, members, lobby_attrs) do
    lobby_attrs = Map.put(lobby_attrs, "host_id", user.id)

    case Lobbies.create_lobby(lobby_attrs) do
      {:ok, lobby} ->
        finalize_party_lobby_creation(user, members, lobby)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp finalize_party_lobby_creation(user, members, lobby) do
    non_leader_members = Enum.reject(members, &(&1.id == user.id))

    # Use a transaction with advisory lock so either ALL members join or NONE do
    Repo.transaction(fn ->
      AdvisoryLock.lock(:lobby, lobby.id)

      Enum.each(non_leader_members, fn member ->
        member = Accounts.get_user(member.id)

        case Ecto.Changeset.change(member, %{lobby_id: lobby.id}) |> Repo.update() do
          {:ok, updated} ->
            invalidate_user_cache(updated.id)
            updated

          {:error, reason} ->
            Repo.rollback({:member_join_failed, member.id, reason})
        end
      end)
    end)
    |> case do
      {:ok, _} ->
        # Broadcast events only after successful commit
        Enum.each(non_leader_members, fn member ->
          _ = Accounts.broadcast_user_update(Accounts.get_user(member.id))
        end)

        _ = Accounts.broadcast_user_update(Accounts.get_user(user.id))
        {:ok, lobby}

      {:error, reason} ->
        Logger.warning("Party lobby creation rolled back: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Lobby integration: join lobby with party
  # ---------------------------------------------------------------------------

  @doc """
  The party leader joins an existing lobby, and all party members join it
  atomically. The party is kept intact.

  The lobby must have enough free slots for the entire party.
  """
  @spec join_lobby_with_party(User.t(), integer(), map()) :: {:ok, map()} | {:error, term()}
  def join_lobby_with_party(%User{} = user, lobby_id, opts \\ %{}) when is_integer(lobby_id) do
    user = Accounts.get_user(user.id)

    with :ok <- check_in_party(user),
         {:ok, party} <- fetch_party(user.party_id),
         :ok <- check_is_leader(party, user),
         {:ok, lobby} <- fetch_joinable_lobby(lobby_id) do
      members = get_party_members(party.id)

      with :ok <- check_no_members_in_lobby(members) do
        password = Map.get(opts, :password) || Map.get(opts, "password")

        case validate_lobby_password(lobby, password) do
          :ok -> join_all_members_to_lobby(members, lobby, party)
          {:error, _} = err -> err
        end
      end
    end
  end

  defp fetch_joinable_lobby(lobby_id) do
    case Lobbies.get_lobby(lobby_id) do
      nil -> {:error, :invalid_lobby}
      %{is_locked: true} -> {:error, :locked}
      lobby -> {:ok, lobby}
    end
  end

  defp validate_lobby_password(lobby, password) do
    case {lobby.password_hash, password} do
      {nil, _} ->
        :ok

      {_hash, nil} ->
        {:error, :password_required}

      {hash, pwd} ->
        if Bcrypt.verify_pass(pwd, hash), do: :ok, else: {:error, :invalid_password}
    end
  end

  defp join_all_members_to_lobby(members, lobby, _party) do
    # Use a transaction with advisory lock so the space check + member joins
    # are atomic. This prevents TOCTOU race conditions on PostgreSQL.
    Repo.transaction(fn ->
      AdvisoryLock.lock(:lobby, lobby.id)

      # Re-check space inside the lock
      current_lobby_count =
        Repo.one(
          from(u in User,
            where: u.lobby_id == ^lobby.id,
            select: count(u.id)
          )
        ) || 0

      available = lobby.max_users - current_lobby_count

      if available < length(members) do
        Repo.rollback(:not_enough_space)
      end

      Enum.each(members, fn member ->
        member = Accounts.get_user(member.id)

        case member
             |> Ecto.Changeset.change(%{lobby_id: lobby.id})
             |> Repo.update() do
          {:ok, updated} ->
            invalidate_user_cache(updated.id)
            updated

          {:error, reason} ->
            Repo.rollback({:member_join_failed, member.id, reason})
        end
      end)
    end)
    |> case do
      {:ok, _} ->
        # Broadcast events only after successful commit
        Enum.each(members, fn member ->
          updated = Accounts.get_user(member.id)
          _ = Accounts.broadcast_user_update(updated)

          Phoenix.PubSub.broadcast(
            GameServer.PubSub,
            "lobby:#{lobby.id}",
            {:user_joined, lobby.id, member.id}
          )
        end)

        {:ok, lobby}

      {:error, reason} ->
        Logger.warning("Party lobby join rolled back: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Internal helpers
  # ---------------------------------------------------------------------------

  defp disband_party(%Party{} = party) do
    # Remove party_id from all members
    members = get_party_members(party.id)

    Enum.each(members, fn member ->
      member
      |> Ecto.Changeset.change(%{party_id: nil})
      |> Repo.update()
      |> case do
        {:ok, updated} ->
          invalidate_user_cache(updated.id)
          _ = Accounts.broadcast_user_update(updated)

        _ ->
          :ok
      end
    end)

    # Delete the party
    Repo.delete(party)
    broadcast_party(party.id, {:party_disbanded, party.id})
    broadcast_parties({:party_deleted, party.id})

    {:ok, :disbanded}
  end

  defp remove_member(%User{} = user, party_id) do
    result =
      user
      |> Ecto.Changeset.change(%{party_id: nil})
      |> Repo.update()

    case result do
      {:ok, updated} ->
        invalidate_user_cache(updated.id)
        _ = Accounts.broadcast_user_update(updated)
        broadcast_party(party_id, {:party_member_left, party_id, updated.id})
        {:ok, :left}

      error ->
        error
    end
  end

  defp clear_party_id(%User{} = user) do
    user
    |> Ecto.Changeset.change(%{party_id: nil})
    |> Repo.update()
    |> case do
      {:ok, updated} ->
        invalidate_user_cache(updated.id)
        _ = Accounts.broadcast_user_update(updated)
        {:ok, updated}

      error ->
        error
    end
  end

  defp invalidate_user_cache(user_id) when is_integer(user_id) do
    GameServer.Async.run(fn ->
      _ = GameServer.Cache.delete({:accounts, :user, user_id})
      :ok
    end)

    :ok
  end

  defp normalize_params(attrs) when is_map(attrs) do
    Map.new(attrs, fn {k, v} ->
      if is_atom(k), do: {Atom.to_string(k), v}, else: {k, v}
    end)
  end

  defp normalize_params(other), do: other

  # ---------------------------------------------------------------------------
  # Admin helpers
  # ---------------------------------------------------------------------------

  @doc "Subscribe to all party events (create/delete)."
  @spec subscribe_parties() :: :ok | {:error, term()}
  def subscribe_parties do
    Phoenix.PubSub.subscribe(GameServer.PubSub, "parties")
  end

  defp broadcast_parties(event) do
    Phoenix.PubSub.broadcast(GameServer.PubSub, "parties", event)
  end

  @doc "List all parties with optional filters and pagination."
  @spec list_all_parties(map(), keyword()) :: [Party.t()]
  def list_all_parties(filters \\ %{}, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    page_size = Keyword.get(opts, :page_size, 25)
    sort_by = Keyword.get(opts, :sort_by, "updated_at")
    offset = (page - 1) * page_size

    from(p in Party)
    |> apply_party_filters(filters)
    |> apply_party_sort(sort_by)
    |> limit(^page_size)
    |> offset(^offset)
    |> Repo.all()
    |> Repo.preload(:leader)
  end

  @doc "Count all parties matching the given filters."
  @spec count_all_parties(map()) :: non_neg_integer()
  def count_all_parties(filters \\ %{}) do
    from(p in Party, select: count(p.id))
    |> apply_party_filters(filters)
    |> Repo.one() || 0
  end

  @doc "Return a changeset for the given party (for edit forms)."
  @spec change_party(Party.t()) :: Ecto.Changeset.t()
  def change_party(%Party{} = party) do
    Party.changeset(party, %{})
  end

  @doc "Admin update of a party (max_size, metadata)."
  @spec admin_update_party(Party.t(), map()) :: {:ok, Party.t()} | {:error, Ecto.Changeset.t()}
  def admin_update_party(%Party{} = party, attrs) do
    result =
      party
      |> Party.changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated} ->
        broadcast_party(updated.id, {:party_updated, updated.id})
        broadcast_parties({:party_updated, updated.id})
        result

      _ ->
        result
    end
  end

  @doc "Admin delete of a party. Clears all members' party_id and deletes the party."
  @spec admin_delete_party(integer()) :: {:ok, Party.t()} | {:error, term()}
  def admin_delete_party(party_id) when is_integer(party_id) do
    case get_party(party_id) do
      nil ->
        {:error, :not_found}

      party ->
        # Clear all members' party_id
        from(u in User, where: u.party_id == ^party_id)
        |> Repo.update_all(set: [party_id: nil])

        case Repo.delete(party) do
          {:ok, deleted} ->
            broadcast_party(party_id, {:party_disbanded, party_id})
            broadcast_parties({:party_deleted, party_id})
            {:ok, deleted}

          error ->
            error
        end
    end
  end

  defp apply_party_filters(query, filters) when is_map(filters) do
    query
    |> maybe_filter_leader_id(filters)
    |> maybe_filter_min_size(filters)
    |> maybe_filter_max_size(filters)
  end

  defp maybe_filter_leader_id(query, %{"leader_id" => id}) when id not in ["", nil] do
    case Integer.parse(to_string(id)) do
      {lid, ""} -> where(query, [p], p.leader_id == ^lid)
      _ -> query
    end
  end

  defp maybe_filter_leader_id(query, _), do: query

  defp maybe_filter_min_size(query, %{"min_size" => v}) when v not in ["", nil] do
    case Integer.parse(to_string(v)) do
      {n, ""} -> where(query, [p], p.max_size >= ^n)
      _ -> query
    end
  end

  defp maybe_filter_min_size(query, _), do: query

  defp maybe_filter_max_size(query, %{"max_size" => v}) when v not in ["", nil] do
    case Integer.parse(to_string(v)) do
      {n, ""} -> where(query, [p], p.max_size <= ^n)
      _ -> query
    end
  end

  defp maybe_filter_max_size(query, _), do: query

  defp apply_party_sort(query, "updated_at"), do: order_by(query, [p], desc: p.updated_at)
  defp apply_party_sort(query, "updated_at_asc"), do: order_by(query, [p], asc: p.updated_at)
  defp apply_party_sort(query, "inserted_at"), do: order_by(query, [p], desc: p.inserted_at)
  defp apply_party_sort(query, "inserted_at_asc"), do: order_by(query, [p], asc: p.inserted_at)
  defp apply_party_sort(query, "max_size"), do: order_by(query, [p], desc: p.max_size)
  defp apply_party_sort(query, "max_size_asc"), do: order_by(query, [p], asc: p.max_size)
  defp apply_party_sort(query, _), do: order_by(query, [p], desc: p.updated_at)
end
