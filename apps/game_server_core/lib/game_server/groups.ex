defmodule GameServer.Groups do
  @moduledoc """
  Context module for group management: creating, updating, listing, joining,
  leaving, kicking, promoting/demoting members, and handling join requests.

  Groups are persistent communities (unlike ephemeral lobbies). They support
  three visibility types:

  - **public** – anyone can join directly
  - **private** – anyone can request to join; an admin must approve
  - **hidden** – only invited users can join (via notifications / invite API)

  ## Usage

      # Create a group (creator becomes admin)
      {:ok, group} = Groups.create_group(user_id, %{"title" => "Cool Group"})

      # List public/private groups (hidden excluded)
      groups = Groups.list_groups(%{}, page: 1, page_size: 25)

      # Join a public group
      {:ok, member} = Groups.join_group(user_id, group.id)

      # Request to join a private group
      {:ok, request} = Groups.request_join(user_id, group.id)

      # Admin approves a join request
      {:ok, member} = Groups.approve_join_request(admin_id, request.id)

  ## PubSub Events

  - `"groups"` topic:
    - `{:group_created, group}`
    - `{:group_updated, group}`
    - `{:group_deleted, group_id}`

  - `"group:<group_id>"` topic:
    - `{:member_joined, group_id, user_id}`
    - `{:member_left, group_id, user_id}`
    - `{:member_kicked, group_id, user_id}`
    - `{:member_promoted, group_id, user_id}`
    - `{:member_demoted, group_id, user_id}`
    - `{:group_updated, group}`
    - `{:join_request_created, group_id, user_id}`
    - `{:join_request_approved, group_id, user_id}`
    - `{:join_request_rejected, group_id, user_id}`
    - `{:group_notification, group_id, sender_id}`
  """

  import Ecto.Query, warn: false
  use Nebulex.Caching, cache: GameServer.Cache

  require Logger

  alias GameServer.Friends
  alias GameServer.Groups.Group
  alias GameServer.Groups.GroupJoinRequest
  alias GameServer.Groups.GroupMember
  alias GameServer.Repo
  alias GameServer.Repo.AdvisoryLock

  # ---------------------------------------------------------------------------
  # PubSub
  # ---------------------------------------------------------------------------

  @groups_topic "groups"

  @doc "Subscribe to global group events."
  @spec subscribe_groups() :: :ok | {:error, term()}
  def subscribe_groups do
    Phoenix.PubSub.subscribe(GameServer.PubSub, @groups_topic)
  end

  @doc "Subscribe to a specific group's events."
  @spec subscribe_group(integer()) :: :ok | {:error, term()}
  def subscribe_group(group_id) do
    Phoenix.PubSub.subscribe(GameServer.PubSub, "group:#{group_id}")
  end

  @doc "Unsubscribe from a specific group's events."
  @spec unsubscribe_group(integer()) :: :ok
  def unsubscribe_group(group_id) do
    Phoenix.PubSub.unsubscribe(GameServer.PubSub, "group:#{group_id}")
  end

  defp broadcast_groups(event) do
    Phoenix.PubSub.broadcast(GameServer.PubSub, @groups_topic, event)
  end

  defp broadcast_group(group_id, event) do
    Phoenix.PubSub.broadcast(GameServer.PubSub, "group:#{group_id}", event)
  end

  # ---------------------------------------------------------------------------
  # Cache helpers
  # ---------------------------------------------------------------------------

  @group_cache_ttl_ms 60_000

  defp group_cache_version(group_id) when is_integer(group_id) do
    GameServer.Cache.get({:groups, :group_version, group_id}) || 1
  end

  defp invalidate_group_cache(group_id) when is_integer(group_id) do
    GameServer.Async.run(fn ->
      _ = GameServer.Cache.incr({:groups, :group_version, group_id}, 1, default: 1)
      :ok
    end)

    :ok
  end

  defp cache_match(nil), do: false
  defp cache_match(_), do: true

  @doc "Public wrapper for cache invalidation (used by admin controller)."
  @spec invalidate_group_cache_public(integer()) :: :ok
  def invalidate_group_cache_public(group_id) when is_integer(group_id) do
    invalidate_group_cache(group_id)
  end

  # ---------------------------------------------------------------------------
  # Queries – single group
  # ---------------------------------------------------------------------------

  @doc "Get a group by ID (cached)."
  @spec get_group(integer()) :: Group.t() | nil
  @decorate cacheable(
              key: {:groups, :get, group_cache_version(id), id},
              match: &cache_match/1,
              opts: [ttl: @group_cache_ttl_ms]
            )
  def get_group(id) when is_integer(id), do: Repo.get(Group, id)

  @doc "Get a group by ID (raises if not found, cached)."
  @spec get_group!(integer()) :: Group.t()
  @decorate cacheable(
              key: {:groups, :get, group_cache_version(id), id},
              opts: [ttl: @group_cache_ttl_ms]
            )
  def get_group!(id) when is_integer(id), do: Repo.get!(Group, id)

  @doc "Get a group by its unique title."
  @spec get_group_by_title(String.t()) :: Group.t() | nil
  def get_group_by_title(title) when is_binary(title) do
    Repo.get_by(Group, title: title)
  end

  # ---------------------------------------------------------------------------
  # Queries – list / count
  # ---------------------------------------------------------------------------

  @doc """
  List groups visible to the public (excludes hidden).

  ## Filters

    * `:title` – prefix search on title (case-insensitive)
    * `:type` – exact match on type (`"public"` or `"private"`)
    * `:min_members` – groups with max_members >= value
    * `:max_members` – groups with max_members <= value
    * `:metadata_key` / `:metadata_value` – filter by metadata entry

  ## Options

    * `:page` – page number (default 1)
    * `:page_size` – results per page (default 25)
  """
  @spec list_groups(map(), keyword()) :: [Group.t()]
  def list_groups(filters \\ %{}, opts \\ []) do
    q =
      from(g in Group)
      |> filter_hidden_false()
      |> apply_filters(filters)
      |> apply_sort(opts)

    results = paginate(q, opts)
    filter_by_metadata_in_memory(results, filters)
  end

  @doc "Count groups matching public filters (excludes hidden)."
  @spec count_list_groups(map()) :: non_neg_integer()
  def count_list_groups(filters \\ %{}) do
    q =
      from(g in Group)
      |> filter_hidden_false()
      |> apply_filters(filters)

    metadata_key = Map.get(filters, :metadata_key) || Map.get(filters, "metadata_key")

    if is_nil(metadata_key) do
      Repo.one(from g in q, select: count(g.id)) || 0
    else
      q |> Repo.all() |> filter_by_metadata_in_memory(filters) |> length()
    end
  end

  @doc """
  List ALL groups including hidden (admin only).
  """
  @spec list_all_groups(map(), keyword()) :: [Group.t()]
  def list_all_groups(filters \\ %{}, opts \\ []) do
    q = from(g in Group) |> apply_filters(filters) |> apply_sort(opts)
    paginate(q, opts)
  end

  @doc "Count ALL groups matching filters (admin)."
  @spec count_all_groups(map()) :: non_neg_integer()
  def count_all_groups(filters \\ %{}) do
    q = from(g in Group) |> apply_filters(filters)
    Repo.aggregate(q, :count, :id)
  end

  @doc "Count groups by type."
  @spec count_groups_by_type(String.t()) :: non_neg_integer()
  def count_groups_by_type(type) when type in ["public", "private", "hidden"] do
    Repo.one(from(g in Group, where: g.type == ^type, select: count(g.id))) || 0
  end

  @doc "Total member count across all groups."
  @spec count_all_members() :: non_neg_integer()
  def count_all_members do
    Repo.one(from(m in GroupMember, select: count(m.id))) || 0
  end

  # ---------------------------------------------------------------------------
  # Members
  # ---------------------------------------------------------------------------

  @doc "Get all members of a group."
  @spec get_group_members(integer()) :: [GroupMember.t()]
  def get_group_members(group_id) when is_integer(group_id) do
    from(m in GroupMember,
      where: m.group_id == ^group_id,
      order_by: [asc: m.inserted_at],
      preload: [:user]
    )
    |> Repo.all()
  end

  @doc "Get paginated members of a group with user info."
  @spec get_group_members_paginated(integer(), keyword()) :: [GroupMember.t()]
  def get_group_members_paginated(group_id, opts \\ []) when is_integer(group_id) do
    from(m in GroupMember,
      where: m.group_id == ^group_id,
      order_by: [asc: m.inserted_at],
      preload: [:user]
    )
    |> paginate(opts)
  end

  @doc "Count members in a group."
  @spec count_group_members(integer()) :: non_neg_integer()
  def count_group_members(group_id) when is_integer(group_id) do
    Repo.one(from(m in GroupMember, where: m.group_id == ^group_id, select: count(m.id))) || 0
  end

  @doc "Get a specific membership."
  @spec get_membership(integer(), integer()) :: GroupMember.t() | nil
  def get_membership(group_id, user_id) do
    Repo.get_by(GroupMember, group_id: group_id, user_id: user_id)
  end

  @doc "Check if user is an admin of the group."
  @spec admin?(integer(), integer()) :: boolean()
  def admin?(group_id, user_id) do
    case get_membership(group_id, user_id) do
      %GroupMember{role: "admin"} -> true
      _ -> false
    end
  end

  @doc "Check if user is a member (any role) of the group."
  @spec member?(integer(), integer()) :: boolean()
  def member?(group_id, user_id) do
    get_membership(group_id, user_id) != nil
  end

  @doc "List groups the user belongs to."
  @spec list_user_groups(integer(), keyword()) :: [Group.t()]
  def list_user_groups(user_id, opts \\ []) when is_integer(user_id) do
    from(g in Group,
      join: m in GroupMember,
      on: m.group_id == g.id,
      where: m.user_id == ^user_id,
      order_by: [asc: g.title]
    )
    |> paginate(opts)
  end

  @doc "List groups the user belongs to, together with the membership role."
  @spec list_user_groups_with_role(integer()) :: [{Group.t(), String.t()}]
  def list_user_groups_with_role(user_id) when is_integer(user_id) do
    from(g in Group,
      join: m in GroupMember,
      on: m.group_id == g.id,
      where: m.user_id == ^user_id,
      order_by: [asc: g.title],
      select: {g, m.role}
    )
    |> Repo.all()
  end

  @doc "Count groups the user belongs to."
  @spec count_user_groups(integer()) :: non_neg_integer()
  def count_user_groups(user_id) when is_integer(user_id) do
    from(m in GroupMember, where: m.user_id == ^user_id, select: count(m.id))
    |> Repo.one()
    |> Kernel.||(0)
  end

  @doc "List pending join requests sent by a user."
  @spec list_user_pending_requests(integer()) :: [GroupJoinRequest.t()]
  def list_user_pending_requests(user_id) when is_integer(user_id) do
    from(r in GroupJoinRequest,
      where: r.user_id == ^user_id and r.status == "pending",
      join: g in assoc(r, :group),
      order_by: [desc: r.inserted_at],
      preload: [group: g]
    )
    |> Repo.all()
  end

  @doc "Count pending invitations for a user."
  @spec count_invitations(integer()) :: non_neg_integer()
  def count_invitations(user_id) when is_integer(user_id) do
    import Ecto.Query

    from(n in GameServer.Notifications.Notification,
      where: n.recipient_id == ^user_id and n.title == "group_invite",
      select: count(n.id)
    )
    |> Repo.one()
    |> Kernel.||(0)
  end

  @doc "Count group invitations sent by a user."
  @spec count_sent_invitations(integer()) :: non_neg_integer()
  def count_sent_invitations(user_id) when is_integer(user_id) do
    import Ecto.Query

    from(n in GameServer.Notifications.Notification,
      where: n.sender_id == ^user_id and n.title == "group_invite",
      select: count(n.id)
    )
    |> Repo.one()
    |> Kernel.||(0)
  end

  # ---------------------------------------------------------------------------
  # Commands – create
  # ---------------------------------------------------------------------------

  @doc """
  Create a new group. The creating user becomes an admin member automatically.
  """
  @spec create_group(integer(), map()) ::
          {:ok, Group.t()} | {:error, Ecto.Changeset.t() | term()}
  def create_group(user_id, attrs) when is_integer(user_id) and is_map(attrs) do
    attrs = normalize_params(attrs)

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:group, fn _changes ->
      %Group{}
      |> Group.changeset(attrs)
      |> Ecto.Changeset.put_change(:creator_id, user_id)
    end)
    |> Ecto.Multi.insert(:membership, fn %{group: group} ->
      GroupMember.changeset(%GroupMember{}, %{
        group_id: group.id,
        user_id: user_id,
        role: "admin"
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{group: group}} ->
        _ = invalidate_group_cache(group.id)
        broadcast_groups({:group_created, group})
        {:ok, group}

      {:error, :group, changeset, _} ->
        {:error, changeset}

      {:error, _op, changeset, _} ->
        {:error, changeset}
    end
  end

  # ---------------------------------------------------------------------------
  # Commands – update
  # ---------------------------------------------------------------------------

  @doc """
  Update group settings. Only admins can update.
  Cannot lower max_members below current member count.
  """
  @spec update_group(integer(), integer(), map()) ::
          {:ok, Group.t()} | {:error, atom() | Ecto.Changeset.t()}
  def update_group(user_id, group_id, attrs)
      when is_integer(user_id) and is_integer(group_id) and is_map(attrs) do
    if admin?(group_id, user_id) do
      group = get_group!(group_id)
      attrs = normalize_params(attrs)

      new_max = Map.get(attrs, "max_members") || Map.get(attrs, :max_members)

      if is_nil(new_max) do
        do_update_group(group, attrs)
      else
        new_max_int = if is_binary(new_max), do: String.to_integer(new_max), else: new_max
        current_count = count_group_members(group_id)

        if new_max_int < current_count do
          {:error, :max_members_too_low}
        else
          do_update_group(group, attrs)
        end
      end
    else
      {:error, :not_admin}
    end
  end

  defp do_update_group(%Group{} = group, attrs) do
    group
    |> Group.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated} ->
        _ = invalidate_group_cache(updated.id)
        broadcast_group(updated.id, {:group_updated, updated})
        broadcast_groups({:group_updated, updated})
        {:ok, updated}

      error ->
        error
    end
  end

  # ---------------------------------------------------------------------------
  # Commands – delete
  # ---------------------------------------------------------------------------

  @doc "Return a changeset for tracking group changes (admin edit forms)."
  @spec change_group(Group.t(), map()) :: Ecto.Changeset.t()
  def change_group(%Group{} = group, attrs \\ %{}) do
    Group.changeset(group, attrs)
  end

  @doc "Admin-level update, bypasses membership checks."
  @spec admin_update_group(Group.t(), map()) :: {:ok, Group.t()} | {:error, Ecto.Changeset.t()}
  def admin_update_group(%Group{} = group, attrs) do
    do_update_group(group, attrs)
  end

  @doc """
  Delete a group. Admin-only. Refuses if the group still has members — groups
  are auto-deleted when the last member leaves.
  """
  @spec delete_group(integer(), integer()) :: {:ok, Group.t()} | {:error, atom()}
  def delete_group(user_id, group_id)
      when is_integer(user_id) and is_integer(group_id) do
    cond do
      not admin?(group_id, user_id) ->
        {:error, :not_admin}

      count_group_members(group_id) > 0 ->
        {:error, :has_members}

      true ->
        group = get_group!(group_id)

        case Repo.delete(group) do
          {:ok, deleted} ->
            _ = invalidate_group_cache(deleted.id)
            broadcast_groups({:group_deleted, deleted.id})
            {:ok, deleted}

          error ->
            error
        end
    end
  end

  @doc "Admin-level delete (no membership check, for server admins)."
  @spec admin_delete_group(integer()) :: {:ok, Group.t()} | {:error, term()}
  def admin_delete_group(group_id) when is_integer(group_id) do
    group = get_group!(group_id)

    case Repo.delete(group) do
      {:ok, deleted} ->
        _ = invalidate_group_cache(deleted.id)
        broadcast_groups({:group_deleted, deleted.id})
        {:ok, deleted}

      error ->
        error
    end
  end

  @doc """
  Clean up group memberships before a user is deleted.

  For each group the user belongs to:
  - If the user is the sole admin and other members exist, promotes the oldest
    member to admin before removing the user's membership row.
  - Removes the membership row.
  - If the group has no members left after removal, deletes the group.

  This must be called *before* `Repo.delete(user)` so that the membership
  rows still exist (the DB cascade would silently delete them otherwise
  without running the admin-transfer / empty-group logic).
  """
  @spec handle_user_deletion(integer()) :: :ok
  def handle_user_deletion(user_id) when is_integer(user_id) do
    memberships =
      from(m in GroupMember, where: m.user_id == ^user_id)
      |> Repo.all()

    Enum.each(memberships, fn member ->
      group_id = member.group_id

      if member.role == "admin" do
        maybe_transfer_admin_before_leave(member, group_id, user_id)
      else
        do_leave(member, group_id, user_id)
      end
    end)

    :ok
  end

  # ---------------------------------------------------------------------------
  # Commands – join / leave / kick
  # ---------------------------------------------------------------------------

  @doc """
  Join a public group directly. Returns error for private/hidden groups.
  """
  @spec join_group(integer(), integer()) ::
          {:ok, GroupMember.t()} | {:error, atom()}
  def join_group(user_id, group_id)
      when is_integer(user_id) and is_integer(group_id) do
    group = get_group(group_id)

    cond do
      is_nil(group) ->
        {:error, :not_found}

      group.type != "public" ->
        {:error, :not_public}

      member?(group_id, user_id) ->
        {:error, :already_member}

      true ->
        do_add_group_member(user_id, group_id, group, "public_join")
    end
  end

  @doc "Leave a group."
  @spec leave_group(integer(), integer()) :: {:ok, GroupMember.t()} | {:error, atom()}
  def leave_group(user_id, group_id)
      when is_integer(user_id) and is_integer(group_id) do
    case get_membership(group_id, user_id) do
      nil ->
        {:error, :not_member}

      member ->
        # If leaving user is admin, check if they're the last admin
        if member.role == "admin" do
          maybe_transfer_admin_before_leave(member, group_id, user_id)
        else
          do_leave(member, group_id, user_id)
        end
    end
  end

  defp maybe_transfer_admin_before_leave(member, group_id, user_id) do
    admin_count =
      from(m in GroupMember,
        where: m.group_id == ^group_id and m.role == "admin",
        select: count(m.id)
      )
      |> Repo.one()

    if admin_count <= 1 do
      # Last admin — try to promote the longest-standing non-admin member
      next_member =
        from(m in GroupMember,
          where: m.group_id == ^group_id and m.user_id != ^user_id and m.role == "member",
          order_by: [asc: m.inserted_at],
          limit: 1
        )
        |> Repo.one()

      if next_member do
        next_member
        |> Ecto.Changeset.change(%{role: "admin"})
        |> Repo.update!()

        broadcast_group(group_id, {:member_promoted, group_id, next_member.user_id})
      end

      # Leave even if no other member remains (group becomes empty)
      do_leave(member, group_id, user_id)
    else
      do_leave(member, group_id, user_id)
    end
  end

  defp do_leave(member, group_id, user_id) do
    case Repo.delete(member) do
      {:ok, deleted} ->
        _ = invalidate_group_cache(group_id)
        broadcast_group(group_id, {:member_left, group_id, user_id})
        maybe_delete_empty_group(group_id)
        {:ok, deleted}

      error ->
        error
    end
  end

  defp maybe_delete_empty_group(group_id) do
    if count_group_members(group_id) == 0 do
      case Repo.get(Group, group_id) do
        nil ->
          :ok

        group ->
          Repo.delete(group)
          _ = invalidate_group_cache(group_id)
          broadcast_groups({:group_deleted, group_id})
      end
    end
  end

  @doc "Kick a member from the group. Only admins can kick."
  @spec kick_member(integer(), integer(), integer()) ::
          {:ok, GroupMember.t()} | {:error, atom()}
  def kick_member(admin_id, group_id, target_id)
      when is_integer(admin_id) and is_integer(group_id) and is_integer(target_id) do
    cond do
      not admin?(group_id, admin_id) ->
        {:error, :not_admin}

      admin_id == target_id ->
        {:error, :cannot_kick_self}

      true ->
        case get_membership(group_id, target_id) do
          nil ->
            {:error, :not_member}

          member ->
            case Repo.delete(member) do
              {:ok, deleted} ->
                _ = invalidate_group_cache(group_id)
                broadcast_group(group_id, {:member_kicked, group_id, target_id})
                {:ok, deleted}

              error ->
                error
            end
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Commands – promote / demote
  # ---------------------------------------------------------------------------

  @doc "Promote a member to admin. Only admins can promote."
  @spec promote_member(integer(), integer(), integer()) ::
          {:ok, GroupMember.t()} | {:error, atom()}
  def promote_member(admin_id, group_id, target_id)
      when is_integer(admin_id) and is_integer(group_id) and is_integer(target_id) do
    cond do
      not admin?(group_id, admin_id) ->
        {:error, :not_admin}

      admin_id == target_id ->
        {:error, :cannot_promote_self}

      true ->
        case get_membership(group_id, target_id) do
          nil ->
            {:error, :not_member}

          %GroupMember{role: "admin"} ->
            {:error, :already_admin}

          member ->
            member
            |> Ecto.Changeset.change(%{role: "admin"})
            |> Repo.update()
            |> case do
              {:ok, updated} ->
                _ = invalidate_group_cache(group_id)
                broadcast_group(group_id, {:member_promoted, group_id, target_id})
                {:ok, updated}

              error ->
                error
            end
        end
    end
  end

  @doc "Demote an admin to member. Only admins can demote other admins."
  @spec demote_member(integer(), integer(), integer()) ::
          {:ok, GroupMember.t()} | {:error, atom()}
  def demote_member(admin_id, group_id, target_id)
      when is_integer(admin_id) and is_integer(group_id) and is_integer(target_id) do
    cond do
      not admin?(group_id, admin_id) ->
        {:error, :not_admin}

      admin_id == target_id ->
        {:error, :cannot_demote_self}

      true ->
        case get_membership(group_id, target_id) do
          nil ->
            {:error, :not_member}

          %GroupMember{role: "member"} ->
            {:error, :already_member}

          member ->
            member
            |> Ecto.Changeset.change(%{role: "member"})
            |> Repo.update()
            |> case do
              {:ok, updated} ->
                _ = invalidate_group_cache(group_id)
                broadcast_group(group_id, {:member_demoted, group_id, target_id})
                {:ok, updated}

              error ->
                error
            end
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Commands – join requests (private groups)
  # ---------------------------------------------------------------------------

  @doc """
  Request to join a private group. Creates a pending join request.
  """
  @spec request_join(integer(), integer()) ::
          {:ok, GroupJoinRequest.t()} | {:error, atom()}
  def request_join(user_id, group_id)
      when is_integer(user_id) and is_integer(group_id) do
    group = get_group(group_id)

    cond do
      is_nil(group) ->
        {:error, :not_found}

      group.type != "private" ->
        {:error, :not_private}

      member?(group_id, user_id) ->
        {:error, :already_member}

      true ->
        # Check for existing pending request
        existing =
          Repo.get_by(GroupJoinRequest,
            group_id: group_id,
            user_id: user_id,
            status: "pending"
          )

        if existing do
          {:error, :already_requested}
        else
          %GroupJoinRequest{}
          |> GroupJoinRequest.changeset(%{group_id: group_id, user_id: user_id})
          |> Repo.insert(
            on_conflict: {:replace, [:status, :updated_at]},
            conflict_target: [:group_id, :user_id]
          )
          |> case do
            {:ok, request} ->
              broadcast_group(group_id, {:join_request_created, group_id, user_id})
              {:ok, request}

            error ->
              error
          end
        end
    end
  end

  @doc "List pending join requests for a group (admin only)."
  @spec list_join_requests(integer(), integer(), keyword()) ::
          {:ok, [GroupJoinRequest.t()]} | {:error, atom()}
  def list_join_requests(admin_id, group_id, opts \\ [])
      when is_integer(admin_id) and is_integer(group_id) do
    if admin?(group_id, admin_id) do
      page = Keyword.get(opts, :page, 1)
      page_size = Keyword.get(opts, :page_size, 25)
      offset = (page - 1) * page_size

      requests =
        from(r in GroupJoinRequest,
          where: r.group_id == ^group_id and r.status == "pending",
          order_by: [asc: r.inserted_at],
          limit: ^page_size,
          offset: ^offset,
          preload: [:user]
        )
        |> Repo.all()

      {:ok, requests}
    else
      {:error, :not_admin}
    end
  end

  @spec count_join_requests(integer()) :: non_neg_integer()
  def count_join_requests(group_id) when is_integer(group_id) do
    Repo.one(
      from(r in GroupJoinRequest,
        where: r.group_id == ^group_id and r.status == "pending",
        select: count(r.id)
      )
    ) || 0
  end

  @doc "Approve a pending join request. Admin only."
  @spec approve_join_request(integer(), integer()) ::
          {:ok, GroupMember.t()} | {:error, atom()}
  def approve_join_request(admin_id, request_id)
      when is_integer(admin_id) and is_integer(request_id) do
    case Repo.get(GroupJoinRequest, request_id) do
      nil ->
        {:error, :not_found}

      %GroupJoinRequest{status: status} when status != "pending" ->
        {:error, :not_pending}

      %GroupJoinRequest{group_id: group_id} = request ->
        group = get_group!(group_id)

        if admin?(group_id, admin_id) do
          approve_join_request_with_hook(request, group, admin_id, request_id)
        else
          {:error, :not_admin}
        end
    end
  end

  defp approve_join_request_with_hook(request, group, admin_id, request_id) do
    group_id = request.group_id
    user_id = request.user_id

    case run_before_group_join_hook(user_id, group, %{
           "source" => "join_request_approval",
           "request_id" => request_id,
           "actor_user_id" => admin_id,
           "admin_id" => admin_id
         }) do
      :ok ->
        Ecto.Multi.new()
        |> Ecto.Multi.run(:lock_and_check, fn _repo, _changes ->
          AdvisoryLock.lock(:group, group_id)

          if count_group_members(group_id) >= group.max_members do
            {:error, :full}
          else
            {:ok, :space_available}
          end
        end)
        |> Ecto.Multi.update(:request, Ecto.Changeset.change(request, %{status: "accepted"}))
        |> Ecto.Multi.insert(:membership, fn _changes ->
          GroupMember.changeset(%GroupMember{}, %{
            group_id: group_id,
            user_id: user_id,
            role: "member"
          })
        end)
        |> Repo.transaction()
        |> case do
          {:ok, %{membership: member}} ->
            _ = invalidate_group_cache(group_id)
            broadcast_group(group_id, {:join_request_approved, group_id, user_id})
            broadcast_group(group_id, {:member_joined, group_id, user_id})
            {:ok, member}

          {:error, _op, changeset, _} ->
            {:error, changeset}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Reject a pending join request. Admin only."
  @spec reject_join_request(integer(), integer()) ::
          {:ok, GroupJoinRequest.t()} | {:error, atom()}
  def reject_join_request(admin_id, request_id)
      when is_integer(admin_id) and is_integer(request_id) do
    case Repo.get(GroupJoinRequest, request_id) do
      nil ->
        {:error, :not_found}

      %GroupJoinRequest{status: status} when status != "pending" ->
        {:error, :not_pending}

      %GroupJoinRequest{group_id: group_id} = request ->
        if admin?(group_id, admin_id) do
          request
          |> Ecto.Changeset.change(%{status: "rejected"})
          |> Repo.update()
          |> case do
            {:ok, updated} ->
              broadcast_group(group_id, {:join_request_rejected, group_id, updated.user_id})
              {:ok, updated}

            error ->
              error
          end
        else
          {:error, :not_admin}
        end
    end
  end

  @doc "Cancel (delete) a pending join request. Only the requesting user can cancel."
  @spec cancel_join_request(integer(), integer()) ::
          {:ok, GroupJoinRequest.t()} | {:error, atom()}
  def cancel_join_request(user_id, request_id)
      when is_integer(user_id) and is_integer(request_id) do
    case Repo.get(GroupJoinRequest, request_id) do
      nil ->
        {:error, :not_found}

      %GroupJoinRequest{user_id: ^user_id, status: "pending"} = request ->
        case Repo.delete(request) do
          {:ok, deleted} ->
            broadcast_group(
              request.group_id,
              {:join_request_cancelled, request.group_id, user_id}
            )

            {:ok, deleted}

          error ->
            error
        end

      %GroupJoinRequest{status: status} when status != "pending" ->
        {:error, :not_pending}

      _other ->
        {:error, :not_owner}
    end
  end

  # ---------------------------------------------------------------------------
  # Commands – invite (hidden groups)
  # ---------------------------------------------------------------------------

  @doc """
  Invite a user to a hidden group by sending a notification with metadata.
  The notification system handles delivery; this creates the notification with
  a special title so the client can recognise it as a group invite.
  """
  @spec invite_to_group(integer(), integer(), integer()) ::
          {:ok, term()} | {:error, atom()}
  def invite_to_group(admin_id, group_id, target_user_id)
      when is_integer(admin_id) and is_integer(group_id) and is_integer(target_user_id) do
    group = get_group(group_id)

    cond do
      is_nil(group) ->
        {:error, :not_found}

      not admin?(group_id, admin_id) ->
        {:error, :not_admin}

      member?(group_id, target_user_id) ->
        {:error, :already_member}

      Friends.blocked?(admin_id, target_user_id) ->
        {:error, :blocked}

      true ->
        GameServer.Notifications.admin_create_notification(admin_id, target_user_id, %{
          "title" => "group_invite",
          "content" => "You have been invited to join group: #{group.title}",
          "metadata" => %{"group_id" => group_id, "group_name" => group.title}
        })
    end
  end

  @doc """
  Accept a group invite (for hidden groups). The user must have a group_invite
  notification containing the group_id.
  """
  @spec accept_invite(integer(), integer()) ::
          {:ok, GroupMember.t()} | {:error, atom()}
  def accept_invite(user_id, group_id)
      when is_integer(user_id) and is_integer(group_id) do
    group = get_group(group_id)

    cond do
      is_nil(group) ->
        {:error, :not_found}

      group.type != "hidden" ->
        {:error, :not_hidden}

      member?(group_id, user_id) ->
        {:error, :already_member}

      true ->
        do_add_group_member(user_id, group_id, group, "invite_accept")
    end
  end

  # Shared helper: acquire advisory lock, check capacity, run hook, insert member.
  defp do_add_group_member(user_id, group_id, group, source) do
    Repo.transaction(fn ->
      AdvisoryLock.lock(:group, group_id)

      if count_group_members(group_id) >= group.max_members do
        Repo.rollback(:full)
      end

      case run_before_group_join_hook(user_id, group, %{"source" => source}) do
        :ok -> insert_group_member(group_id, user_id)
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp insert_group_member(group_id, user_id) do
    case %GroupMember{}
         |> GroupMember.changeset(%{group_id: group_id, user_id: user_id, role: "member"})
         |> Repo.insert() do
      {:ok, member} ->
        _ = invalidate_group_cache(group_id)
        broadcast_group(group_id, {:member_joined, group_id, user_id})
        member

      {:error, reason} ->
        Repo.rollback(reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Invitations list
  # ---------------------------------------------------------------------------

  @doc """
  List pending group invitations for a user. These are notifications with
  title `"group_invite"` and a metadata `group_id`.
  """
  @spec list_invitations(integer(), keyword()) :: [map()]
  def list_invitations(user_id, opts \\ []) when is_integer(user_id) do
    import Ecto.Query

    from(n in GameServer.Notifications.Notification,
      where:
        n.recipient_id == ^user_id and
          n.title == "group_invite",
      order_by: [desc: n.inserted_at]
    )
    |> paginate(opts)
    |> Enum.map(&serialize_invite_notification/1)
  end

  @doc """
  List group invitations sent by a user.
  Returns notifications where the user is the sender and the title is `"group_invite"`.
  """
  @spec list_sent_invitations(integer(), keyword()) :: [map()]
  def list_sent_invitations(user_id, opts \\ []) when is_integer(user_id) do
    import Ecto.Query

    from(n in GameServer.Notifications.Notification,
      where:
        n.sender_id == ^user_id and
          n.title == "group_invite",
      preload: [:recipient],
      order_by: [desc: n.inserted_at]
    )
    |> paginate(opts)
    |> Enum.map(fn n ->
      Map.merge(serialize_invite_notification(n), %{
        recipient_id: n.recipient_id,
        recipient_name: n.recipient && n.recipient.display_name
      })
    end)
  end

  @doc """
  Cancel (delete) a group invitation that the current user sent.
  Only the sender can cancel their own invitation.
  """
  @spec cancel_invite(integer(), integer()) :: :ok | {:error, atom()}
  def cancel_invite(user_id, notification_id)
      when is_integer(user_id) and is_integer(notification_id) do
    import Ecto.Query

    case Repo.get(GameServer.Notifications.Notification, notification_id) do
      nil ->
        {:error, :not_found}

      %{sender_id: ^user_id, title: "group_invite"} = notification ->
        Repo.delete(notification)
        :ok

      %{title: "group_invite"} ->
        {:error, :not_owner}

      _other ->
        {:error, :not_found}
    end
  end

  defp serialize_invite_notification(n) do
    %{
      id: n.id,
      group_id: get_in(n.metadata, ["group_id"]),
      group_name: get_in(n.metadata, ["group_name"]),
      sender_id: n.sender_id,
      inserted_at: n.inserted_at
    }
  end

  # ---------------------------------------------------------------------------
  # Group notifications
  # ---------------------------------------------------------------------------

  @doc """
  Send a notification to all members of a group (except the sender).

  Any group member can send a notification. The notification is created for
  each member using a direct insert (bypassing the friends-only check).
  The `group_id` / `group_name` are stored in metadata so the client can
  recognise and route it.

  ## Options

    * `title` – notification title string (default: `"group_notification"`).
      The title is part of the unique constraint `(sender_id, recipient_id, title)`,
      so different titles create separate notification slots.

  Because of the unique constraint on `(sender_id, recipient_id, title)`, a
  new notification from the same sender to the same recipient with the same title
  replaces the previous one (upsert). This prevents spam while keeping the latest
  message.

  Returns `{:ok, count}` with the number of notifications sent.
  """
  @spec notify_group(integer(), integer(), String.t(), map()) ::
          {:ok, non_neg_integer()} | {:error, atom()}
  def notify_group(sender_id, group_id, content, metadata \\ %{})
      when is_integer(sender_id) and is_integer(group_id) and is_binary(content) do
    group = get_group(group_id)
    title = Map.get(metadata, "title") || Map.get(metadata, :title) || "group_notification"
    # Remove the title key from metadata so it doesn't duplicate in the payload
    clean_metadata =
      metadata |> Map.delete("title") |> Map.delete(:title)

    cond do
      is_nil(group) ->
        {:error, :not_found}

      not member?(group_id, sender_id) ->
        {:error, :not_member}

      true ->
        member_ids =
          from(m in GroupMember,
            where: m.group_id == ^group_id and m.user_id != ^sender_id,
            select: m.user_id
          )
          |> Repo.all()

        notification_attrs = %{
          "title" => title,
          "content" => content,
          "metadata" =>
            Map.merge(clean_metadata, %{
              "group_id" => group_id,
              "group_name" => group.title
            })
        }

        sent =
          Enum.reduce(member_ids, 0, fn recipient_id, acc ->
            case upsert_group_notification(sender_id, recipient_id, notification_attrs) do
              {:ok, _} -> acc + 1
              _ -> acc
            end
          end)

        broadcast_group(group_id, {:group_notification, group_id, sender_id})
        {:ok, sent}
    end
  end

  defp upsert_group_notification(sender_id, recipient_id, attrs) do
    alias GameServer.Notifications.Notification

    changeset =
      %Notification{}
      |> Notification.changeset(attrs)
      |> Ecto.Changeset.put_change(:sender_id, sender_id)
      |> Ecto.Changeset.put_change(:recipient_id, recipient_id)

    case Repo.insert(changeset,
           on_conflict: {:replace, [:content, :metadata, :updated_at]},
           conflict_target: [:sender_id, :recipient_id, :title]
         ) do
      {:ok, notification} ->
        GameServer.Notifications.invalidate_notifications_cache(recipient_id)

        Phoenix.PubSub.broadcast(
          GameServer.PubSub,
          "notifications:user:#{recipient_id}",
          {:new_notification, notification}
        )

        {:ok, notification}

      error ->
        error
    end
  end

  defp run_before_group_join_hook(user_id, %Group{} = group, opts)
       when is_integer(user_id) and is_map(opts) do
    case Repo.get(GameServer.Accounts.User, user_id) do
      nil ->
        {:error, :not_found}

      user ->
        actor_user_id = Map.get(opts, "actor_user_id") || Map.get(opts, :actor_user_id) || user_id

        hook_opts =
          Map.merge(opts, %{
            "actor_user_id" => actor_user_id,
            "joining_user_id" => user_id,
            "group_id" => group.id,
            "group_name" => group.title,
            "group_type" => group.type,
            "group_metadata" => group.metadata || %{}
          })

        case GameServer.Hooks.internal_call(:before_group_join, [user, group, hook_opts],
               caller: actor_user_id
             ) do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp filter_hidden_false(q) do
    from g in q, where: g.type != "hidden"
  end

  defp apply_filters(q, filters) do
    q
    |> filter_by_title(filters)
    |> filter_by_type(filters)
    |> filter_by_min_members(filters)
    |> filter_by_max_members(filters)
  end

  defp filter_by_title(q, filters) do
    case Map.get(filters, :title) || Map.get(filters, "title") do
      nil ->
        q

      "" ->
        q

      term ->
        prefix = String.downcase(String.trim(term)) <> "%"
        from g in q, where: fragment("lower(?) LIKE ?", g.title, ^prefix)
    end
  end

  defp filter_by_type(q, filters) do
    case Map.get(filters, :type) || Map.get(filters, "type") do
      nil -> q
      "" -> q
      t when t in ["public", "private", "hidden"] -> from g in q, where: g.type == ^t
      _ -> q
    end
  end

  defp filter_by_min_members(q, filters) do
    case Map.get(filters, :min_members) || Map.get(filters, "min_members") do
      nil -> q
      "" -> q
      v when is_binary(v) -> from g in q, where: g.max_members >= ^String.to_integer(v)
      v when is_integer(v) -> from g in q, where: g.max_members >= ^v
      _ -> q
    end
  end

  defp filter_by_max_members(q, filters) do
    case Map.get(filters, :max_members) || Map.get(filters, "max_members") do
      nil -> q
      "" -> q
      v when is_binary(v) -> from g in q, where: g.max_members <= ^String.to_integer(v)
      v when is_integer(v) -> from g in q, where: g.max_members <= ^v
      _ -> q
    end
  end

  defp filter_by_metadata_in_memory(results, filters) do
    case Map.get(filters, :metadata_key) || Map.get(filters, "metadata_key") do
      nil ->
        results

      key ->
        value = Map.get(filters, :metadata_value) || Map.get(filters, "metadata_value")

        Enum.filter(results, fn g ->
          case Map.get(g.metadata || %{}, key) do
            nil -> false
            _ when is_nil(value) -> true
            v -> String.contains?(to_string(v), to_string(value))
          end
        end)
    end
  end

  defp paginate(q, opts) do
    page = Keyword.get(opts, :page, nil)
    page_size = Keyword.get(opts, :page_size, nil)

    if page && page_size do
      offset = (page - 1) * page_size
      Repo.all(from g in q, limit: ^page_size, offset: ^offset)
    else
      Repo.all(q)
    end
  end

  defp apply_sort(q, opts) do
    case Keyword.get(opts, :sort_by) do
      "updated_at" -> from g in q, order_by: [desc: g.updated_at]
      "updated_at_asc" -> from g in q, order_by: [asc: g.updated_at]
      "inserted_at" -> from g in q, order_by: [desc: g.inserted_at]
      "inserted_at_asc" -> from g in q, order_by: [asc: g.inserted_at]
      "title" -> from g in q, order_by: [asc: g.title]
      "title_desc" -> from g in q, order_by: [desc: g.title]
      "max_members" -> from g in q, order_by: [desc: g.max_members]
      "max_members_asc" -> from g in q, order_by: [asc: g.max_members]
      _ -> from g in q, order_by: [desc: g.inserted_at]
    end
  end

  defp normalize_params(attrs) when is_map(attrs) do
    keys = Map.keys(attrs)
    has_string = Enum.any?(keys, &is_binary/1)
    has_atom = Enum.any?(keys, &is_atom/1)

    if has_string and has_atom do
      Map.new(attrs, fn {k, v} ->
        if is_atom(k), do: {Atom.to_string(k), v}, else: {k, v}
      end)
    else
      attrs
    end
  end

  defp normalize_params(other), do: other
end
