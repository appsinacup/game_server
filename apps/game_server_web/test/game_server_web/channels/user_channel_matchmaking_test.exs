defmodule GameServerWeb.UserChannelMatchmakingTest do
  use ExUnit.Case, async: false

  import Phoenix.ChannelTest

  alias GameServer.AccountsFixtures
  alias GameServer.Matchmaking
  alias GameServer.Matchmaking.Worker
  alias GameServerWeb.Auth.Guardian

  @endpoint GameServerWeb.Endpoint

  setup tags do
    GameServer.DataCase.setup_sandbox(tags)
    :ok
  end

  defp join_user_channel(user) do
    {:ok, token, _claims} = Guardian.encode_and_sign(user)
    {:ok, socket} = connect(GameServerWeb.UserSocket, %{"token" => token})
    {:ok, _, socket} = subscribe_and_join(socket, "user:#{user.id}", %{})
    # drain the on-join profile push
    assert_push "updated", _user_payload
    socket
  end

  defp user_fixture, do: AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()

  test "matched players receive match_found on their user channel" do
    alice = user_fixture()
    bob = user_fixture()

    _alice_socket = join_user_channel(alice)
    _bob_socket = join_user_channel(bob)

    {:ok, _} = Matchmaking.join(alice, %{"mode" => "duel"}, 2, 2)
    {:ok, _} = Matchmaking.join(bob, %{"mode" => "duel"}, 2, 2)

    assert Worker.sweep() == 1

    assert_push "match_found", %{lobby_id: lobby_id, match_params: %{"mode" => "duel"}}
    assert is_binary(lobby_id)
  end

  test "matchmaking:join is no longer a channel push (moved to HTTP)" do
    socket = join_user_channel(user_fixture())

    ref = push(socket, "matchmaking:join", %{"match_params" => %{"mode" => "duel"}})
    assert_reply ref, :error, %{error: "unknown_event"}

    ref = push(socket, "matchmaking:cancel", %{})
    assert_reply ref, :error, %{error: "unknown_event"}
  end

  test "socket disconnect cancels the user's queued tickets" do
    user = user_fixture()
    socket = join_user_channel(user)

    {:ok, _} = Matchmaking.join(user, %{"mode" => "duel"})
    assert Matchmaking.current_ticket(user.id) != nil

    Process.unlink(socket.channel_pid)
    close(socket)

    assert Matchmaking.current_ticket(user.id) == nil
  end
end
