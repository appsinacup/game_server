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

    GameServerWeb.Endpoint.broadcast("lobby:#{lobby.id}", "event", payload)

    assert_push "event", ^payload
  end

  test "non-members cannot join a lobby topic" do
    host = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
    stranger = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

    {:ok, lobby} = Lobbies.create_lobby(%{title: "reject-room", host_id: host.id})

    {:ok, token_stranger, _} = Guardian.encode_and_sign(stranger)
    {:ok, socket_stranger} = connect(GameServerWeb.UserSocket, %{"token" => token_stranger})

    assert {:error, _} = subscribe_and_join(socket_stranger, "lobby:#{lobby.id}", %{})
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

    assert_push "user_kicked", %{user_id: kicked_id}
    assert kicked_id == member.id
  end

  test "channel receives updated event when lobby is updated" do
    host = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

    {:ok, lobby} = Lobbies.create_lobby(%{title: "update-channel-room", host_id: host.id})

    {:ok, token_host, _} = Guardian.encode_and_sign(host)
    {:ok, socket_host} = connect(GameServerWeb.UserSocket, %{"token" => token_host})
    {:ok, _, _socket} = subscribe_and_join(socket_host, "lobby:#{lobby.id}", %{})

    # Update the lobby
    {:ok, _} = Lobbies.update_lobby_by_host(host, lobby, %{"title" => "New Title"})

    # allow a slightly longer window for the broadcast -> push to arrive in tests
    assert_push "updated", %{title: "New Title"}, 500
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
end
