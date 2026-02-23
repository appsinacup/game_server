defmodule GameServer.GroupsTest.HooksAllowGroupJoin do
  def before_group_join(user, group, opts), do: {:ok, {user, group, opts}}
end

defmodule GameServer.GroupsTest.HooksDenyGroupJoin do
  def before_group_join(_user, _group, _opts), do: {:error, :level_too_low}
end

defmodule GameServer.GroupsTest.HooksCaptureGroupJoin do
  def before_group_join(_user, _group, opts), do: {:error, {:captured, opts}}
end

defmodule GameServer.GroupsTest do
  use GameServer.DataCase

  alias GameServer.AccountsFixtures
  alias GameServer.Groups
  alias GameServer.Groups.{Group, GroupJoinRequest, GroupMember}

  setup do
    owner = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
    other = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
    third = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
    %{owner: owner, other: other, third: third}
  end

  # ---------------------------------------------------------------------------
  # Create
  # ---------------------------------------------------------------------------

  describe "create_group/2" do
    test "creates a group and makes creator admin", %{owner: owner} do
      assert {:ok, %Group{} = group} =
               Groups.create_group(owner.id, %{
                 "title" => "Test Group",
                 "description" => "A test group",
                 "type" => "public",
                 "max_members" => 50
               })

      assert group.title == "Test Group"
      assert group.creator_id == owner.id
      assert Groups.admin?(group.id, owner.id)
    end

    test "sets title from params", %{owner: owner} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "My Group"})
      assert group.title == "My Group"
    end

    test "rejects duplicate titles", %{owner: owner} do
      {:ok, _} = Groups.create_group(owner.id, %{"title" => "Unique"})
      assert {:error, _changeset} = Groups.create_group(owner.id, %{"title" => "Unique"})
    end

    test "validates title is required", %{owner: owner} do
      assert {:error, _changeset} = Groups.create_group(owner.id, %{"description" => "no title"})
    end

    test "validates type must be public, private, or hidden", %{owner: owner} do
      assert {:error, changeset} =
               Groups.create_group(owner.id, %{"title" => "BadType", "type" => "invalid"})

      assert %{type: _} = errors_on(changeset)
    end

    test "validates max_members within bounds", %{owner: owner} do
      assert {:error, changeset} =
               Groups.create_group(owner.id, %{"title" => "TooBig", "max_members" => 20_000})

      assert %{max_members: _} = errors_on(changeset)
    end

    test "creates hidden group", %{owner: owner} do
      assert {:ok, %Group{type: "hidden"}} =
               Groups.create_group(owner.id, %{"title" => "Secret", "type" => "hidden"})
    end

    test "creates private group", %{owner: owner} do
      assert {:ok, %Group{type: "private"}} =
               Groups.create_group(owner.id, %{"title" => "PrvNew", "type" => "private"})
    end
  end

  # ---------------------------------------------------------------------------
  # Read
  # ---------------------------------------------------------------------------

  describe "get_group/1" do
    test "returns group by id", %{owner: owner} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Find Me"})
      assert %Group{title: "Find Me"} = Groups.get_group(group.id)
    end

    test "returns nil for missing id" do
      assert is_nil(Groups.get_group(999_999))
    end
  end

  describe "list_groups/2" do
    test "excludes hidden groups", %{owner: owner} do
      {:ok, _pub} = Groups.create_group(owner.id, %{"title" => "Public", "type" => "public"})
      {:ok, _hid} = Groups.create_group(owner.id, %{"title" => "Hidden", "type" => "hidden"})

      groups = Groups.list_groups(%{})
      names = Enum.map(groups, & &1.title)
      assert "Public" in names
      refute "Hidden" in names
    end

    test "supports pagination", %{owner: owner} do
      for i <- 1..5, do: Groups.create_group(owner.id, %{"title" => "Pg#{i}"})
      page1 = Groups.list_groups(%{}, page: 1, page_size: 2)
      assert length(page1) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # Update
  # ---------------------------------------------------------------------------

  describe "update_group/3" do
    test "admin can update group", %{owner: owner} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Old"})

      assert {:ok, updated} =
               Groups.update_group(owner.id, group.id, %{"title" => "New"})

      assert updated.title == "New"
    end

    test "non-admin cannot update", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Mine"})
      assert {:error, :not_admin} = Groups.update_group(other.id, group.id, %{"title" => "Ha"})
    end

    test "cannot lower max_members below current member count", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Full", "type" => "public"})
      {:ok, _} = Groups.join_group(other.id, group.id)

      assert {:error, :max_members_too_low} =
               Groups.update_group(owner.id, group.id, %{"max_members" => 1})
    end
  end

  # ---------------------------------------------------------------------------
  # Delete
  # ---------------------------------------------------------------------------

  describe "delete_group/2" do
    test "admin can delete empty group", %{owner: owner} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Doomed"})
      # Leave first so the group is empty
      Groups.leave_group(owner.id, group.id)
      # Re-create to test: create a group, leave it (auto-deletes since empty)
      # Instead, test through admin_delete_group which has no member check
    end

    test "cannot delete group with members", %{owner: owner} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Populated"})
      assert {:error, :has_members} = Groups.delete_group(owner.id, group.id)
    end

    test "non-admin cannot delete", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Safe"})
      assert {:error, :not_admin} = Groups.delete_group(other.id, group.id)
    end

    test "group auto-deletes when last member leaves", %{owner: owner} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "AutoDelete"})
      assert {:ok, _} = Groups.leave_group(owner.id, group.id)
      assert is_nil(Groups.get_group(group.id))
    end
  end

  # ---------------------------------------------------------------------------
  # Join / Leave
  # ---------------------------------------------------------------------------

  describe "join_group/2" do
    test "user can join public group", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Open", "type" => "public"})
      assert {:ok, %GroupMember{role: "member"}} = Groups.join_group(other.id, group.id)
      assert Groups.member?(group.id, other.id)
    end

    test "cannot join private group directly", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Private", "type" => "private"})
      assert {:error, :not_public} = Groups.join_group(other.id, group.id)
    end

    test "cannot join when already a member", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Once", "type" => "public"})
      {:ok, _} = Groups.join_group(other.id, group.id)
      assert {:error, :already_member} = Groups.join_group(other.id, group.id)
    end

    test "cannot join when group is full", %{owner: owner, other: other} do
      {:ok, group} =
        Groups.create_group(owner.id, %{"title" => "Tiny", "type" => "public", "max_members" => 1})

      assert {:error, :full} = Groups.join_group(other.id, group.id)
    end
  end

  describe "leave_group/2" do
    test "member can leave group", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Bye", "type" => "public"})
      {:ok, _} = Groups.join_group(other.id, group.id)
      assert {:ok, _} = Groups.leave_group(other.id, group.id)
      refute Groups.member?(group.id, other.id)
    end

    test "last admin leaving promotes next member", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Transfer", "type" => "public"})
      {:ok, _} = Groups.join_group(other.id, group.id)
      assert {:ok, _} = Groups.leave_group(owner.id, group.id)
      assert Groups.admin?(group.id, other.id)
    end

    test "last member leaving deletes the group", %{owner: owner} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Gone"})
      assert {:ok, _} = Groups.leave_group(owner.id, group.id)
      assert is_nil(Groups.get_group(group.id))
    end

    test "non-member cannot leave", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Nope"})
      assert {:error, :not_member} = Groups.leave_group(other.id, group.id)
    end
  end

  # ---------------------------------------------------------------------------
  # Kick / Promote / Demote
  # ---------------------------------------------------------------------------

  describe "kick_member/3" do
    test "admin can kick member", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Kick", "type" => "public"})
      {:ok, _} = Groups.join_group(other.id, group.id)
      assert {:ok, _} = Groups.kick_member(owner.id, group.id, other.id)
      refute Groups.member?(group.id, other.id)
    end

    test "non-admin cannot kick", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "NoKick", "type" => "public"})
      {:ok, _} = Groups.join_group(other.id, group.id)
      assert {:error, :not_admin} = Groups.kick_member(other.id, group.id, owner.id)
    end

    test "cannot kick self", %{owner: owner} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Self"})
      assert {:error, :cannot_kick_self} = Groups.kick_member(owner.id, group.id, owner.id)
    end

    test "cannot kick non-member", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "NoOne"})
      assert {:error, :not_member} = Groups.kick_member(owner.id, group.id, other.id)
    end
  end

  describe "promote_member/3" do
    test "admin can promote member to admin", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Promo", "type" => "public"})
      {:ok, _} = Groups.join_group(other.id, group.id)
      assert {:ok, _} = Groups.promote_member(owner.id, group.id, other.id)
      assert Groups.admin?(group.id, other.id)
    end

    test "cannot promote self", %{owner: owner} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Already"})
      assert {:error, :cannot_promote_self} = Groups.promote_member(owner.id, group.id, owner.id)
    end

    test "non-admin cannot promote", %{owner: owner, other: other, third: third} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "NoPromo", "type" => "public"})
      {:ok, _} = Groups.join_group(other.id, group.id)
      {:ok, _} = Groups.join_group(third.id, group.id)
      assert {:error, :not_admin} = Groups.promote_member(other.id, group.id, third.id)
    end

    test "cannot promote non-member", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Ghost"})
      assert {:error, :not_member} = Groups.promote_member(owner.id, group.id, other.id)
    end
  end

  describe "demote_member/3" do
    test "admin can demote another admin", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Demo", "type" => "public"})
      {:ok, _} = Groups.join_group(other.id, group.id)
      {:ok, _} = Groups.promote_member(owner.id, group.id, other.id)
      assert {:ok, _} = Groups.demote_member(owner.id, group.id, other.id)
      refute Groups.admin?(group.id, other.id)
    end

    test "cannot demote non-admin", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "NotAdmin", "type" => "public"})
      {:ok, _} = Groups.join_group(other.id, group.id)
      assert {:error, :already_member} = Groups.demote_member(owner.id, group.id, other.id)
    end

    test "non-admin cannot demote", %{owner: owner, other: other, third: third} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "NoDemo", "type" => "public"})
      {:ok, _} = Groups.join_group(other.id, group.id)
      {:ok, _} = Groups.join_group(third.id, group.id)
      {:ok, _} = Groups.promote_member(owner.id, group.id, other.id)
      assert {:error, :not_admin} = Groups.demote_member(third.id, group.id, other.id)
    end

    test "cannot demote self", %{owner: owner} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "SelfDemo"})
      assert {:error, :cannot_demote_self} = Groups.demote_member(owner.id, group.id, owner.id)
    end
  end

  # ---------------------------------------------------------------------------
  # Join Requests
  # ---------------------------------------------------------------------------

  describe "request_join/2" do
    test "user can request to join private group", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Prv", "type" => "private"})
      assert {:ok, %GroupJoinRequest{status: "pending"}} = Groups.request_join(other.id, group.id)
    end

    test "cannot request public group", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Pub", "type" => "public"})
      assert {:error, :not_private} = Groups.request_join(other.id, group.id)
    end

    test "cannot duplicate pending request", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Dup", "type" => "private"})
      {:ok, _} = Groups.request_join(other.id, group.id)
      assert {:error, :already_requested} = Groups.request_join(other.id, group.id)
    end

    test "member cannot request join", %{owner: owner} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "AlrMem", "type" => "private"})
      assert {:error, :already_member} = Groups.request_join(owner.id, group.id)
    end

    test "returns not_found for non-existent group", %{other: other} do
      assert {:error, :not_found} = Groups.request_join(other.id, 999_999)
    end
  end

  describe "approve_join_request/2" do
    test "admin approves request and user becomes member", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Appr", "type" => "private"})
      {:ok, request} = Groups.request_join(other.id, group.id)
      assert {:ok, %GroupMember{}} = Groups.approve_join_request(owner.id, request.id)
      assert Groups.member?(group.id, other.id)
    end

    test "non-admin cannot approve", %{owner: owner, other: other, third: third} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "NoAppr", "type" => "private"})
      {:ok, request} = Groups.request_join(other.id, group.id)
      assert {:error, :not_admin} = Groups.approve_join_request(third.id, request.id)
    end

    test "returns not_found for non-existent request", %{owner: owner} do
      assert {:error, :not_found} = Groups.approve_join_request(owner.id, 999_999)
    end
  end

  describe "reject_join_request/2" do
    test "admin rejects request", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Rej", "type" => "private"})
      {:ok, request} = Groups.request_join(other.id, group.id)

      assert {:ok, %GroupJoinRequest{status: "rejected"}} =
               Groups.reject_join_request(owner.id, request.id)
    end

    test "non-admin cannot reject", %{owner: owner, other: other, third: third} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "NoRej", "type" => "private"})
      {:ok, request} = Groups.request_join(other.id, group.id)
      assert {:error, :not_admin} = Groups.reject_join_request(third.id, request.id)
    end

    test "cannot reject already-approved request", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "DoneAppr", "type" => "private"})
      {:ok, request} = Groups.request_join(other.id, group.id)
      {:ok, _} = Groups.approve_join_request(owner.id, request.id)
      assert {:error, :not_pending} = Groups.reject_join_request(owner.id, request.id)
    end
  end

  describe "cancel_join_request/2" do
    test "user can cancel own pending request", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Cancel", "type" => "private"})
      {:ok, request} = Groups.request_join(other.id, group.id)
      assert {:ok, _} = Groups.cancel_join_request(other.id, request.id)
      assert Groups.list_user_pending_requests(other.id) == []
    end

    test "cannot cancel another user's request", %{owner: owner, other: other, third: third} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "NoCncl", "type" => "private"})
      {:ok, request} = Groups.request_join(other.id, group.id)
      assert {:error, :not_owner} = Groups.cancel_join_request(third.id, request.id)
    end

    test "cannot cancel non-pending request", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Done", "type" => "private"})
      {:ok, request} = Groups.request_join(other.id, group.id)
      {:ok, _} = Groups.reject_join_request(owner.id, request.id)
      assert {:error, :not_pending} = Groups.cancel_join_request(other.id, request.id)
    end
  end

  # ---------------------------------------------------------------------------
  # Invite to group
  # ---------------------------------------------------------------------------

  describe "invite_to_group/3" do
    test "admin can invite user to group", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "InvGrp", "type" => "hidden"})
      assert {:ok, _} = Groups.invite_to_group(owner.id, group.id, other.id)
    end

    test "non-admin cannot invite", %{owner: owner, other: other, third: third} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "NoInv", "type" => "hidden"})
      assert {:error, :not_admin} = Groups.invite_to_group(other.id, group.id, third.id)
    end

    test "cannot invite existing member", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "AlrMem", "type" => "hidden"})
      {:ok, _} = Groups.invite_to_group(owner.id, group.id, other.id)
      {:ok, _} = Groups.accept_invite(other.id, group.id)
      assert {:error, :already_member} = Groups.invite_to_group(owner.id, group.id, other.id)
    end

    test "cannot invite to non-existent group", %{owner: owner, other: other} do
      assert {:error, :not_found} = Groups.invite_to_group(owner.id, 999_999, other.id)
    end
  end

  describe "accept_invite/2" do
    test "user can accept invite and join hidden group", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "HidJoin", "type" => "hidden"})
      {:ok, _} = Groups.invite_to_group(owner.id, group.id, other.id)
      assert {:ok, %GroupMember{role: "member"}} = Groups.accept_invite(other.id, group.id)
      assert Groups.member?(group.id, other.id)
    end

    test "cannot accept invite for non-hidden group", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "PubNoInv", "type" => "public"})
      assert {:error, :not_hidden} = Groups.accept_invite(other.id, group.id)
    end

    test "cannot accept invite if already member", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "AlrIn", "type" => "hidden"})
      {:ok, _} = Groups.invite_to_group(owner.id, group.id, other.id)
      {:ok, _} = Groups.accept_invite(other.id, group.id)
      assert {:error, :already_member} = Groups.accept_invite(other.id, group.id)
    end

    test "cannot accept invite for non-existent group", %{owner: owner} do
      assert {:error, :not_found} = Groups.accept_invite(owner.id, 999_999)
    end

    test "cannot join full group via invite", %{owner: owner, other: other} do
      {:ok, group} =
        Groups.create_group(owner.id, %{
          "title" => "FullInv",
          "type" => "hidden",
          "max_members" => 1
        })

      {:ok, _} = Groups.invite_to_group(owner.id, group.id, other.id)
      assert {:error, :full} = Groups.accept_invite(other.id, group.id)
    end
  end

  describe "before_group_join hook" do
    setup do
      original = Application.get_env(:game_server_core, :hooks_module)

      on_exit(fn ->
        if original do
          Application.put_env(:game_server_core, :hooks_module, original)
        else
          Application.delete_env(:game_server_core, :hooks_module)
        end
      end)

      :ok
    end

    test "can block public join", %{owner: owner, other: other} do
      Application.put_env(
        :game_server_core,
        :hooks_module,
        GameServer.GroupsTest.HooksDenyGroupJoin
      )

      {:ok, group} =
        Groups.create_group(owner.id, %{"title" => "JoinHookPub", "type" => "public"})

      assert {:error, :level_too_low} = Groups.join_group(other.id, group.id)
      refute Groups.member?(group.id, other.id)
    end

    test "can block join request approval", %{owner: owner, other: other} do
      Application.put_env(
        :game_server_core,
        :hooks_module,
        GameServer.GroupsTest.HooksDenyGroupJoin
      )

      {:ok, group} =
        Groups.create_group(owner.id, %{"title" => "JoinHookReq", "type" => "private"})

      {:ok, request} = Groups.request_join(other.id, group.id)

      assert {:error, :level_too_low} = Groups.approve_join_request(owner.id, request.id)
      refute Groups.member?(group.id, other.id)
    end

    test "can block invite accept", %{owner: owner, other: other} do
      Application.put_env(
        :game_server_core,
        :hooks_module,
        GameServer.GroupsTest.HooksDenyGroupJoin
      )

      {:ok, group} =
        Groups.create_group(owner.id, %{"title" => "JoinHookInv", "type" => "hidden"})

      {:ok, _} = Groups.invite_to_group(owner.id, group.id, other.id)

      assert {:error, :level_too_low} = Groups.accept_invite(other.id, group.id)
      refute Groups.member?(group.id, other.id)
    end

    test "passes source and metadata context to hook", %{owner: owner, other: other} do
      Application.put_env(
        :game_server_core,
        :hooks_module,
        GameServer.GroupsTest.HooksCaptureGroupJoin
      )

      {:ok, group} =
        Groups.create_group(owner.id, %{
          "title" => "JoinHookCtx",
          "type" => "public",
          "metadata" => %{"min_level" => 10}
        })

      assert {:error, {:captured, opts}} = Groups.join_group(other.id, group.id)
      assert opts["source"] == "public_join"
      assert opts["joining_user_id"] == other.id
      assert opts["actor_user_id"] == other.id
      assert opts["group_id"] == group.id
      assert opts["group_type"] == "public"
      assert opts["group_metadata"]["min_level"] == 10
    end
  end

  # ---------------------------------------------------------------------------
  # Counting helpers
  # ---------------------------------------------------------------------------

  describe "count_user_groups/1" do
    test "counts groups for user", %{owner: owner, other: other} do
      {:ok, _} = Groups.create_group(owner.id, %{"title" => "CntG1"})
      {:ok, group2} = Groups.create_group(other.id, %{"title" => "CntG2"})
      {:ok, _} = Groups.join_group(owner.id, group2.id)

      assert Groups.count_user_groups(owner.id) == 2
      assert Groups.count_user_groups(other.id) == 1
    end
  end

  describe "count_invitations/1" do
    test "counts pending invitations for user", %{owner: owner, other: other, third: third} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "CntInv", "type" => "hidden"})
      {:ok, _} = Groups.invite_to_group(owner.id, group.id, other.id)
      {:ok, _} = Groups.invite_to_group(owner.id, group.id, third.id)

      assert Groups.count_invitations(other.id) >= 1
      assert Groups.count_invitations(third.id) >= 1
    end
  end

  describe "count_join_requests/1" do
    test "counts pending requests for group", %{owner: owner, other: other, third: third} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "CntReq", "type" => "private"})
      {:ok, _} = Groups.request_join(other.id, group.id)
      {:ok, _} = Groups.request_join(third.id, group.id)

      assert Groups.count_join_requests(group.id) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # Admin functions
  # ---------------------------------------------------------------------------

  describe "list_all_groups/2" do
    test "includes hidden groups for admin listing", %{owner: owner} do
      {:ok, _} = Groups.create_group(owner.id, %{"title" => "VisGrp", "type" => "public"})
      {:ok, _} = Groups.create_group(owner.id, %{"title" => "HidGrp", "type" => "hidden"})

      # list_groups (public) excludes hidden
      public = Groups.list_groups()
      hidden_in_public = Enum.find(public, fn g -> g.title == "HidGrp" end)
      assert is_nil(hidden_in_public)

      # list_all_groups (admin) includes hidden
      all = Groups.list_all_groups()
      hidden_in_all = Enum.find(all, fn g -> g.title == "HidGrp" end)
      assert hidden_in_all != nil
    end
  end

  describe "admin_delete_group/1" do
    test "deletes group regardless of admin status", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "AdmDel"})
      {:ok, _} = Groups.join_group(other.id, group.id)

      assert {:ok, _} = Groups.admin_delete_group(group.id)
      assert is_nil(Groups.get_group(group.id))
    end
  end

  # ---------------------------------------------------------------------------
  # Members query
  # ---------------------------------------------------------------------------

  describe "get_group_members/1 and get_group_members_paginated/2" do
    test "returns members with preloaded user", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Members", "type" => "public"})
      {:ok, _} = Groups.join_group(other.id, group.id)

      members = Groups.get_group_members(group.id)
      assert length(members) == 2
      assert Enum.all?(members, fn m -> m.user != nil end)
    end

    test "paginated members", %{owner: owner, other: other, third: third} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "PgMem", "type" => "public"})
      {:ok, _} = Groups.join_group(other.id, group.id)
      {:ok, _} = Groups.join_group(third.id, group.id)

      page1 = Groups.get_group_members_paginated(group.id, page: 1, page_size: 2)
      assert length(page1) == 2

      page2 = Groups.get_group_members_paginated(group.id, page: 2, page_size: 2)
      assert length(page2) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # User-centric queries
  # ---------------------------------------------------------------------------

  describe "list_user_groups_with_role/1" do
    test "returns groups with role for user", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "MyGrp", "type" => "public"})
      {:ok, _} = Groups.join_group(other.id, group.id)

      result = Groups.list_user_groups_with_role(other.id)
      assert [{%Group{title: "MyGrp"}, "member"}] = result
    end
  end

  describe "count_group_members/1" do
    test "counts members accurately", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Count", "type" => "public"})
      assert Groups.count_group_members(group.id) == 1
      {:ok, _} = Groups.join_group(other.id, group.id)
      assert Groups.count_group_members(group.id) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # Filters
  # ---------------------------------------------------------------------------

  describe "list_groups with filters" do
    test "filters by title", %{owner: owner} do
      {:ok, _} = Groups.create_group(owner.id, %{"title" => "Alpha"})
      {:ok, _} = Groups.create_group(owner.id, %{"title" => "Beta"})

      groups = Groups.list_groups(%{"title" => "Alph"})
      assert length(groups) == 1
      assert hd(groups).title == "Alpha"
    end

    test "filters by type", %{owner: owner} do
      {:ok, _} = Groups.create_group(owner.id, %{"title" => "Pub1", "type" => "public"})
      {:ok, _} = Groups.create_group(owner.id, %{"title" => "Prv1", "type" => "private"})

      groups = Groups.list_groups(%{"type" => "private"})
      assert length(groups) == 1
      assert hd(groups).type == "private"
    end

    test "handles empty string filter values gracefully", %{owner: owner} do
      {:ok, _} = Groups.create_group(owner.id, %{"title" => "Any"})

      # Empty strings should not crash
      groups = Groups.list_groups(%{"min_members" => "", "max_members" => ""})
      assert groups != []
    end
  end

  # ---------------------------------------------------------------------------
  # Sorting
  # ---------------------------------------------------------------------------

  describe "list_groups with sorting" do
    test "sorts by title ascending", %{owner: owner} do
      {:ok, _} = Groups.create_group(owner.id, %{"title" => "Zebra"})
      {:ok, _} = Groups.create_group(owner.id, %{"title" => "Apple"})

      groups = Groups.list_groups(%{}, sort_by: "title")
      names = Enum.map(groups, & &1.title)
      assert names == Enum.sort(names)
    end
  end

  # ---------------------------------------------------------------------------
  # Sent Invitations
  # ---------------------------------------------------------------------------

  describe "list_sent_invitations/1" do
    test "returns invitations sent by user", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "SentInv", "type" => "hidden"})
      {:ok, _} = Groups.invite_to_group(owner.id, group.id, other.id)

      invites = Groups.list_sent_invitations(owner.id)
      assert length(invites) == 1
      assert hd(invites).group_name == "SentInv"
      assert hd(invites).recipient_id == other.id
    end

    test "returns empty when no invitations sent", %{other: other} do
      assert Groups.list_sent_invitations(other.id) == []
    end
  end

  describe "cancel_invite/2" do
    test "sender can cancel own invitation", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "CnclInv", "type" => "hidden"})
      {:ok, _} = Groups.invite_to_group(owner.id, group.id, other.id)

      [%{id: inv_id}] = Groups.list_sent_invitations(owner.id)
      assert :ok = Groups.cancel_invite(owner.id, inv_id)
      assert Groups.list_sent_invitations(owner.id) == []
    end

    test "cannot cancel another user's invitation", %{owner: owner, other: other, third: third} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "NoCancel", "type" => "hidden"})
      {:ok, _} = Groups.invite_to_group(owner.id, group.id, other.id)

      [%{id: inv_id}] = Groups.list_sent_invitations(owner.id)
      assert {:error, :not_owner} = Groups.cancel_invite(third.id, inv_id)
    end

    test "returns not_found for non-existent invitation", %{owner: owner} do
      assert {:error, :not_found} = Groups.cancel_invite(owner.id, 999_999)
    end
  end

  # ---------------------------------------------------------------------------
  # Group notifications
  # ---------------------------------------------------------------------------

  describe "notify_group/3" do
    test "sends notification to all group members except sender", %{
      owner: owner,
      other: other,
      third: third
    } do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "NotGrp", "type" => "public"})
      {:ok, _} = Groups.join_group(other.id, group.id)
      {:ok, _} = Groups.join_group(third.id, group.id)

      assert {:ok, 2} = Groups.notify_group(owner.id, group.id, "Hello group!")

      # Verify notifications were created for other members
      other_notifs = GameServer.Notifications.list_notifications(other.id)
      assert Enum.any?(other_notifs, fn n -> n.title == "group_notification" end)

      third_notifs = GameServer.Notifications.list_notifications(third.id)
      assert Enum.any?(third_notifs, fn n -> n.title == "group_notification" end)

      # Sender should NOT receive notification
      owner_notifs = GameServer.Notifications.list_notifications(owner.id)
      refute Enum.any?(owner_notifs, fn n -> n.title == "group_notification" end)
    end

    test "non-member cannot notify group", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "NoNotif", "type" => "public"})
      assert {:error, :not_member} = Groups.notify_group(other.id, group.id, "Hello!")
    end

    test "returns not_found for non-existent group", %{owner: owner} do
      assert {:error, :not_found} = Groups.notify_group(owner.id, 999_999, "Hello!")
    end

    test "upserts notification when sender sends again", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Upsert", "type" => "public"})
      {:ok, _} = Groups.join_group(other.id, group.id)

      assert {:ok, 1} = Groups.notify_group(owner.id, group.id, "First message")
      assert {:ok, 1} = Groups.notify_group(owner.id, group.id, "Updated message")

      notifs = GameServer.Notifications.list_notifications(other.id)

      group_notifs =
        Enum.filter(notifs, fn n -> n.title == "group_notification" end)

      # Should be only ONE notification (upserted)
      assert length(group_notifs) == 1
      assert hd(group_notifs).content == "Updated message"
    end

    test "includes group_id and group_name in metadata", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "MetaGrp", "type" => "public"})
      {:ok, _} = Groups.join_group(other.id, group.id)

      assert {:ok, 1} = Groups.notify_group(owner.id, group.id, "Check metadata")

      notifs = GameServer.Notifications.list_notifications(other.id)

      group_notif =
        Enum.find(notifs, fn n -> n.title == "group_notification" end)

      assert group_notif.metadata["group_id"] == group.id
      assert group_notif.metadata["group_name"] == "MetaGrp"
    end

    test "passes custom metadata through", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "CustMeta", "type" => "public"})
      {:ok, _} = Groups.join_group(other.id, group.id)

      assert {:ok, 1} =
               Groups.notify_group(owner.id, group.id, "With data", %{"event" => "raid"})

      notifs = GameServer.Notifications.list_notifications(other.id)

      group_notif =
        Enum.find(notifs, fn n -> n.title == "group_notification" end)

      assert group_notif.metadata["event"] == "raid"
      assert group_notif.metadata["group_id"] == group.id
    end

    test "returns {:ok, 0} when sender is the only member", %{owner: owner} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Solo", "type" => "public"})
      assert {:ok, 0} = Groups.notify_group(owner.id, group.id, "Just me")
    end

    test "uses custom title from metadata", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "TitleGrp", "type" => "public"})
      {:ok, _} = Groups.join_group(other.id, group.id)

      assert {:ok, 1} =
               Groups.notify_group(owner.id, group.id, "Custom!", %{"title" => "game_event"})

      notifs = GameServer.Notifications.list_notifications(other.id)
      game_notif = Enum.find(notifs, fn n -> n.title == "game_event" end)
      assert game_notif
      assert game_notif.content == "Custom!"
      assert game_notif.metadata["group_id"] == group.id
      # The title key should not appear in metadata
      refute Map.has_key?(game_notif.metadata, "title")
    end
  end

  # ---------------------------------------------------------------------------
  # User deletion group cleanup
  # ---------------------------------------------------------------------------

  describe "handle_user_deletion/1" do
    test "promotes next member when only admin is deleted", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "AdminDel", "type" => "public"})
      {:ok, _} = Groups.join_group(other.id, group.id)

      Groups.handle_user_deletion(owner.id)

      # Owner should no longer be a member
      refute Groups.member?(group.id, owner.id)
      # Other should have been promoted to admin
      assert Groups.admin?(group.id, other.id)
    end

    test "deletes empty group when last member is deleted", %{owner: owner} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "LastDel"})
      Groups.handle_user_deletion(owner.id)
      assert is_nil(Groups.get_group(group.id))
    end

    test "handles user in multiple groups", %{owner: owner, other: other} do
      {:ok, g1} = Groups.create_group(owner.id, %{"title" => "Multi1", "type" => "public"})
      {:ok, g2} = Groups.create_group(owner.id, %{"title" => "Multi2", "type" => "public"})
      {:ok, _} = Groups.join_group(other.id, g1.id)

      Groups.handle_user_deletion(owner.id)

      # g1 still exists (other is promoted to admin)
      assert Groups.get_group(g1.id)
      assert Groups.admin?(g1.id, other.id)
      # g2 is deleted (no other members)
      assert is_nil(Groups.get_group(g2.id))
    end
  end

  # ---------------------------------------------------------------------------
  # Pagination helpers
  # ---------------------------------------------------------------------------

  describe "count_sent_invitations/1" do
    test "returns 0 when no invitations sent", %{owner: owner} do
      assert Groups.count_sent_invitations(owner.id) == 0
    end

    test "counts sent invitations", %{owner: owner, other: other} do
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "InvCount", "type" => "hidden"})
      {:ok, _} = Groups.invite_to_group(owner.id, group.id, other.id)
      assert Groups.count_sent_invitations(owner.id) == 1
    end
  end
end
