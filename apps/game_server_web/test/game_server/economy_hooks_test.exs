defmodule GameServer.EconomyHooksTest do
  use GameServer.DataCase, async: false

  alias GameServer.Economy
  alias GameServer.Inventory

  defmodule Hook do
    use GameServerWeb.TestSupport.NoopHooks

    @impl true
    def after_wallet_changed(change) do
      if pid = Application.get_env(:game_server_core, :test_econ_pid),
        do: send(pid, {:wallet, change})

      :ok
    end

    @impl true
    def after_inventory_changed(change) do
      if pid = Application.get_env(:game_server_core, :test_econ_pid),
        do: send(pid, {:inv, change})

      :ok
    end
  end

  setup do
    orig = Application.get_env(:game_server_core, :hooks_module)
    Application.put_env(:game_server_core, :test_econ_pid, self())
    Application.put_env(:game_server_core, :hooks_module, Hook)

    on_exit(fn ->
      Application.put_env(:game_server_core, :hooks_module, orig)
      Application.delete_env(:game_server_core, :test_econ_pid)
    end)

    %{user: GameServer.AccountsFixtures.user_fixture()}
  end

  test "after_wallet_changed fires on grant", %{user: user} do
    Economy.grant(user.id, "gold", 42, reason: "reward")
    assert_receive {:wallet, %{currency: "gold", balance: 42, delta: 42, reason: "reward"}}, 1000
  end

  test "after_inventory_changed fires on grant_item", %{user: user} do
    Inventory.grant_item(user.id, "potion", 3)
    assert_receive {:inv, %{item: "potion", quantity: 3, delta: 3}}, 1000
  end
end
