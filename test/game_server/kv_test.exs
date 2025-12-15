defmodule GameServer.KVTest do
  use GameServer.DataCase, async: true

  alias GameServer.AccountsFixtures
  alias GameServer.KV

  test "put/get/update and delete" do
    user = AccountsFixtures.user_fixture()

    assert :error == KV.get("polyglot_pirates:key1")

    assert {:ok, _row} =
             KV.put("polyglot_pirates:key1", %{"a" => 1}, %{"plugin" => "polyglot_pirates"})

    assert {:ok, %{value: %{"a" => 1}, metadata: %{"plugin" => "polyglot_pirates"}}} =
             KV.get("polyglot_pirates:key1")

    assert {:ok, _row} =
             KV.put("polyglot_pirates:key1", %{"a" => 2}, %{"plugin" => "polyglot_pirates"},
               user_id: user.id
             )

    assert {:ok, %{value: %{"a" => 2}, metadata: %{"plugin" => "polyglot_pirates"}}} =
             KV.get("polyglot_pirates:key1", user_id: user.id)

    # Deleting the global entry doesn't affect the per-user one.
    assert :ok = KV.delete("polyglot_pirates:key1")
    assert :error == KV.get("polyglot_pirates:key1")
    assert {:ok, _} = KV.get("polyglot_pirates:key1", user_id: user.id)

    assert :ok = KV.delete("polyglot_pirates:key1", user_id: user.id)
    assert :error == KV.get("polyglot_pirates:key1", user_id: user.id)
  end
end
