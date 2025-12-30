defmodule GameServerWeb.Api.V1.Admin.PluginsAdminControllerTest do
  use GameServerWeb.ConnCase, async: false

  alias GameServer.Accounts
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

  test "GET /api/v1/admin/plugins/buildable returns list", %{conn: conn, admin: admin} do
    conn = conn |> bearer_conn(admin)

    conn = get(conn, "/api/v1/admin/plugins/buildable")
    assert %{"data" => data} = json_response(conn, 200)
    assert is_list(data)
  end
end
