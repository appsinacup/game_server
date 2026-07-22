defmodule GameServerWeb.Api.V1.EconomyControllerTest do
  use GameServerWeb.ConnCase, async: true

  alias GameServer.Economy
  alias GameServerWeb.Auth.Guardian

  setup %{conn: conn} do
    user = GameServer.AccountsFixtures.user_fixture()
    {:ok, token, _} = Guardian.encode_and_sign(user)
    %{conn: put_req_header(conn, "authorization", "Bearer " <> token), user: user}
  end

  test "GET /me/wallet requires auth" do
    assert json_response(get(build_conn(), "/api/v1/me/wallet"), 401)
  end

  test "GET /me/wallet returns balances", %{conn: conn, user: user} do
    Economy.grant(user.id, "gold", 100)
    Economy.grant(user.id, "gems", 5)

    assert %{"data" => %{"gold" => 100, "gems" => 5}} =
             json_response(get(conn, "/api/v1/me/wallet"), 200)
  end

  test "GET /me/wallet/ledger returns the user's history", %{conn: conn, user: user} do
    Economy.grant(user.id, "gold", 100, reason: "reward")
    Economy.spend(user.id, "gold", 40, reason: "store")

    body = json_response(get(conn, "/api/v1/me/wallet/ledger"), 200)
    assert body["meta"]["total_count"] == 2
    assert [%{"delta" => -40} | _] = body["data"]
  end

  test "GET /me/inventory returns item quantities", %{conn: conn, user: user} do
    GameServer.Inventory.grant_item(user.id, "potion", 3)
    assert %{"data" => %{"potion" => 3}} = json_response(get(conn, "/api/v1/me/inventory"), 200)
  end
end
