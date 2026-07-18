defmodule GameServer.LobbyScopedKvTest do
  @moduledoc """
  Per-member lobby state lives in KV scoped to (user_id, lobby_id). It belongs
  to the membership, so leaving or being kicked must clear it — otherwise a
  rejoin silently restores stale state such as a ready flag.
  """
  use GameServer.DataCase

  alias GameServer.AccountsFixtures
  alias GameServer.KV
  alias GameServer.Lobbies

  defp lobby_with_members(count) do
    [host | rest] = users = for _ <- 1..count, do: AccountsFixtures.user_fixture()
    # create_lobby/1 already seats the host.
    {:ok, lobby} = Lobbies.create_lobby(%{title: "t", host_id: host.id, max_users: 8})

    for user <- rest do
      {:ok, _} = Lobbies.join_lobby(user, lobby.id)
    end

    {lobby, users}
  end

  defp ready!(user, lobby, value) do
    KV.put("ready", %{"value" => value}, %{}, user_id: user.id, lobby_id: lobby.id)
  end

  defp ready(user, lobby) do
    case KV.get("ready", user_id: user.id, lobby_id: lobby.id) do
      {:ok, %{value: value}} -> value
      :error -> nil
    end
  end

  test "leaving a lobby clears that member's lobby-scoped entries" do
    {lobby, [user | _]} = lobby_with_members(2)
    ready!(user, lobby, true)
    assert ready(user, lobby) == %{"value" => true}

    {:ok, _} = Lobbies.leave_lobby(user)

    assert ready(user, lobby) == nil
  end

  test "rejoining does not restore a stale ready flag" do
    {lobby, [user | _]} = lobby_with_members(2)
    ready!(user, lobby, true)
    {:ok, _} = Lobbies.leave_lobby(user)

    {:ok, _} = Lobbies.join_lobby(Repo.reload(user), lobby.id)

    assert ready(user, lobby) == nil
  end

  test "being kicked clears the member's entries" do
    {lobby, [host, target | _]} = lobby_with_members(2)
    ready!(target, lobby, true)

    {:ok, _} = Lobbies.kick_user(host, lobby, target)

    assert ready(target, lobby) == nil
  end

  test "another member's entries survive one member leaving" do
    {lobby, [leaver, stayer | _]} = lobby_with_members(2)
    ready!(leaver, lobby, true)
    ready!(stayer, lobby, true)

    {:ok, _} = Lobbies.leave_lobby(leaver)

    assert ready(leaver, lobby) == nil
    assert ready(stayer, lobby) == %{"value" => true}
  end

  test "lobby-wide and user-global entries are untouched" do
    {lobby, [user | _]} = lobby_with_members(2)
    ready!(user, lobby, true)
    KV.put("map", %{"value" => "dust2"}, %{}, lobby_id: lobby.id)
    KV.put("coins", %{"value" => 10}, %{}, user_id: user.id)

    {:ok, _} = Lobbies.leave_lobby(user)

    assert ready(user, lobby) == nil
    assert {:ok, %{value: %{"value" => "dust2"}}} = KV.get("map", lobby_id: lobby.id)
    assert {:ok, %{value: %{"value" => 10}}} = KV.get("coins", user_id: user.id)
  end

  test "leaving with no lobby-scoped entries is a no-op" do
    {_lobby, [user | _]} = lobby_with_members(2)
    assert {:ok, _} = Lobbies.leave_lobby(user)
  end
end
