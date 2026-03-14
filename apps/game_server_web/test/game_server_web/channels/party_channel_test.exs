defmodule GameServerWeb.PartyChannelTest do
  use ExUnit.Case
  import Phoenix.ChannelTest

  alias GameServer.AccountsFixtures
  alias GameServer.Parties
  alias GameServerWeb.Auth.Guardian

  setup tags do
    GameServer.DataCase.setup_sandbox(tags)
    :ok
  end

  @endpoint GameServerWeb.Endpoint

  defp add_member_to_party(user, party) do
    user
    |> Ecto.Changeset.change(%{party_id: party.id})
    |> GameServer.Repo.update!()
  end

  test "members can join party channel and receive broadcasts" do
    leader = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
    member = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

    {:ok, party} = Parties.create_party(leader, %{})
    add_member_to_party(member, party)

    {:ok, token_leader, _} = Guardian.encode_and_sign(leader)
    {:ok, socket_leader} = connect(GameServerWeb.UserSocket, %{"token" => token_leader})
    {:ok, _, _socket} = subscribe_and_join(socket_leader, "party:#{party.id}", %{})

    # drain the initial after_join payload
    assert_push "updated", _initial, 500
  end

  test "non-members cannot join party channel" do
    leader = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
    stranger = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

    {:ok, party} = Parties.create_party(leader, %{})

    {:ok, token_stranger, _} = Guardian.encode_and_sign(stranger)
    {:ok, socket_stranger} = connect(GameServerWeb.UserSocket, %{"token" => token_stranger})

    assert {:error, %{reason: "not_a_member"}} =
             subscribe_and_join(socket_stranger, "party:#{party.id}", %{})
  end

  test "channel receives member_online when a party member comes online" do
    leader = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
    member = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

    {:ok, party} = Parties.create_party(leader, %{})
    add_member_to_party(member, party)

    {:ok, token_leader, _} = Guardian.encode_and_sign(leader)
    {:ok, socket_leader} = connect(GameServerWeb.UserSocket, %{"token" => token_leader})
    {:ok, _, _socket} = subscribe_and_join(socket_leader, "party:#{party.id}", %{})

    # drain the initial after_join payload
    assert_push "updated", _initial, 500

    # Simulate member coming online
    Parties.broadcast_member_presence(party.id, {:member_online, member.id})

    assert_push "member_online", payload, 500
    assert payload.user_id == member.id
    assert Map.has_key?(payload, :display_name)
    assert Map.has_key?(payload, :metadata)
  end

  test "channel receives member_offline when a party member goes offline" do
    leader = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
    member = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

    {:ok, party} = Parties.create_party(leader, %{})
    add_member_to_party(member, party)

    {:ok, token_leader, _} = Guardian.encode_and_sign(leader)
    {:ok, socket_leader} = connect(GameServerWeb.UserSocket, %{"token" => token_leader})
    {:ok, _, _socket} = subscribe_and_join(socket_leader, "party:#{party.id}", %{})

    # drain the initial after_join payload
    assert_push "updated", _initial, 500

    # Simulate member going offline
    Parties.broadcast_member_presence(party.id, {:member_offline, member.id})

    assert_push "member_offline", payload, 500
    assert payload.user_id == member.id
    assert Map.has_key?(payload, :display_name)
  end
end
