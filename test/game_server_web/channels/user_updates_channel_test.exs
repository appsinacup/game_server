defmodule GameServerWeb.UserChannelTest do
  use ExUnit.Case
  import Phoenix.ChannelTest

  alias GameServer.AccountsFixtures
  alias GameServerWeb.Auth.Guardian

  setup tags do
    GameServer.DataCase.setup_sandbox(tags)
    :ok
  end

  @endpoint GameServerWeb.Endpoint

  test "join allowed for owner and receives broadcasts" do
    user = AccountsFixtures.user_fixture()
    {:ok, token, _claims} = Guardian.encode_and_sign(user)

    {:ok, socket} = connect(GameServerWeb.UserSocket, %{"token" => token})
    # verify connect assigned a current_scope (user auto-loaded)
    assert Map.has_key?(socket.assigns, :current_scope)
    assert socket.assigns.current_scope.user.id == user.id
    {:ok, _, _socket} = subscribe_and_join(socket, "user:#{user.id}", %{})

    payload = %{id: user.id, metadata: %{"display_name" => "Updated"}}

    GameServerWeb.Endpoint.broadcast("user:#{user.id}", "updated", payload)

    # The test process receives the push
    assert_push "updated", ^payload
  end

  test "user channel receives friend events for create & accept flows" do
    a = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
    b = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

    {:ok, token_a, _} = Guardian.encode_and_sign(a)
    {:ok, token_b, _} = Guardian.encode_and_sign(b)

    {:ok, socket_a} = connect(GameServerWeb.UserSocket, %{"token" => token_a})
    {:ok, socket_b} = connect(GameServerWeb.UserSocket, %{"token" => token_b})

    {:ok, _, _socket_a} = subscribe_and_join(socket_a, "user:#{a.id}", %{})
    {:ok, _, _socket_b} = subscribe_and_join(socket_b, "user:#{b.id}", %{})

    # create request a -> b
    assert {:ok, f} = GameServer.Friends.create_request(a.id, b.id)

    expected = %{
      id: f.id,
      requester_id: f.requester_id,
      target_id: f.target_id,
      status: f.status
    }

    # both requester and target should receive channel pushes for outgoing/incoming
    assert_push "outgoing_request", ^expected
    assert_push "incoming_request", ^expected

    # accept as b
    assert {:ok, accepted} = GameServer.Friends.accept_friend_request(f.id, b)

    expected_acc = %{
      id: accepted.id,
      requester_id: accepted.requester_id,
      target_id: accepted.target_id,
      status: accepted.status
    }

    # both users get friend_accepted
    assert_push "friend_accepted", ^expected_acc
    assert_push "friend_accepted", ^expected_acc
  end

  test "user channel receives friend events for reject and cancel flows" do
    a = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
    b = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

    {:ok, token_a, _} = Guardian.encode_and_sign(a)
    {:ok, token_b, _} = Guardian.encode_and_sign(b)

    {:ok, socket_a} = connect(GameServerWeb.UserSocket, %{"token" => token_a})
    {:ok, socket_b} = connect(GameServerWeb.UserSocket, %{"token" => token_b})

    {:ok, _, _socket_a} = subscribe_and_join(socket_a, "user:#{a.id}", %{})
    {:ok, _, _socket_b} = subscribe_and_join(socket_b, "user:#{b.id}", %{})

    # create request a -> b
    assert {:ok, f} = GameServer.Friends.create_request(a.id, b.id)

    # reject as b
    assert {:ok, rejected} = GameServer.Friends.reject_friend_request(f.id, b)

    expected_rej = %{
      id: rejected.id,
      requester_id: rejected.requester_id,
      target_id: rejected.target_id,
      status: rejected.status
    }

    assert_push "friend_rejected", ^expected_rej
    assert_push "friend_rejected", ^expected_rej

    # create a new request then cancel as requester
    {:ok, f2} = GameServer.Friends.create_request(a.id, b.id)
    assert {:ok, :cancelled} = GameServer.Friends.cancel_request(f2.id, a)

    expected_cancel = %{
      id: f2.id,
      requester_id: f2.requester_id,
      target_id: f2.target_id,
      status: f2.status
    }

    assert_push "request_cancelled", ^expected_cancel
    assert_push "request_cancelled", ^expected_cancel
  end

  test "user channel receives friend_blocked, unblocked and removed events" do
    a = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
    b = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

    {:ok, token_a, _} = Guardian.encode_and_sign(a)
    {:ok, token_b, _} = Guardian.encode_and_sign(b)

    {:ok, socket_a} = connect(GameServerWeb.UserSocket, %{"token" => token_a})
    {:ok, socket_b} = connect(GameServerWeb.UserSocket, %{"token" => token_b})

    {:ok, _, _socket_a} = subscribe_and_join(socket_a, "user:#{a.id}", %{})
    {:ok, _, _socket_b} = subscribe_and_join(socket_b, "user:#{b.id}", %{})

    # a -> b then block as b
    {:ok, f} = GameServer.Friends.create_request(a.id, b.id)
    assert {:ok, blocked} = GameServer.Friends.block_friend_request(f.id, b)

    expected_block = %{
      id: blocked.id,
      requester_id: blocked.requester_id,
      target_id: blocked.target_id,
      status: blocked.status
    }

    assert_push "friend_blocked", ^expected_block
    assert_push "friend_blocked", ^expected_block

    # unblock as b
    assert {:ok, :unblocked} = GameServer.Friends.unblock_friendship(blocked.id, b)
    # The original blocked record is deleted during unblock, but unblock_friendship broadcasts
    # a friend_unblocked event with the friendship that was removed
    assert_push "friend_unblocked", ^expected_block
    assert_push "friend_unblocked", ^expected_block

    # create accepted friend and then remove
    {:ok, f2} = GameServer.Friends.create_request(a.id, b.id)
    {:ok, accepted} = GameServer.Friends.accept_friend_request(f2.id, b)

    assert {:ok, _} = GameServer.Friends.remove_friend(a.id, b.id)

    expected_removed = %{
      id: accepted.id,
      requester_id: accepted.requester_id,
      target_id: accepted.target_id,
      status: accepted.status
    }

    assert_push "friend_removed", ^expected_removed
    assert_push "friend_removed", ^expected_removed
  end

  test "join rejected for another user" do
    user = AccountsFixtures.user_fixture()
    other = AccountsFixtures.user_fixture()
    {:ok, token2, _} = Guardian.encode_and_sign(other)

    {:ok, socket2} = connect(GameServerWeb.UserSocket, %{"token" => token2})
    require ExUnit.CaptureLog

    # the channel logs a warning when an unauthorized join is attempted; capture
    # that log in the test so it doesn't show up as noisy output
    ExUnit.CaptureLog.capture_log(fn ->
      assert {:error, _} = subscribe_and_join(socket2, "user:#{user.id}", %{})
    end)
  end

  test "user channel receives updated event when linking a provider" do
    # Create a user with a password and google_id (so we can link another provider)
    user = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

    {:ok, token, _} = Guardian.encode_and_sign(user)
    {:ok, socket} = connect(GameServerWeb.UserSocket, %{"token" => token})
    {:ok, _, _socket} = subscribe_and_join(socket, "user:#{user.id}", %{})

    # Link discord provider to the user
    {:ok, updated_user} =
      GameServer.Accounts.link_account(
        user,
        %{discord_id: "123456789"},
        :discord_id,
        &GameServer.Accounts.User.discord_oauth_changeset/2
      )

    # Should receive updated event
    assert_push "updated", payload
    assert payload.id == updated_user.id
  end

  test "user channel receives updated event when unlinking a provider" do
    # Create a user then add multiple providers so we can unlink one
    user = AccountsFixtures.user_fixture()

    # Use link_account to add providers
    {:ok, user} =
      GameServer.Accounts.link_account(
        user,
        %{google_id: "google123"},
        :google_id,
        &GameServer.Accounts.User.google_oauth_changeset/2
      )

    {:ok, user} =
      GameServer.Accounts.link_account(
        user,
        %{discord_id: "discord456"},
        :discord_id,
        &GameServer.Accounts.User.discord_oauth_changeset/2
      )

    {:ok, token, _} = Guardian.encode_and_sign(user)
    {:ok, socket} = connect(GameServerWeb.UserSocket, %{"token" => token})
    {:ok, _, _socket} = subscribe_and_join(socket, "user:#{user.id}", %{})

    # Unlink discord provider
    {:ok, updated_user} = GameServer.Accounts.unlink_provider(user, :discord)

    # Should receive updated event
    assert_push "updated", payload
    assert payload.id == updated_user.id
  end
end
