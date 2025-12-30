defmodule GameServerWeb.Api.V1.Admin.KvAdminControllerTest do
  use GameServerWeb.ConnCase, async: false

  alias GameServer.Accounts
  alias GameServer.KV
  alias GameServerWeb.Auth.Guardian

  defp bearer_conn(conn, user) do
    {:ok, token, _} = Guardian.encode_and_sign(user)
    put_req_header(conn, "authorization", "Bearer " <> token)
  end

  setup do
    user = GameServer.AccountsFixtures.user_fixture()
    {:ok, admin} = Accounts.update_user(user, %{is_admin: true})

    {:ok, admin: admin}
  end

  test "PUT /api/v1/admin/kv upserts and returns entry", %{conn: conn, admin: admin} do
    conn = conn |> bearer_conn(admin)

    conn = put(conn, "/api/v1/admin/kv", %{"key" => "test:key", "value" => %{"a" => 1}})
    assert %{"data" => %{"key" => "test:key", "value" => %{"a" => 1}}} = json_response(conn, 200)

    # ensure it exists
    assert {:ok, %{value: %{"a" => 1}}} = KV.get("test:key")
  end
end
