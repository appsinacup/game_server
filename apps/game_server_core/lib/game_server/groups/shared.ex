defmodule GameServer.Groups.Shared do
  @moduledoc false
  # Internal helpers shared by `GameServer.Groups` and its submodules
  # (`Invites`, `JoinRequests`). Not part of the public Groups API.

  import Ecto.Query, warn: false

  alias GameServer.Groups
  alias GameServer.Groups.Group
  alias GameServer.Groups.GroupInvite
  alias GameServer.Groups.GroupMember
  alias GameServer.Repo
  alias GameServer.Repo.AdvisoryLock

  @doc false
  def broadcast_group(group_id, event) do
    Phoenix.PubSub.broadcast(GameServer.PubSub, "group:#{group_id}", event)
  end

  # -- Group cache (version-based, keyed by group_id) --

  @doc false
  def group_cache_version(group_id) when is_binary(group_id) do
    GameServer.Cache.get!({:groups, :group_version, group_id}) || 1
  end

  @doc false
  def invalidate_group_cache(group_id) when is_binary(group_id) do
    GameServer.Async.run(fn ->
      _ = GameServer.Cache.bump_version({:groups, :group_version, group_id})
      :ok
    end)

    :ok
  end

  # -- Invite cache (version-based, keyed by user_id) --

  def invite_cache_version(user_id) when is_binary(user_id) do
    GameServer.Cache.get!({:group_invites, :version, user_id}) || 1
  end

  def invalidate_invite_cache(user_id) when is_binary(user_id) do
    GameServer.Async.run(fn ->
      _ = GameServer.Cache.bump_version({:group_invites, :version, user_id})
      :ok
    end)

    :ok
  end

  # Synchronous version — used when the caller needs the cache to be
  # invalidated immediately before returning (e.g. accept_invite where the
  # client polls right away).
  def invalidate_invite_cache_sync(user_id) when is_binary(user_id) do
    _ = GameServer.Cache.bump_version({:group_invites, :version, user_id})
    :ok
  end

  # Mark any pending GroupInvite records for a user+group as "accepted" and
  # notify/invalidate caches for each sender. Called when a user joins a group
  # through a path other than accept_invite (e.g. manual join, admin approval).
  def mark_pending_invites_accepted(user_id, group_id) do
    pending_invites =
      from(i in GroupInvite,
        where:
          i.recipient_id == ^user_id and i.group_id == ^group_id and
            i.status == "pending"
      )
      |> Repo.all()

    if pending_invites != [] do
      from(i in GroupInvite,
        where:
          i.recipient_id == ^user_id and i.group_id == ^group_id and
            i.status == "pending"
      )
      |> Repo.update_all(set: [status: "accepted", updated_at: DateTime.utc_now()])

      invalidate_invite_cache_sync(user_id)

      user = GameServer.Accounts.get_user(user_id)
      user_name = (user && user.display_name) || ""
      group = Groups.get_group(group_id)
      group_title = (group && group.title) || ""

      sender_ids = pending_invites |> Enum.map(& &1.sender_id) |> Enum.uniq()

      for sender_id <- sender_ids do
        invalidate_invite_cache_sync(sender_id)

        GameServer.Notifications.admin_create_notification(
          user_id,
          sender_id,
          %{
            "title" => "#{user_name} joined #{group_title}",
            "content" => "",
            "metadata" => %{
              "type" => "group_invite_accepted",
              "group_id" => group_id,
              "group_name" => group_title,
              "user_id" => user_id,
              "user_name" => user_name
            }
          }
        )

        Phoenix.PubSub.broadcast(
          GameServer.PubSub,
          "user:#{sender_id}",
          {:group_invite_accepted, %{group_id: group_id}}
        )
      end
    end

    :ok
  end

  # Collect unique user IDs (senders + recipients) with pending invites for a group.
  # Must be called BEFORE deleting the group (cascade deletes the rows).
  def gather_pending_invite_user_ids(group_id) do
    from(i in GroupInvite,
      where: i.group_id == ^group_id and i.status == "pending",
      select: {i.sender_id, i.recipient_id}
    )
    |> Repo.all()
    |> Enum.flat_map(fn {s, r} -> [s, r] end)
    |> Enum.uniq()
  end

  # Invalidate invite caches for a list of user IDs.
  def invalidate_invite_caches_for_users(user_ids) do
    for uid <- user_ids, do: invalidate_invite_cache_sync(uid)
    :ok
  end

  # Broadcast a group_deleted event to each user who had a pending invite.
  def notify_invite_users_group_deleted(user_ids, group) do
    for uid <- user_ids do
      Phoenix.PubSub.broadcast(
        GameServer.PubSub,
        "user:#{uid}",
        {:group_invite_cancelled, %{group_id: group.id, group_name: group.title}}
      )
    end

    :ok
  end

  def run_before_group_join_hook(user_id, %Group{} = group, opts)
      when is_binary(user_id) and is_map(opts) do
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

  # Shared helper: acquire advisory lock, check capacity, run hook, insert member.
  @doc false
  def do_add_group_member(user_id, group_id, group, source) do
    Repo.transaction(fn ->
      AdvisoryLock.lock(:group, group_id)

      if Groups.count_group_members(group_id) >= group.max_members do
        Repo.rollback(:full)
      end

      max_groups = GameServer.Limits.get(:max_groups_per_user)

      if Groups.count_user_group_memberships(user_id) >= max_groups do
        Repo.rollback(:too_many_groups)
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
end
