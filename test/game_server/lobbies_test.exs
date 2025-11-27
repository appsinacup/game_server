defmodule GameServer.LobbiesTest do
  use GameServer.DataCase

  alias GameServer.AccountsFixtures
  alias GameServer.Lobbies

  describe "lobbies and memberships" do
    defmodule CaptureHook do
      @behaviour GameServer.Hooks

      @impl true
      def after_user_register(_user), do: :ok

      @impl true
      def after_user_login(_user), do: :ok

      # Lobby lifecycle hooks - implement minimal no-ops and capture after_lobby_join
      @impl true
      def before_lobby_create(attrs), do: {:ok, attrs}

      @impl true
      def after_lobby_create(_lobby), do: :ok

      @impl true
      def before_lobby_join(user, lobby, opts), do: {:ok, {user, lobby, opts}}

      @impl true
      def after_lobby_join(_user, lobby) do
        if pid = Application.get_env(:game_server, :hooks_test_pid) do
          send(pid, {:after_lobby_join, lobby})
        end

        :ok
      end

      @impl true
      def before_lobby_leave(user, lobby), do: {:ok, {user, lobby}}

      @impl true
      def after_lobby_leave(_user, _lobby), do: :ok

      @impl true
      def before_lobby_update(_lobby, attrs), do: {:ok, attrs}

      @impl true
      def after_lobby_update(_lobby), do: :ok

      @impl true
      def before_lobby_delete(lobby), do: {:ok, lobby}

      @impl true
      def after_lobby_delete(_lobby), do: :ok

      @impl true
      def before_user_kicked(host, target, lobby), do: {:ok, {host, target, lobby}}

      @impl true
      def after_user_kicked(_host, _target, _lobby), do: :ok

      @impl true
      def after_lobby_host_change(_lobby, _new_host_id), do: :ok
    end

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

    test "kick errors: cannot kick self, not_host, not_found, not_in_lobby", %{
      host: host,
      other: other
    } do
      # set up lobby and memberships
      {:ok, lobby} = Lobbies.create_lobby(%{name: "errors-room", host_id: host.id, max_users: 5})
      assert {:ok, _} = Lobbies.join_lobby(other, lobby)

      # cannot kick self
      assert {:error, :cannot_kick_self} = Lobbies.kick_user(host, lobby, host)

      # not_host (some other non-host user tries to kick) - create additional user
      another = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
      assert {:error, :not_host} = Lobbies.kick_user(another, lobby, other)

      # not_found (target id points to non-existing user)
      assert {:error, :not_found} =
               Lobbies.kick_user(host, lobby, %GameServer.Accounts.User{id: 999_999})

      # not_in_lobby: target exists but not in this lobby
      outsider = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
      assert {:error, :not_in_lobby} = Lobbies.kick_user(host, lobby, outsider)
    end

    test "cannot join if already in a lobby", %{host: host, other: other} do
      {:ok, lobby1} = Lobbies.create_lobby(%{name: "a-room-1", host_id: host.id})

      # other joins lobby1
      assert {:ok, _} = Lobbies.join_lobby(other, lobby1)

      # tries to join a different lobby and should get error :already_in_lobby
      {:ok, lobby2} =
        Lobbies.create_lobby(%{name: "a-room-2", host_id: AccountsFixtures.user_fixture().id})

      assert {:error, :already_in_lobby} = Lobbies.join_lobby(other, lobby2)
    end

    test "before_lobby_join hook can reject a join", %{host: host, other: other} do
      orig = Application.get_env(:game_server, :hooks_module)

      defmodule DenyJoinHook do
        def before_lobby_create(attrs), do: {:ok, attrs}
        def before_lobby_join(_user, _lobby, _opts), do: {:error, :banned}
        def after_lobby_create(_), do: :ok
        def after_lobby_join(_user, _lobby), do: :ok
        def before_lobby_leave(_, _), do: {:ok, :noop}
        def after_lobby_leave(_, _), do: :ok
        def before_user_kicked(_, _, _), do: {:ok, :noop}
        def after_user_kicked(_, _, _), do: :ok
        def before_lobby_update(_, _), do: {:ok, %{}}
        def after_lobby_update(_), do: :ok
        def before_lobby_delete(_), do: {:ok, %{}}
        def after_lobby_delete(_), do: :ok
        def after_lobby_host_change(_, _), do: :ok
      end

      Application.put_env(:game_server, :hooks_module, DenyJoinHook)

      on_exit(fn -> Application.put_env(:game_server, :hooks_module, orig) end)

      {:ok, lobby} = Lobbies.create_lobby(%{name: "deny-room", host_id: host.id})
      assert {:error, {:hook_rejected, :banned}} = Lobbies.join_lobby(other, lobby)
    end

    test "create_membership invokes hook without doing DB checkouts in child task", %{
      host: host,
      other: other
    } do
      orig = Application.get_env(:game_server, :hooks_module)
      orig_pid = Application.get_env(:game_server, :hooks_test_pid)

      on_exit(fn ->
        Application.put_env(:game_server, :hooks_module, orig)
        Application.put_env(:game_server, :hooks_test_pid, orig_pid)
      end)

      # register our capture hook and give it the pid so it can notify us
      Application.put_env(:game_server, :hooks_module, CaptureHook)
      Application.put_env(:game_server, :hooks_test_pid, self())

      {:ok, lobby} = Lobbies.create_lobby(%{name: "hook-room", host_id: host.id, max_users: 5})

      # Ensure join triggers create_membership which starts background task
      assert {:ok, _} = Lobbies.join_lobby(other, lobby)

      # create_membership starts a background task; wait for the hook message
      assert_receive {:after_lobby_join, received_lobby}, 200

      assert received_lobby.id == lobby.id
    end

    test "cannot shrink lobby max_users below current member count", %{host: host, other: other} do
      # create with max_users 3, host auto-joined
      {:ok, lobby} = Lobbies.create_lobby(%{name: "shrink-room", host_id: host.id, max_users: 3})

      # two other users join -> total 3
      assert {:ok, _} = Lobbies.join_lobby(other, lobby)
      user3 = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
      assert {:ok, _} = Lobbies.join_lobby(user3, lobby)

      # host tries to shrink to 2, should be rejected
      assert {:error, :too_small} = Lobbies.update_lobby_by_host(host, lobby, %{max_users: 2})

      # increasing is allowed
      assert {:ok, updated} = Lobbies.update_lobby_by_host(host, lobby, %{max_users: 6})
      assert updated.max_users == 6
    end
  end
end
