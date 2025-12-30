defmodule GameServerWeb.Api.V1.Admin.LeaderboardsAdminControllerTest do
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

  test "POST /api/v1/admin/leaderboards creates leaderboard", %{conn: conn, admin: admin} do
    conn = conn |> bearer_conn(admin)

    conn =
      post(conn, "/api/v1/admin/leaderboards", %{
        "slug" => "admin_test_lb",
        "title" => "Admin Test"
      })

    assert %{"data" => %{"id" => id, "slug" => "admin_test_lb"}} = json_response(conn, 200)
    assert is_integer(id)
  end
end
