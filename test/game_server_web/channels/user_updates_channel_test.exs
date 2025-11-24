defmodule GameServerWeb.UserUpdatesChannelTest do
  use ExUnit.Case
  import Phoenix.ChannelTest

  alias GameServerWeb.Auth.Guardian
  alias GameServer.AccountsFixtures

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
    {:ok, _, _socket} = subscribe_and_join(socket, "user_updates:#{user.id}", %{})

    payload = %{id: user.id, metadata: %{"display_name" => "Updated"}}

    GameServerWeb.Endpoint.broadcast("user_updates:#{user.id}", "metadata_updated", payload)

    # The test process receives the push
    assert_push "metadata_updated", ^payload
  end

  test "join rejected for another user" do
    user = AccountsFixtures.user_fixture()
    other = AccountsFixtures.user_fixture()
    {:ok, token2, _} = Guardian.encode_and_sign(other)

    {:ok, socket2} = connect(GameServerWeb.UserSocket, %{"token" => token2})
    assert {:error, _} = subscribe_and_join(socket2, "user_updates:#{user.id}", %{})
  end
end
