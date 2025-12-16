defmodule GameServerWeb.LobbiesChannelTest do
  use ExUnit.Case
  import Phoenix.ChannelTest

  alias GameServer.AccountsFixtures
  alias GameServer.Lobbies

  setup tags do
    GameServer.DataCase.setup_sandbox(tags)
    :ok
  end

  @endpoint GameServerWeb.Endpoint

  test "clients can join lobbies topic and receive lobby_created, updated, membership changes, and deleted" do
    host = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
    member = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

    # anonymous socket should be able to subscribe to global lobbies
    {:ok, socket} = connect(GameServerWeb.UserSocket, %{})
    {:ok, _, _socket} = subscribe_and_join(socket, "lobbies", %{})

    # create lobby (this should broadcast a lobby_created event)
    {:ok, lobby} = Lobbies.create_lobby(%{title: "global-room", host_id: host.id})

    assert_push "lobby_created", %{id: id}
    assert id == lobby.id

    # membership change (joining as member should broadcast lobby_membership_changed)
    assert {:ok, _} = Lobbies.join_lobby(member, lobby)
    assert_push "lobby_membership_changed", %{id: id2}
    assert id2 == lobby.id

    # update lobby by host
    {:ok, _updated} = Lobbies.update_lobby_by_host(host, lobby, %{"title" => "Brand New"})
    assert_push "lobby_updated", %{title: "Brand New"}

    # delete lobby (broadcasts a lobby_deleted event)
    {:ok, deleted} = Lobbies.delete_lobby(lobby)
    assert_push "lobby_deleted", %{id: id3}
    assert id3 == deleted.id
  end
end
