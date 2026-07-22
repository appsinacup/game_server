defmodule GameServer.InventoryTest do
  use GameServer.DataCase, async: true

  alias GameServer.Inventory

  setup do
    %{user: GameServer.AccountsFixtures.user_fixture()}
  end

  test "grant_item accumulates and consume_item subtracts", %{user: user} do
    assert {:ok, 3} = Inventory.grant_item(user.id, "health_potion", 3)
    assert {:ok, 5} = Inventory.grant_item(user.id, "health_potion", 2)
    assert {:ok, 4} = Inventory.consume_item(user.id, "health_potion", 1)
    assert Inventory.quantity(user.id, "health_potion") == 4
  end

  test "consume refuses to go below zero", %{user: user} do
    Inventory.grant_item(user.id, "sword", 1)
    assert {:error, :insufficient_items} = Inventory.consume_item(user.id, "sword", 2)
    assert Inventory.quantity(user.id, "sword") == 1
  end

  test "consuming an item the user lacks fails", %{user: user} do
    assert {:error, :insufficient_items} = Inventory.consume_item(user.id, "nope", 1)
  end

  test "inventory/1 lists held items", %{user: user} do
    Inventory.grant_item(user.id, "gold_bar", 2)
    Inventory.grant_item(user.id, "gem", 10)
    assert Inventory.inventory(user.id) == %{"gold_bar" => 2, "gem" => 10}
  end

  test "invalid item code rejected", %{user: user} do
    assert {:error, :invalid_item} = Inventory.grant_item(user.id, "", 1)
  end

  test "set_metadata stores per-stack metadata", %{user: user} do
    Inventory.grant_item(user.id, "sword", 1)

    assert {:ok, %{"enchant" => "fire"}} =
             Inventory.set_metadata(user.id, "sword", %{"enchant" => "fire"})

    assert [%{metadata: %{"enchant" => "fire"}}] = Inventory.list_items(user_id: user.id)
  end

  test "broadcasts inventory_updated to subscribers", %{user: user} do
    Inventory.subscribe(user.id)
    assert {:ok, 3} = Inventory.grant_item(user.id, "potion", 3)
    assert_receive {:inventory_updated, %{item: "potion", quantity: 3, delta: 3}}
  end
end
