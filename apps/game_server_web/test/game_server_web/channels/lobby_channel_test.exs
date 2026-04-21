defmodule GameServerWeb.LobbyChannelTest do
  use ExUnit.Case
  import Phoenix.ChannelTest

  alias GameServer.AccountsFixtures
  alias GameServer.Lobbies
  alias GameServerWeb.Auth.Guardian

  setup tags do
    GameServer.DataCase.setup_sandbox(tags)
    :ok
  end

  @endpoint GameServerWeb.Endpoint

  test "members can join lobby topic and receive broadcasts" do
    host = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
    other = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

    {:ok, lobby} = Lobbies.create_lobby(%{title: "channel-room", host_id: host.id})

    # other joins as member
    assert {:ok, _} = Lobbies.join_lobby(other, lobby)

    {:ok, token_host, _} = Guardian.encode_and_sign(host)
    {:ok, token_other, _} = Guardian.encode_and_sign(other)

    {:ok, socket_host} = connect(GameServerWeb.UserSocket, %{"token" => token_host})
    {:ok, socket_other} = connect(GameServerWeb.UserSocket, %{"token" => token_other})

    {:ok, _, _socket} = subscribe_and_join(socket_host, "lobby:#{lobby.id}", %{})
    {:ok, _, _socket} = subscribe_and_join(socket_other, "lobby:#{lobby.id}", %{})

    payload = %{event: "hello", message: "hi"}

    GameServerWeb.endpoint().broadcast("lobby:#{lobby.id}", "event", payload)

    assert_push "event", ^payload
  end

  test "non-members can join a public lobby as spectators" do
    host = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
    spectator = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

    {:ok, lobby} = Lobbies.create_lobby(%{title: "spectate-room", host_id: host.id})

    {:ok, token_spectator, _} = Guardian.encode_and_sign(spectator)
    {:ok, socket_spectator} = connect(GameServerWeb.UserSocket, %{"token" => token_spectator})

    {:ok, _, socket} = subscribe_and_join(socket_spectator, "lobby:#{lobby.id}", %{})
    assert socket.assigns.spectator == true
  end

  test "non-members cannot join a hidden lobby" do
    host = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
    stranger = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

    {:ok, lobby} = Lobbies.create_lobby(%{title: "hidden-room", host_id: host.id})
    {:ok, lobby} = Lobbies.update_lobby(lobby, %{is_hidden: true})

    {:ok, token_stranger, _} = Guardian.encode_and_sign(stranger)
    {:ok, socket_stranger} = connect(GameServerWeb.UserSocket, %{"token" => token_stranger})

    assert {:error, %{reason: "not_spectatable"}} =
             subscribe_and_join(socket_stranger, "lobby:#{lobby.id}", %{})
  end

  test "non-members cannot join a locked lobby" do
    host = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
    stranger = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

    {:ok, lobby} = Lobbies.create_lobby(%{title: "locked-room", host_id: host.id})
    {:ok, lobby} = Lobbies.update_lobby(lobby, %{is_locked: true})

    {:ok, token_stranger, _} = Guardian.encode_and_sign(stranger)
    {:ok, socket_stranger} = connect(GameServerWeb.UserSocket, %{"token" => token_stranger})

    assert {:error, %{reason: "not_spectatable"}} =
             subscribe_and_join(socket_stranger, "lobby:#{lobby.id}", %{})
  end

  test "user in a different lobby cannot spectate another lobby" do
    host1 = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
    host2 = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
    member = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

    {:ok, lobby1} = Lobbies.create_lobby(%{title: "lobby-1", host_id: host1.id})
    {:ok, lobby2} = Lobbies.create_lobby(%{title: "lobby-2", host_id: host2.id})

    # member joins lobby1
    {:ok, _} = Lobbies.join_lobby(member, lobby1)

    {:ok, token_member, _} = Guardian.encode_and_sign(member)
    {:ok, socket_member} = connect(GameServerWeb.UserSocket, %{"token" => token_member})

    # member tries to spectate lobby2 — should be rejected
    assert {:error, %{reason: "must_spectate_own_lobby"}} =
             subscribe_and_join(socket_member, "lobby:#{lobby2.id}", %{})
  end

  test "channel receives user_kicked event when member is kicked" do
    host = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
    member = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

    {:ok, lobby} = Lobbies.create_lobby(%{title: "kick-channel-room", host_id: host.id})
    assert {:ok, _} = Lobbies.join_lobby(member, lobby)

    {:ok, token_host, _} = Guardian.encode_and_sign(host)
    {:ok, socket_host} = connect(GameServerWeb.UserSocket, %{"token" => token_host})
    {:ok, _, _socket} = subscribe_and_join(socket_host, "lobby:#{lobby.id}", %{})

    # Kick the member - this should broadcast user_kicked event
    {:ok, _} = Lobbies.kick_user(host, lobby, member)

    assert_push "user_kicked", %{user_id: kicked_id, display_name: kicked_name}
    assert kicked_id == member.id
    assert is_binary(kicked_name)
  end

  test "channel receives updated event when lobby is updated" do
    host = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

    {:ok, lobby} = Lobbies.create_lobby(%{title: "update-channel-room", host_id: host.id})

    {:ok, token_host, _} = Guardian.encode_and_sign(host)
    {:ok, socket_host} = connect(GameServerWeb.UserSocket, %{"token" => token_host})
    {:ok, _, _socket} = subscribe_and_join(socket_host, "lobby:#{lobby.id}", %{})

    # drain the initial after_join payload
    assert_push "updated", %{title: "update-channel-room"}, 500

    # Update the lobby
    {:ok, _} = Lobbies.update_lobby_by_host(host, lobby, %{"title" => "New Title"})

    # allow a slightly longer window for the broadcast -> push to arrive in tests
    assert_push "updated", payload, 500
    assert payload.title == "New Title"
    assert Map.has_key?(payload, :host_name)
  end

  test "channel emits a single updated event per lobby update" do
    host = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

    {:ok, lobby} = Lobbies.create_lobby(%{title: "single-update-room", host_id: host.id})

    {:ok, token_host, _} = Guardian.encode_and_sign(host)
    {:ok, socket_host} = connect(GameServerWeb.UserSocket, %{"token" => token_host})
    {:ok, _, _socket} = subscribe_and_join(socket_host, "lobby:#{lobby.id}", %{})

    # consume the initial after_join payload
    assert_push "updated", %{title: "single-update-room"}, 500

    {:ok, _} = Lobbies.update_lobby_by_host(host, lobby, %{"title" => "Single Update"})

    assert_push "updated", %{title: "Single Update"}, 500
    refute_push "updated", _payload, 200
  end

  test "channel receives member_online when a lobby member comes online" do
    host = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
    member = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

    {:ok, lobby} = Lobbies.create_lobby(%{title: "presence-room", host_id: host.id})
    {:ok, _} = Lobbies.join_lobby(member, lobby)

    {:ok, token_host, _} = Guardian.encode_and_sign(host)
    {:ok, socket_host} = connect(GameServerWeb.UserSocket, %{"token" => token_host})
    {:ok, _, _socket} = subscribe_and_join(socket_host, "lobby:#{lobby.id}", %{})

    # drain the initial after_join payload
    assert_push "updated", _initial, 500

    # Simulate member coming online
    Lobbies.broadcast_member_presence(lobby.id, {:member_online, member.id})

    assert_push "member_online", payload, 500
    assert payload.user_id == member.id
    assert Map.has_key?(payload, :display_name)
    assert Map.has_key?(payload, :metadata)
  end

  test "channel receives member_offline when a lobby member goes offline" do
    host = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
    member = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

    {:ok, lobby} = Lobbies.create_lobby(%{title: "offline-room", host_id: host.id})
    {:ok, _} = Lobbies.join_lobby(member, lobby)

    {:ok, token_host, _} = Guardian.encode_and_sign(host)
    {:ok, socket_host} = connect(GameServerWeb.UserSocket, %{"token" => token_host})
    {:ok, _, _socket} = subscribe_and_join(socket_host, "lobby:#{lobby.id}", %{})

    # drain the initial after_join payload
    assert_push "updated", _initial, 500

    # Simulate member going offline
    Lobbies.broadcast_member_presence(lobby.id, {:member_offline, member.id})

    assert_push "member_offline", payload, 500
    assert payload.user_id == member.id
    assert Map.has_key?(payload, :display_name)
  end
end
