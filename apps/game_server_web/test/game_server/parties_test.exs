defmodule GameServer.PartiesTest.HooksAllowPartyCreate do
  def before_party_create(_user, attrs), do: {:ok, attrs}
end

defmodule GameServer.PartiesTest.HooksDenyPartyCreate do
  def before_party_create(_user, _attrs), do: {:error, :party_creation_blocked}
end

defmodule GameServer.PartiesTest.HooksModifyPartyCreate do
  def before_party_create(_user, attrs) do
    {:ok, Map.put(attrs, "max_size", 3)}
  end
end

defmodule GameServer.PartiesTest.HooksAllowPartyUpdate do
  def before_party_update(_party, attrs), do: {:ok, attrs}
end

defmodule GameServer.PartiesTest.HooksDenyPartyUpdate do
  def before_party_update(_party, _attrs), do: {:error, :party_update_blocked}
end

defmodule GameServer.PartiesTest.HooksModifyPartyUpdate do
  def before_party_update(_party, attrs) do
    {:ok, Map.put(attrs, "max_size", 5)}
  end
end

defmodule GameServer.PartiesTest do
  use GameServer.DataCase

  alias GameServer.Accounts
  alias GameServer.AccountsFixtures
  alias GameServer.Friends
  alias GameServer.Lobbies
  alias GameServer.Parties

  setup do
    leader = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
    member1 = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
    member2 = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

    %{leader: leader, member1: member1, member2: member2}
  end

  # Directly sets the party_id on a user (test setup helper only).
  defp add_member_to_party(user, party) do
    user
    |> Ecto.Changeset.change(%{party_id: party.id})
    |> GameServer.Repo.update!()
  end

  # Sets all given users as online (required for party lobby operations).
  defp set_all_online(users) do
    Enum.each(users, &Accounts.set_user_online/1)
  end

  # Creates a mutual friendship for invite eligibility.
  defp make_friends(user_a, user_b) do
    {:ok, req} = Friends.create_request(user_a, user_b.id)
    Friends.accept_friend_request(req.id, user_b)
  end

  describe "create_party/2" do
    test "creates a party and sets user as leader and member", %{leader: leader} do
      assert {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      assert party.leader_id == leader.id
      assert party.max_size == 4

      # Leader should now have party_id set
      updated_leader = Accounts.get_user(leader.id)
      assert updated_leader.party_id == party.id
    end

    test "cannot create party while already in a party", %{leader: leader} do
      {:ok, _party} = Parties.create_party(leader, %{})

      assert {:error, :already_in_party} = Parties.create_party(leader, %{})
    end

    test "uses default max_size when not specified", %{leader: leader} do
      assert {:ok, party} = Parties.create_party(leader)
      assert party.max_size == 4
    end
  end

  describe "invite_to_party/2" do
    test "leader can invite a friend", %{leader: leader, member1: member1} do
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})
      make_friends(leader, member1)

      assert {:ok, _notification} = Parties.invite_to_party(leader, member1.id)
    end

    test "leader can invite a shared group member", %{leader: leader, member1: member1} do
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})

      {:ok, group} =
        GameServer.Groups.create_group(leader.id, %{"title" => "g", "type" => "public"})

      {:ok, _} = GameServer.Groups.join_group(member1.id, group.id)

      assert {:ok, _notification} = Parties.invite_to_party(leader, member1.id)
    end

    test "fails when caller is not the leader", %{
      leader: leader,
      member1: member1,
      member2: member2
    } do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      add_member_to_party(member1, party)
      make_friends(member1, member2)

      assert {:error, :not_leader} = Parties.invite_to_party(member1, member2.id)
    end

    test "fails when target is not a friend or group member", %{leader: leader, member1: member1} do
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})

      assert {:error, :not_connected} = Parties.invite_to_party(leader, member1.id)
    end

    test "succeeds when target is already in a party", %{leader: leader, member1: member1} do
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})
      {:ok, _other} = Parties.create_party(member1, %{})
      make_friends(leader, member1)

      assert {:ok, _invite} = Parties.invite_to_party(leader, member1.id)
    end

    test "fails when invite already pending", %{leader: leader, member1: member1} do
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})
      make_friends(leader, member1)

      assert {:ok, _} = Parties.invite_to_party(leader, member1.id)
      assert {:error, :already_invited} = Parties.invite_to_party(leader, member1.id)
    end

    test "stores sender_name and recipient_name in notification metadata", %{
      leader: leader,
      member1: member1
    } do
      {:ok, _} =
        GameServer.Accounts.update_user_display_name(leader, %{"display_name" => "LeaderDisplay"})

      {:ok, _} =
        GameServer.Accounts.update_user_display_name(member1, %{
          "display_name" => "Member1Display"
        })

      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})
      make_friends(leader, member1)
      {:ok, invite} = Parties.invite_to_party(leader, member1.id)

      # invite_to_party now returns a PartyInvite record
      assert invite.sender_id == leader.id
      assert invite.recipient_id == member1.id
      assert invite.status == "pending"

      # Verify the informational notification was also created with metadata
      [notification] = GameServer.Notifications.list_notifications(member1.id)
      assert notification.metadata["sender_name"] == "LeaderDisplay"
      assert notification.metadata["recipient_name"] == "Member1Display"
    end
  end

  describe "accept_party_invite/2" do
    test "user can accept a valid invite and joins the party", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      make_friends(leader, member1)
      {:ok, _} = Parties.invite_to_party(leader, member1.id)

      assert {:ok, joined_party} = Parties.accept_party_invite(member1, party.id)
      assert joined_party.id == party.id

      updated = Accounts.get_user(member1.id)
      assert updated.party_id == party.id
    end

    test "invite notification is removed after accept", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      make_friends(leader, member1)
      {:ok, _} = Parties.invite_to_party(leader, member1.id)

      {:ok, _} = Parties.accept_party_invite(member1, party.id)

      invites = Parties.list_party_invitations(member1)
      assert invites == []
    end

    test "fails when no invite exists", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})

      assert {:error, :no_invite} = Parties.accept_party_invite(member1, party.id)
    end

    test "auto-leaves current party when accepting another invite", %{
      leader: leader,
      member1: member1,
      member2: _member2
    } do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      make_friends(leader, member1)
      # Send invite while member1 is not yet in a party
      {:ok, _} = Parties.invite_to_party(leader, member1.id)
      # Now put member1 into their own party (directly, to simulate concurrent join)
      {:ok, other_party} = Parties.create_party(member1, %{})

      # Accept should auto-leave the other party and join the new one
      assert {:ok, joined_party} = Parties.accept_party_invite(member1, party.id)
      assert joined_party.id == party.id

      # The old party should be disbanded (member1 was leader)
      assert is_nil(Parties.get_party(other_party.id))
    end

    test "fails when party is full", %{leader: leader, member1: member1, member2: member2} do
      {:ok, party} = Parties.create_party(leader, %{max_size: 2})
      add_member_to_party(member1, party)
      make_friends(leader, member2)
      {:ok, _} = Parties.invite_to_party(leader, member2.id)

      assert {:error, :party_full} = Parties.accept_party_invite(member2, party.id)
    end
  end

  describe "decline_party_invite/2" do
    test "removes the invite notification", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      make_friends(leader, member1)
      {:ok, _} = Parties.invite_to_party(leader, member1.id)

      assert :ok = Parties.decline_party_invite(member1, party.id)

      invites = Parties.list_party_invitations(member1)
      assert invites == []
    end

    test "is idempotent with no invite", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})

      assert :ok = Parties.decline_party_invite(member1, party.id)
    end
  end

  describe "cancel_party_invite/2" do
    test "leader can cancel a pending invite", %{leader: leader, member1: member1} do
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})
      make_friends(leader, member1)
      {:ok, _} = Parties.invite_to_party(leader, member1.id)

      assert :ok = Parties.cancel_party_invite(leader, member1.id)

      invites = Parties.list_party_invitations(member1)
      assert invites == []
    end

    test "fails when caller is not the leader", %{
      leader: leader,
      member1: member1,
      member2: member2
    } do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      add_member_to_party(member1, party)
      make_friends(leader, member2)
      {:ok, _} = Parties.invite_to_party(leader, member2.id)

      assert {:error, :not_leader} = Parties.cancel_party_invite(member1, member2.id)
    end
  end

  describe "list_party_invitations/1" do
    test "returns pending invites for user", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      make_friends(leader, member1)
      {:ok, _} = Parties.invite_to_party(leader, member1.id)

      invites = Parties.list_party_invitations(member1)
      assert length(invites) == 1
      assert hd(invites).party_id == party.id
      assert hd(invites).sender_id == leader.id
    end

    test "includes sender_name and recipient_name", %{leader: leader, member1: member1} do
      {:ok, _} =
        GameServer.Accounts.update_user_display_name(leader, %{"display_name" => "InvLeader"})

      {:ok, _} =
        GameServer.Accounts.update_user_display_name(member1, %{"display_name" => "InvMember"})

      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})
      make_friends(leader, member1)
      {:ok, _} = Parties.invite_to_party(leader, member1.id)

      invites = Parties.list_party_invitations(member1)
      assert length(invites) == 1
      invite = hd(invites)
      assert invite.sender_name == "InvLeader"
      assert invite.recipient_name == "InvMember"
    end

    test "returns empty list with no invites", %{member1: member1} do
      assert Parties.list_party_invitations(member1) == []
    end
  end

  describe "leave_party/1" do
    test "leader leaving disbands the party", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{})
      add_member_to_party(member1, party)

      assert {:ok, :disbanded} = Parties.leave_party(leader)

      # Party should no longer exist
      assert is_nil(Parties.get_party(party.id))

      # Both users should have no party
      assert is_nil(Accounts.get_user(leader.id).party_id)
      assert is_nil(Accounts.get_user(member1.id).party_id)
    end

    test "regular member leaving does not disband the party", %{
      leader: leader,
      member1: member1
    } do
      {:ok, party} = Parties.create_party(leader, %{})
      add_member_to_party(member1, party)

      assert {:ok, :left} = Parties.leave_party(member1)

      # Party should still exist
      assert Parties.get_party(party.id) != nil

      # Only the member should have been removed
      assert is_nil(Accounts.get_user(member1.id).party_id)
      assert Accounts.get_user(leader.id).party_id == party.id
    end

    test "returns error when not in a party", %{member1: member1} do
      assert {:error, :not_in_party} = Parties.leave_party(member1)
    end
  end

  describe "kick_member/2" do
    test "leader can kick a member", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{})
      add_member_to_party(member1, party)

      assert {:ok, _} = Parties.kick_member(leader, member1.id)

      assert is_nil(Accounts.get_user(member1.id).party_id)
      assert Parties.get_party(party.id) != nil
    end

    test "non-leader cannot kick", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{})
      add_member_to_party(member1, party)

      assert {:error, :not_leader} = Parties.kick_member(member1, leader.id)
    end

    test "cannot kick self", %{leader: leader} do
      {:ok, _party} = Parties.create_party(leader, %{})

      assert {:error, :cannot_kick_self} = Parties.kick_member(leader, leader.id)
    end
  end

  describe "update_party/2" do
    test "leader can update party settings", %{leader: leader} do
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})

      assert {:ok, updated} = Parties.update_party(leader, %{max_size: 8})
      assert updated.max_size == 8
    end

    test "cannot reduce max_size below current member count", %{
      leader: leader,
      member1: member1
    } do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      add_member_to_party(member1, party)

      # 2 members, can't set to 1
      assert {:error, :too_small} = Parties.update_party(leader, %{max_size: 1})
    end

    test "non-leader cannot update", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{})
      add_member_to_party(member1, party)

      assert {:error, :not_leader} = Parties.update_party(member1, %{max_size: 8})
    end
  end

  describe "create_lobby_with_party/2" do
    test "leader creates lobby and all members join, party stays intact", %{
      leader: leader,
      member1: member1
    } do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      add_member_to_party(member1, party)
      set_all_online([leader, member1])

      assert {:ok, lobby} =
               Parties.create_lobby_with_party(leader, %{title: "party-lobby", max_users: 8})

      assert lobby.title == "party-lobby"

      # Party should still exist
      assert Parties.get_party(party.id) != nil

      # Both users should be in the lobby
      assert Accounts.get_user(leader.id).lobby_id == lobby.id
      assert Accounts.get_user(member1.id).lobby_id == lobby.id

      # Both should still be in the party
      assert Accounts.get_user(leader.id).party_id == party.id
      assert Accounts.get_user(member1.id).party_id == party.id
    end

    test "fails if lobby max_users is too small for party", %{
      leader: leader,
      member1: member1,
      member2: member2
    } do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      add_member_to_party(member1, party)
      add_member_to_party(member2, party)
      set_all_online([leader, member1, member2])

      # 3 members but max_users = 2
      assert {:error, :lobby_too_small_for_party} =
               Parties.create_lobby_with_party(leader, %{title: "tiny", max_users: 2})
    end

    test "non-leader cannot create lobby with party", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{})
      add_member_to_party(member1, party)
      set_all_online([leader, member1])

      assert {:error, :not_leader} = Parties.create_lobby_with_party(member1, %{title: "nope"})
    end

    test "fails if any party member is already in a lobby", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      add_member_to_party(member1, party)
      set_all_online([leader, member1])

      # Put member1 in a lobby
      host = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
      {:ok, lobby} = Lobbies.create_lobby(%{title: "existing", host_id: host.id})
      Lobbies.join_lobby(member1, lobby.id)

      assert {:error, :member_in_lobby} =
               Parties.create_lobby_with_party(leader, %{title: "party-lobby", max_users: 8})
    end
  end

  describe "join_lobby_with_party/3" do
    test "leader joins existing lobby and all members join, party stays intact", %{
      leader: leader,
      member1: member1
    } do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      add_member_to_party(member1, party)
      set_all_online([leader, member1])

      # Create a lobby with a different host
      host = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
      {:ok, lobby} = Lobbies.create_lobby(%{title: "existing-lobby", host_id: host.id})

      assert {:ok, joined_lobby} = Parties.join_lobby_with_party(leader, lobby.id)
      assert joined_lobby.id == lobby.id

      # Party should still exist
      assert Parties.get_party(party.id) != nil

      # All users should be in the lobby
      assert Accounts.get_user(leader.id).lobby_id == lobby.id
      assert Accounts.get_user(member1.id).lobby_id == lobby.id

      # All users should still be in the party
      assert Accounts.get_user(leader.id).party_id == party.id
      assert Accounts.get_user(member1.id).party_id == party.id
    end

    test "fails if lobby doesn't have enough space", %{
      leader: leader,
      member1: member1,
      member2: member2
    } do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      add_member_to_party(member1, party)
      add_member_to_party(member2, party)
      set_all_online([leader, member1, member2])

      # Create a lobby with max 3 users and 1 already in it (the host)
      host = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
      {:ok, lobby} = Lobbies.create_lobby(%{title: "small-lobby", host_id: host.id, max_users: 3})

      # 3 party members + 1 existing host = 4, but max is 3
      assert {:error, :not_enough_space} = Parties.join_lobby_with_party(leader, lobby.id)
    end

    test "fails if lobby is locked", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{})
      add_member_to_party(member1, party)
      set_all_online([leader, member1])

      host = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

      {:ok, lobby} =
        Lobbies.create_lobby(%{title: "locked-lobby", host_id: host.id, is_locked: true})

      assert {:error, :locked} = Parties.join_lobby_with_party(leader, lobby.id)
    end

    test "fails if lobby requires password and no password given", %{
      leader: leader,
      member1: member1
    } do
      {:ok, party} = Parties.create_party(leader, %{})
      add_member_to_party(member1, party)
      set_all_online([leader, member1])

      host = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
      phash = Bcrypt.hash_pwd_salt("secret")

      {:ok, lobby} =
        Lobbies.create_lobby(%{
          title: "pw-lobby",
          host_id: host.id,
          password_hash: phash,
          max_users: 8
        })

      assert {:error, :password_required} = Parties.join_lobby_with_party(leader, lobby.id)
    end

    test "succeeds with correct password", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{})
      add_member_to_party(member1, party)
      set_all_online([leader, member1])

      host = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
      phash = Bcrypt.hash_pwd_salt("secret")

      {:ok, lobby} =
        Lobbies.create_lobby(%{
          title: "pw-lobby",
          host_id: host.id,
          password_hash: phash,
          max_users: 8
        })

      assert {:ok, _} = Parties.join_lobby_with_party(leader, lobby.id, %{password: "secret"})
    end

    test "non-leader cannot join lobby with party", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{})
      add_member_to_party(member1, party)
      set_all_online([leader, member1])

      host = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
      {:ok, lobby} = Lobbies.create_lobby(%{title: "test-lobby", host_id: host.id})

      assert {:error, :not_leader} = Parties.join_lobby_with_party(member1, lobby.id)
    end

    test "cannot join non-existent lobby with party", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{})
      add_member_to_party(member1, party)
      set_all_online([leader, member1])

      assert {:error, :invalid_lobby} = Parties.join_lobby_with_party(leader, 999_999)
    end

    test "fails with wrong password", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{})
      add_member_to_party(member1, party)
      set_all_online([leader, member1])

      host = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
      phash = Bcrypt.hash_pwd_salt("secret")

      {:ok, lobby} =
        Lobbies.create_lobby(%{
          title: "pw-lobby",
          host_id: host.id,
          password_hash: phash,
          max_users: 8
        })

      assert {:error, :invalid_password} =
               Parties.join_lobby_with_party(leader, lobby.id, %{password: "wrong"})

      # Party should still exist after failed join
      updated_leader = Accounts.get_user(leader.id)
      assert updated_leader.party_id != nil
      assert is_nil(updated_leader.lobby_id)
    end

    test "fails if any party member is already in a lobby", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      add_member_to_party(member1, party)
      set_all_online([leader, member1])

      # Put member1 in a lobby
      host = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
      {:ok, existing_lobby} = Lobbies.create_lobby(%{title: "existing", host_id: host.id})
      Lobbies.join_lobby(member1, existing_lobby.id)

      # Create a target lobby to try to join
      host2 = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
      {:ok, target_lobby} = Lobbies.create_lobby(%{title: "target", host_id: host2.id})

      assert {:error, :member_in_lobby} = Parties.join_lobby_with_party(leader, target_lobby.id)
    end
  end

  describe "atomicity of lobby operations" do
    test "create_lobby_with_party: party stays intact and all members are in lobby", %{
      leader: leader,
      member1: member1,
      member2: member2
    } do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      add_member_to_party(member1, party)
      add_member_to_party(member2, party)
      set_all_online([leader, member1, member2])

      {:ok, lobby} =
        Parties.create_lobby_with_party(leader, %{title: "atomic-lobby", max_users: 8})

      # All 3 users should be in the lobby and still in the party
      for user <- [leader, member1, member2] do
        u = Accounts.get_user(user.id)
        assert u.lobby_id == lobby.id, "User #{user.id} should be in the lobby"
        assert u.party_id == party.id, "User #{user.id} should still be in the party"
      end

      # Party should still exist
      assert Parties.get_party(party.id) != nil

      # Lobby should have 3 members
      members_in_lobby =
        GameServer.Repo.all(
          Ecto.Query.from(u in GameServer.Accounts.User,
            where: u.lobby_id == ^lobby.id
          )
        )

      assert length(members_in_lobby) == 3
    end

    test "join_lobby_with_party: party stays intact and all members are in lobby", %{
      leader: leader,
      member1: member1,
      member2: member2
    } do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      add_member_to_party(member1, party)
      add_member_to_party(member2, party)
      set_all_online([leader, member1, member2])

      host = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
      {:ok, lobby} = Lobbies.create_lobby(%{title: "existing", host_id: host.id, max_users: 10})

      {:ok, joined_lobby} = Parties.join_lobby_with_party(leader, lobby.id)
      assert joined_lobby.id == lobby.id

      # All 3 party members should be in the lobby and still in the party
      for user <- [leader, member1, member2] do
        u = Accounts.get_user(user.id)
        assert u.lobby_id == lobby.id, "User #{user.id} should be in the lobby"
        assert u.party_id == party.id, "User #{user.id} should still be in the party"
      end

      # Party should still exist
      assert Parties.get_party(party.id) != nil

      # Lobby should have 4 members (host + 3 party members)
      members_in_lobby =
        GameServer.Repo.all(
          Ecto.Query.from(u in GameServer.Accounts.User,
            where: u.lobby_id == ^lobby.id
          )
        )

      assert length(members_in_lobby) == 4
    end

    test "join_lobby_with_party: party still exists after failed password", %{
      leader: leader,
      member1: member1
    } do
      {:ok, party} = Parties.create_party(leader, %{})
      add_member_to_party(member1, party)
      set_all_online([leader, member1])

      host = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
      phash = Bcrypt.hash_pwd_salt("secret")

      {:ok, lobby} =
        Lobbies.create_lobby(%{
          title: "pw-lobby",
          host_id: host.id,
          password_hash: phash,
          max_users: 8
        })

      assert {:error, :password_required} = Parties.join_lobby_with_party(leader, lobby.id)

      # Party and membership should still be intact
      assert Parties.get_party(party.id) != nil
      assert Accounts.get_user(leader.id).party_id == party.id
      assert Accounts.get_user(member1.id).party_id == party.id
      assert is_nil(Accounts.get_user(leader.id).lobby_id)
      assert is_nil(Accounts.get_user(member1.id).lobby_id)
    end

    test "create_lobby_with_party: party_ids restored when lobby creation fails", %{
      leader: leader,
      member1: member1
    } do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      add_member_to_party(member1, party)
      set_all_online([leader, member1])

      # Create a lobby with the same title to cause a conflict
      # (titles need not be unique per se, but let's test with an invalid
      # max_users to force a changeset error)
      assert {:error, _} =
               Parties.create_lobby_with_party(leader, %{title: "err-lobby", max_users: 0})

      # Party should still exist
      assert Parties.get_party(party.id) != nil

      # Users should have party_id restored (not nil and not in a lobby)
      leader_fresh = Accounts.get_user(leader.id)
      member1_fresh = Accounts.get_user(member1.id)

      assert leader_fresh.party_id == party.id
      assert member1_fresh.party_id == party.id
      assert is_nil(leader_fresh.lobby_id)
      assert is_nil(member1_fresh.lobby_id)
    end
  end

  describe "PubSub events" do
    test "party_member_joined event is broadcast when invite accepted", %{
      leader: leader,
      member1: member1
    } do
      {:ok, party} = Parties.create_party(leader, %{})
      make_friends(leader, member1)
      {:ok, _} = Parties.invite_to_party(leader, member1.id)
      Parties.subscribe_party(party.id)

      {:ok, _} = Parties.accept_party_invite(member1, party.id)

      party_id = party.id
      member_id = member1.id
      assert_receive {:party_member_joined, ^party_id, ^member_id}, 500
    end

    test "party_member_left event is broadcast when member leaves", %{
      leader: leader,
      member1: member1
    } do
      {:ok, party} = Parties.create_party(leader, %{})
      add_member_to_party(member1, party)
      Parties.subscribe_party(party.id)

      {:ok, :left} = Parties.leave_party(member1)

      party_id = party.id
      member_id = member1.id
      assert_receive {:party_member_left, ^party_id, ^member_id}, 500
    end

    test "party_disbanded event is broadcast when leader leaves", %{
      leader: leader,
      member1: member1
    } do
      {:ok, party} = Parties.create_party(leader, %{})
      add_member_to_party(member1, party)
      Parties.subscribe_party(party.id)

      {:ok, :disbanded} = Parties.leave_party(leader)

      party_id = party.id
      assert_receive {:party_disbanded, ^party_id}, 500
    end

    test "party_updated event is broadcast on update", %{leader: leader} do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      Parties.subscribe_party(party.id)

      {:ok, _} = Parties.update_party(leader, %{max_size: 8})

      assert_receive {:party_updated, updated_party}, 500
      assert updated_party.max_size == 8
    end

    test "party_member_left event is broadcast on kick", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{})
      add_member_to_party(member1, party)
      Parties.subscribe_party(party.id)

      {:ok, _} = Parties.kick_member(leader, member1.id)

      party_id = party.id
      member_id = member1.id
      assert_receive {:party_member_left, ^party_id, ^member_id}, 500
    end
  end

  describe "user deletion edge cases" do
    test "deleting a party leader disbands the party and clears members", %{
      leader: leader,
      member1: member1
    } do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      add_member_to_party(member1, party)

      # Delete the leader
      {:ok, _} = Accounts.delete_user(leader)

      # Party should no longer exist (cascade from leave_party → disband)
      assert is_nil(Parties.get_party(party.id))

      # Member should have party_id cleared
      updated_member = Accounts.get_user(member1.id)
      assert is_nil(updated_member.party_id)
    end

    test "deleting a regular member removes them from the party", %{
      leader: leader,
      member1: member1
    } do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      add_member_to_party(member1, party)

      # Delete the member
      {:ok, _} = Accounts.delete_user(member1)

      # Party should still exist with leader
      remaining_party = Parties.get_party(party.id)
      assert remaining_party != nil
      assert remaining_party.leader_id == leader.id
    end
  end

  # ---------------------------------------------------------------------------
  # Sent party invitations
  # ---------------------------------------------------------------------------

  describe "list_sent_party_invitations/1" do
    test "returns invitations sent by leader", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      make_friends(leader, member1)
      {:ok, _} = Parties.invite_to_party(leader, member1.id)

      invites = Parties.list_sent_party_invitations(leader)
      assert length(invites) == 1
      invite = hd(invites)
      assert invite.party_id == party.id
      assert invite.recipient_id == member1.id
    end

    test "includes sender_name and recipient_name", %{leader: leader, member1: member1} do
      {:ok, _} =
        GameServer.Accounts.update_user_display_name(leader, %{"display_name" => "SentLeader"})

      {:ok, _} =
        GameServer.Accounts.update_user_display_name(member1, %{"display_name" => "SentMember"})

      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})
      make_friends(leader, member1)
      {:ok, _} = Parties.invite_to_party(leader, member1.id)

      invites = Parties.list_sent_party_invitations(leader)
      assert length(invites) == 1
      invite = hd(invites)
      assert invite.sender_name == "SentLeader"
      assert invite.recipient_name == "SentMember"
    end

    test "returns empty when no invitations sent", %{member1: member1} do
      assert Parties.list_sent_party_invitations(member1) == []
    end
  end

  # ---------------------------------------------------------------------------
  # Party hooks
  # ---------------------------------------------------------------------------

  describe "before_party_create hook" do
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

    test "allows create when hook returns {:ok, attrs}", %{leader: leader} do
      Application.put_env(
        :game_server_core,
        :hooks_module,
        GameServer.PartiesTest.HooksAllowPartyCreate
      )

      assert {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      assert party.leader_id == leader.id
    end

    test "blocks create when hook returns {:error, reason}", %{leader: leader} do
      Application.put_env(
        :game_server_core,
        :hooks_module,
        GameServer.PartiesTest.HooksDenyPartyCreate
      )

      assert {:error, {:hook_rejected, :party_creation_blocked}} =
               Parties.create_party(leader, %{max_size: 4})
    end

    test "hook can modify attrs before create", %{leader: leader} do
      Application.put_env(
        :game_server_core,
        :hooks_module,
        GameServer.PartiesTest.HooksModifyPartyCreate
      )

      assert {:ok, party} = Parties.create_party(leader, %{max_size: 10})
      assert party.max_size == 3
    end
  end

  describe "before_party_update hook" do
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

    test "allows update when hook returns {:ok, attrs}", %{leader: leader} do
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})

      Application.put_env(
        :game_server_core,
        :hooks_module,
        GameServer.PartiesTest.HooksAllowPartyUpdate
      )

      assert {:ok, updated} = Parties.update_party(leader, %{"max_size" => 6})
      assert updated.max_size == 6
    end

    test "blocks update when hook returns {:error, reason}", %{leader: leader} do
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})

      Application.put_env(
        :game_server_core,
        :hooks_module,
        GameServer.PartiesTest.HooksDenyPartyUpdate
      )

      assert {:error, :party_update_blocked} =
               Parties.update_party(leader, %{"max_size" => 6})
    end

    test "hook can modify attrs before update", %{leader: leader} do
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})

      Application.put_env(
        :game_server_core,
        :hooks_module,
        GameServer.PartiesTest.HooksModifyPartyUpdate
      )

      assert {:ok, updated} = Parties.update_party(leader, %{"max_size" => 10})
      assert updated.max_size == 5
    end
  end

  describe "after_party_join hook" do
    test "fires after invite accept without breaking the flow", %{
      leader: leader,
      member1: member1
    } do
      make_friends(leader, member1)
      {:ok, party} = Parties.create_party(leader, %{})
      {:ok, _invite} = Parties.invite_to_party(leader, member1.id)

      assert {:ok, _party} = Parties.accept_party_invite(member1, party.id)
      updated = Accounts.get_user(member1.id)
      assert updated.party_id == party.id
    end
  end

  describe "after_party_leave hook" do
    test "fires after leave without breaking the flow", %{leader: leader, member1: member1} do
      make_friends(leader, member1)
      {:ok, party} = Parties.create_party(leader, %{})
      {:ok, _invite} = Parties.invite_to_party(leader, member1.id)
      {:ok, _} = Parties.accept_party_invite(member1, party.id)

      assert {:ok, :left} = Parties.leave_party(member1)
      updated = Accounts.get_user(member1.id)
      assert is_nil(updated.party_id)
    end
  end

  describe "after_party_kick hook" do
    test "fires after kick without breaking the flow", %{leader: leader, member1: member1} do
      make_friends(leader, member1)
      {:ok, party} = Parties.create_party(leader, %{})
      {:ok, _invite} = Parties.invite_to_party(leader, member1.id)
      {:ok, _} = Parties.accept_party_invite(member1, party.id)

      assert {:ok, _} = Parties.kick_member(leader, member1.id)
      updated = Accounts.get_user(member1.id)
      assert is_nil(updated.party_id)
    end
  end

  describe "after_party_disband hook" do
    test "fires after disband without breaking the flow", %{leader: leader, member1: member1} do
      make_friends(leader, member1)
      {:ok, party} = Parties.create_party(leader, %{})
      {:ok, _invite} = Parties.invite_to_party(leader, member1.id)
      {:ok, _} = Parties.accept_party_invite(member1, party.id)

      # Leader leaving disbands the party (since leader)
      assert {:ok, :disbanded} = Parties.leave_party(leader)
      updated_leader = Accounts.get_user(leader.id)
      assert is_nil(updated_leader.party_id)
    end
  end
end
