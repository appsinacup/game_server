defmodule GameServer.LobbiesTest do
  use GameServer.DataCase

  alias GameServer.Lobbies
  alias GameServer.AccountsFixtures

  describe "lobbies and memberships" do
    setup do
      host = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
      other = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

      %{host: host, other: other}
    end

    test "create lobby with host and hostless lobby", %{host: host} do
      {:ok, lobby} = Lobbies.create_lobby(%{name: "room-1", title: "Test Room", host_id: host.id})

      assert lobby.name == "room-1"
      assert lobby.host_id == host.id

      {:ok, service_lobby} = Lobbies.create_lobby(%{name: "server-room", hostless: true})
      assert service_lobby.hostless
      assert is_nil(service_lobby.host_id)
    end

    test "join and capacity rules", %{host: host, other: other} do
      {:ok, lobby} = Lobbies.create_lobby(%{name: "join-room", host_id: host.id, max_users: 2})
      # lobby should be persisted and host membership will be created automatically

      # other joins
      assert {:ok, _} = Lobbies.join_lobby(other, lobby)

      # third user can't join when full
      user3 = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
      assert {:error, :full} = Lobbies.join_lobby(user3, lobby)
    end

    test "password-protected join", %{host: host, other: other} do
      pw = "secret"
      phash = Bcrypt.hash_pwd_salt(pw)

      {:ok, lobby} =
        Lobbies.create_lobby(%{name: "pw-room", host_id: host.id, password_hash: phash})

      assert {:error, :password_required} = Lobbies.join_lobby(other, lobby)
      assert {:error, :invalid_password} = Lobbies.join_lobby(other, lobby, password: "nope")
      assert {:ok, _} = Lobbies.join_lobby(other, lobby, password: pw)
    end

    test "search by metadata", %{host: host} do
      {:ok, _} =
        Lobbies.create_lobby(%{
          name: "meta-room",
          host_id: host.id,
          metadata: %{mode: "capture", region: "EU"}
        })

      {:ok, _} =
        Lobbies.create_lobby(%{
          name: "meta-room-2",
          hostless: true,
          metadata: %{mode: "deathmatch", region: "US"}
        })

      results = Lobbies.list_lobbies(%{q: "meta", metadata_key: "mode", metadata_value: "cap"})
      assert Enum.any?(results, fn r -> r.name == "meta-room" end)
      refute Enum.any?(results, fn r -> r.name == "meta-room-2" end)
    end

    test "leave lobby and host transfer", %{host: host, other: other} do
      {:ok, lobby} = Lobbies.create_lobby(%{name: "leave-room", host_id: host.id, max_users: 5})

      # other joins (host created as a member on lobby creation)
      assert {:ok, _} = Lobbies.join_lobby(other, lobby)

      # host leaves and other becomes host
      assert {:ok, _} = Lobbies.leave_lobby(host)

      refreshed = Lobbies.get_lobby!(lobby.id)
      assert refreshed.host_id == other.id
    end

    test "kick user by host", %{host: host, other: other} do
      {:ok, lobby} = Lobbies.create_lobby(%{name: "kick-room", host_id: host.id, max_users: 5})
      # host membership created on lobby creation; ensure other joins
      assert {:ok, _} = Lobbies.join_lobby(other, lobby)

      assert {:ok, _} = Lobbies.kick_user(host, lobby, other)
      # ensure other no longer in the lobby
      assert {:error, :not_in_lobby} == Lobbies.leave_lobby(other)
    end
  end
end
