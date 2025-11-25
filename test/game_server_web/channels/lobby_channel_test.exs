defmodule GameServerWeb.LobbyChannelTest do
  use ExUnit.Case
  import Phoenix.ChannelTest

  alias GameServerWeb.Auth.Guardian
  alias GameServer.AccountsFixtures
  alias GameServer.Lobbies

  setup tags do
    GameServer.DataCase.setup_sandbox(tags)
    :ok
  end

  @endpoint GameServerWeb.Endpoint

  test "members can join lobby topic and receive broadcasts" do
    host = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
    other = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

    {:ok, lobby} = Lobbies.create_lobby(%{name: "channel-room", host_id: host.id})

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

    {:ok, lobby} = Lobbies.create_lobby(%{name: "reject-room", host_id: host.id})

    {:ok, token_stranger, _} = Guardian.encode_and_sign(stranger)
    {:ok, socket_stranger} = connect(GameServerWeb.UserSocket, %{"token" => token_stranger})

    assert {:error, _} = subscribe_and_join(socket_stranger, "lobby:#{lobby.id}", %{})
  end
end
