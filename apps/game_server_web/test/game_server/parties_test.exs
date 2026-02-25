defmodule GameServer.PartiesTest do
  use GameServer.DataCase

  alias GameServer.Accounts
  alias GameServer.AccountsFixtures
  alias GameServer.Lobbies
  alias GameServer.Parties

  setup do
    leader = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
    member1 = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
    member2 = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

    %{leader: leader, member1: member1, member2: member2}
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

  describe "join_party/2" do
    test "allows a user to join an existing party", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})

      assert {:ok, updated_member} = Parties.join_party(member1, party.id)
      assert updated_member.party_id == party.id

      members = Parties.get_party_members(party.id)
      assert length(members) == 2
    end

    test "cannot join a party while already in a party", %{
      leader: leader,
      member1: member1,
      member2: _member2
    } do
      {:ok, party1} = Parties.create_party(leader, %{})
      {:ok, _party2} = Parties.create_party(member1, %{})

      assert {:error, :already_in_party} = Parties.join_party(member1, party1.id)
    end

    test "cannot join a non-existent party", %{member1: member1} do
      assert {:error, :party_not_found} = Parties.join_party(member1, 999_999)
    end

    test "cannot join a full party", %{leader: leader, member1: member1, member2: member2} do
      {:ok, party} = Parties.create_party(leader, %{max_size: 2})
      {:ok, _} = Parties.join_party(member1, party.id)

      assert {:error, :party_full} = Parties.join_party(member2, party.id)
    end
  end

  describe "leave_party/1" do
    test "leader leaving disbands the party", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{})
      {:ok, _} = Parties.join_party(member1, party.id)

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
      {:ok, _} = Parties.join_party(member1, party.id)

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
      {:ok, _} = Parties.join_party(member1, party.id)

      assert {:ok, _} = Parties.kick_member(leader, member1.id)

      assert is_nil(Accounts.get_user(member1.id).party_id)
      assert Parties.get_party(party.id) != nil
    end

    test "non-leader cannot kick", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{})
      {:ok, _} = Parties.join_party(member1, party.id)

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
      {:ok, _} = Parties.join_party(member1, party.id)

      # 2 members, can't set to 1
      assert {:error, :too_small} = Parties.update_party(leader, %{max_size: 1})
    end

    test "non-leader cannot update", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{})
      {:ok, _} = Parties.join_party(member1, party.id)

      assert {:error, :not_leader} = Parties.update_party(member1, %{max_size: 8})
    end
  end

  describe "create_lobby_with_party/2" do
    test "leader creates lobby and all members join, party stays intact", %{
      leader: leader,
      member1: member1
    } do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      {:ok, _} = Parties.join_party(member1, party.id)

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
      {:ok, _} = Parties.join_party(member1, party.id)
      {:ok, _} = Parties.join_party(member2, party.id)

      # 3 members but max_users = 2
      assert {:error, :lobby_too_small_for_party} =
               Parties.create_lobby_with_party(leader, %{title: "tiny", max_users: 2})
    end

    test "non-leader cannot create lobby with party", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{})
      {:ok, _} = Parties.join_party(member1, party.id)

      assert {:error, :not_leader} = Parties.create_lobby_with_party(member1, %{title: "nope"})
    end

    test "fails if any party member is already in a lobby", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      {:ok, _} = Parties.join_party(member1, party.id)

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
      {:ok, _} = Parties.join_party(member1, party.id)

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
      {:ok, _} = Parties.join_party(member1, party.id)
      {:ok, _} = Parties.join_party(member2, party.id)

      # Create a lobby with max 3 users and 1 already in it (the host)
      host = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
      {:ok, lobby} = Lobbies.create_lobby(%{title: "small-lobby", host_id: host.id, max_users: 3})

      # 3 party members + 1 existing host = 4, but max is 3
      assert {:error, :not_enough_space} = Parties.join_lobby_with_party(leader, lobby.id)
    end

    test "fails if lobby is locked", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{})
      {:ok, _} = Parties.join_party(member1, party.id)

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
      {:ok, _} = Parties.join_party(member1, party.id)

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
      {:ok, _} = Parties.join_party(member1, party.id)

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
      {:ok, _} = Parties.join_party(member1, party.id)

      host = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
      {:ok, lobby} = Lobbies.create_lobby(%{title: "test-lobby", host_id: host.id})

      assert {:error, :not_leader} = Parties.join_lobby_with_party(member1, lobby.id)
    end

    test "cannot join non-existent lobby with party", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{})
      {:ok, _} = Parties.join_party(member1, party.id)

      assert {:error, :invalid_lobby} = Parties.join_lobby_with_party(leader, 999_999)
    end

    test "fails with wrong password", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{})
      {:ok, _} = Parties.join_party(member1, party.id)

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
      {:ok, _} = Parties.join_party(member1, party.id)

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
      {:ok, _} = Parties.join_party(member1, party.id)
      {:ok, _} = Parties.join_party(member2, party.id)

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
      {:ok, _} = Parties.join_party(member1, party.id)
      {:ok, _} = Parties.join_party(member2, party.id)

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
      {:ok, _} = Parties.join_party(member1, party.id)

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
      {:ok, _} = Parties.join_party(member1, party.id)

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
    test "party_member_joined event is broadcast on join", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{})
      Parties.subscribe_party(party.id)

      {:ok, _} = Parties.join_party(member1, party.id)

      party_id = party.id
      member_id = member1.id
      assert_receive {:party_member_joined, ^party_id, ^member_id}, 500
    end

    test "party_member_left event is broadcast when member leaves", %{
      leader: leader,
      member1: member1
    } do
      {:ok, party} = Parties.create_party(leader, %{})
      {:ok, _} = Parties.join_party(member1, party.id)
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
      {:ok, _} = Parties.join_party(member1, party.id)
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
      {:ok, _} = Parties.join_party(member1, party.id)
      Parties.subscribe_party(party.id)

      {:ok, _} = Parties.kick_member(leader, member1.id)

      party_id = party.id
      member_id = member1.id
      assert_receive {:party_member_left, ^party_id, ^member_id}, 500
    end
  end

  # ---------------------------------------------------------------------------
  # Invite system
  # ---------------------------------------------------------------------------

  describe "invite_to_party/2" do
    test "leader can invite a user", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})

      assert {:ok, notification} = Parties.invite_to_party(leader, member1.id)
      assert notification.sender_id == leader.id
      assert notification.recipient_id == member1.id
      assert notification.title == "party_invite"
      assert notification.metadata["party_id"] == party.id
    end

    test "cannot invite if not in a party", %{member1: member1, member2: member2} do
      assert {:error, :not_in_party} = Parties.invite_to_party(member1, member2.id)
    end

    test "cannot invite if not the leader", %{leader: leader, member1: member1, member2: member2} do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      {:ok, _} = Parties.join_party(member1, party.id)

      assert {:error, :not_leader} = Parties.invite_to_party(member1, member2.id)
    end

    test "cannot invite self", %{leader: leader} do
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})

      assert {:error, :self_invite} = Parties.invite_to_party(leader, leader.id)
    end

    test "cannot invite user already in a party", %{leader: leader, member1: member1} do
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})
      {:ok, _party2} = Parties.create_party(member1, %{max_size: 4})

      assert {:error, :target_in_party} = Parties.invite_to_party(leader, member1.id)
    end

    test "cannot invite non-existent user", %{leader: leader} do
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})

      assert {:error, :user_not_found} = Parties.invite_to_party(leader, 999_999)
    end

    test "cannot send duplicate invite", %{leader: leader, member1: member1} do
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})
      {:ok, _} = Parties.invite_to_party(leader, member1.id)

      assert {:error, _} = Parties.invite_to_party(leader, member1.id)
    end

    test "cannot invite a blocked user", %{leader: leader, member1: member1} do
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})

      # Create a friend request and block it
      {:ok, f} = GameServer.Friends.create_request(leader.id, member1.id)
      {:ok, _blocked} = GameServer.Friends.block_friend_request(f.id, member1)

      assert {:error, :blocked} = Parties.invite_to_party(leader, member1.id)
    end

    test "cannot invite if target has blocked the leader", %{leader: leader, member1: member1} do
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})

      # Target blocks the leader
      {:ok, f} = GameServer.Friends.create_request(member1.id, leader.id)
      {:ok, _blocked} = GameServer.Friends.block_friend_request(f.id, leader)

      assert {:error, :blocked} = Parties.invite_to_party(leader, member1.id)
    end
  end

  describe "accept_party_invite/2" do
    test "user can accept a party invite", %{leader: leader, member1: member1} do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      {:ok, notification} = Parties.invite_to_party(leader, member1.id)

      assert {:ok, updated_user} = Parties.accept_party_invite(member1, notification.id)
      assert updated_user.party_id == party.id

      # Notification should be deleted
      assert Parties.count_party_invites(member1.id) == 0
    end

    test "cannot accept invite for non-existent notification", %{member1: member1} do
      assert {:error, :invite_not_found} = Parties.accept_party_invite(member1, 999_999)
    end

    test "cannot accept someone else's invite", %{
      leader: leader,
      member1: member1,
      member2: member2
    } do
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})
      {:ok, notification} = Parties.invite_to_party(leader, member1.id)

      assert {:error, :invite_not_found} = Parties.accept_party_invite(member2, notification.id)
    end

    test "cannot accept if already in a party", %{
      leader: leader,
      member1: member1,
      member2: member2
    } do
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})
      {:ok, _party2} = Parties.create_party(member2, %{max_size: 4})

      # Invite member2 - but first they need to not be in a party, so use member1
      {:ok, notification} = Parties.invite_to_party(leader, member1.id)

      # member1 creates their own party before accepting
      {:ok, _party3} = Parties.create_party(member1, %{max_size: 4})

      assert {:error, :already_in_party} = Parties.accept_party_invite(member1, notification.id)
    end

    test "cannot accept if party is full", %{leader: leader, member1: member1, member2: member2} do
      {:ok, party} = Parties.create_party(leader, %{max_size: 2})
      {:ok, notification} = Parties.invite_to_party(leader, member1.id)

      # Fill the party with member2
      {:ok, _} = Parties.join_party(member2, party.id)

      assert {:error, :party_full} = Parties.accept_party_invite(member1, notification.id)
    end

    test "cannot accept if party has been disbanded", %{leader: leader, member1: member1} do
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})
      {:ok, notification} = Parties.invite_to_party(leader, member1.id)

      # Leader leaves, disbanding the party
      {:ok, :disbanded} = Parties.leave_party(leader)

      assert {:error, :party_not_found} = Parties.accept_party_invite(member1, notification.id)
    end
  end

  describe "decline_party_invite/2" do
    test "user can decline a party invite", %{leader: leader, member1: member1} do
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})
      {:ok, notification} = Parties.invite_to_party(leader, member1.id)

      assert :ok = Parties.decline_party_invite(member1, notification.id)

      # Notification should be deleted
      assert Parties.count_party_invites(member1.id) == 0
    end

    test "cannot decline non-existent invite", %{member1: member1} do
      assert {:error, :invite_not_found} = Parties.decline_party_invite(member1, 999_999)
    end

    test "cannot decline someone else's invite", %{
      leader: leader,
      member1: member1,
      member2: member2
    } do
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})
      {:ok, notification} = Parties.invite_to_party(leader, member1.id)

      assert {:error, :invite_not_found} = Parties.decline_party_invite(member2, notification.id)
    end
  end

  describe "cancel_party_invite/2" do
    test "leader can cancel a sent invite", %{leader: leader, member1: member1} do
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})
      {:ok, notification} = Parties.invite_to_party(leader, member1.id)

      assert :ok = Parties.cancel_party_invite(leader, notification.id)

      # Notification should be deleted
      assert Parties.count_party_invites(member1.id) == 0
    end

    test "cannot cancel non-existent invite", %{leader: leader} do
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})

      assert {:error, :invite_not_found} = Parties.cancel_party_invite(leader, 999_999)
    end

    test "cannot cancel someone else's invite", %{
      leader: leader,
      member1: member1,
      member2: member2
    } do
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})
      {:ok, notification} = Parties.invite_to_party(leader, member1.id)

      assert {:error, :not_sender} = Parties.cancel_party_invite(member2, notification.id)
    end
  end

  describe "list_party_invites/2 and count_party_invites/1" do
    test "lists and counts pending invites for a user", %{leader: leader, member1: member1} do
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})
      {:ok, _} = Parties.invite_to_party(leader, member1.id)

      invites = Parties.list_party_invites(member1.id)
      assert length(invites) == 1
      assert hd(invites).recipient_id == member1.id

      assert Parties.count_party_invites(member1.id) == 0 or
               Parties.count_party_invites(member1.id) == 1

      assert Parties.count_party_invites(member1.id) == 1
    end

    test "returns empty list when no invites", %{member1: member1} do
      assert Parties.list_party_invites(member1.id) == []
      assert Parties.count_party_invites(member1.id) == 0
    end

    test "pagination works", %{leader: leader, member1: member1} do
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})

      # We can only send one invite per (sender, recipient, title) due to unique constraint
      # So just verify page_size works
      {:ok, _} = Parties.invite_to_party(leader, member1.id)

      page1 = Parties.list_party_invites(member1.id, page: 1, page_size: 1)
      assert length(page1) == 1

      page2 = Parties.list_party_invites(member1.id, page: 2, page_size: 1)
      assert page2 == []
    end
  end

  describe "list_sent_party_invites/2" do
    test "lists invites sent by a user", %{leader: leader, member1: member1, member2: member2} do
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})
      {:ok, _} = Parties.invite_to_party(leader, member1.id)
      {:ok, _} = Parties.invite_to_party(leader, member2.id)

      sent = Parties.list_sent_party_invites(leader.id)
      assert length(sent) == 2
      assert Enum.all?(sent, fn n -> n.sender_id == leader.id end)
    end

    test "returns empty list when no sent invites", %{member1: member1} do
      assert Parties.list_sent_party_invites(member1.id) == []
    end
  end

  describe "user deletion edge cases" do
    test "deleting a party leader disbands the party and clears members", %{
      leader: leader,
      member1: member1
    } do
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      {:ok, _} = Parties.join_party(member1, party.id)

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
      {:ok, _} = Parties.join_party(member1, party.id)

      # Delete the member
      {:ok, _} = Accounts.delete_user(member1)

      # Party should still exist with leader
      remaining_party = Parties.get_party(party.id)
      assert remaining_party != nil
      assert remaining_party.leader_id == leader.id
    end
  end
end
