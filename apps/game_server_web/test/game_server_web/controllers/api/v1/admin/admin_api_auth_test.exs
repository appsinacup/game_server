defmodule GameServerWeb.Api.V1.Admin.AdminApiAuthTest do
  use GameServerWeb.ConnCase, async: false

  alias GameServer.Accounts
  alias GameServerWeb.Auth.Guardian

  defp bearer_conn(conn, user) do
    {:ok, token, _} = Guardian.encode_and_sign(user)
    put_req_header(conn, "authorization", "Bearer " <> token)
  end

  test "admin endpoints require authentication", %{conn: conn} do
    conn = get(conn, "/api/v1/admin/kv/entries")
    assert %{"error" => _} = json_response(conn, 401)
  end

  test "admin endpoints require admin role", %{conn: conn} do
    # The Accounts context auto-promotes the very first user in the DB to admin.
    # Ensure the user under test is not the first-created user.
    _first_user = GameServer.AccountsFixtures.user_fixture()

    user = GameServer.AccountsFixtures.user_fixture()
    assert user.is_admin == false
    conn = conn |> bearer_conn(user)

    conn = get(conn, "/api/v1/admin/kv/entries")
    assert %{"error" => "forbidden"} = json_response(conn, 403)
  end

  test "admin endpoints allow admin users", %{conn: conn} do
    user = GameServer.AccountsFixtures.user_fixture()
    {:ok, admin} = Accounts.update_user(user, %{is_admin: true})

    conn = conn |> bearer_conn(admin)

    conn = get(conn, "/api/v1/admin/kv/entries")
    assert %{"data" => _, "meta" => _} = json_response(conn, 200)
  end
end
