defmodule GameServerWeb.Api.V1.Admin.AchievementControllerTest do
  use GameServerWeb.ConnCase, async: false

  alias GameServer.Accounts
  alias GameServer.Achievements
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

  test "POST /api/v1/admin/achievements creates achievement", %{conn: conn, admin: admin} do
    conn =
      conn
      |> bearer_conn(admin)
      |> post("/api/v1/admin/achievements", %{
        "slug" => "admin_ach",
        "title" => "Admin Achievement",
        "points" => 50,
        "progress_target" => 1
      })

    resp = json_response(conn, 201)
    assert resp["data"]["slug"] == "admin_ach"
    assert resp["data"]["title"] == "Admin Achievement"
    assert resp["data"]["points"] == 50
  end

  test "POST /api/v1/admin/achievements returns errors for invalid data", %{
    conn: conn,
    admin: admin
  } do
    conn =
      conn
      |> bearer_conn(admin)
      |> post("/api/v1/admin/achievements", %{})

    assert json_response(conn, 422)["errors"] != %{}
  end

  test "PATCH /api/v1/admin/achievements/:id updates achievement", %{
    conn: conn,
    admin: admin
  } do
    {:ok, ach} = Achievements.create_achievement(%{slug: "patch_me", title: "Original"})

    conn =
      conn
      |> bearer_conn(admin)
      |> patch("/api/v1/admin/achievements/#{ach.id}", %{"title" => "Updated"})

    resp = json_response(conn, 200)
    assert resp["data"]["title"] == "Updated"
  end

  test "DELETE /api/v1/admin/achievements/:id deletes achievement", %{
    conn: conn,
    admin: admin
  } do
    {:ok, ach} = Achievements.create_achievement(%{slug: "delete_admin", title: "Delete Me"})

    conn =
      conn
      |> bearer_conn(admin)
      |> delete("/api/v1/admin/achievements/#{ach.id}")

    assert json_response(conn, 200)["message"] =~ "deleted"
    assert Achievements.get_achievement(ach.id) == nil
  end

  test "POST /api/v1/admin/achievements/grant grants to user", %{conn: conn, admin: admin} do
    user = GameServer.AccountsFixtures.user_fixture()
    {:ok, _} = Achievements.create_achievement(%{slug: "grant_admin", title: "Grant"})

    conn =
      conn
      |> bearer_conn(admin)
      |> post("/api/v1/admin/achievements/grant", %{
        "user_id" => user.id,
        "slug" => "grant_admin"
      })

    resp = json_response(conn, 200)
    assert resp["data"]["unlocked_at"] != nil
  end

  test "POST /api/v1/admin/achievements/revoke revokes from user", %{
    conn: conn,
    admin: admin
  } do
    user = GameServer.AccountsFixtures.user_fixture()
    {:ok, ach} = Achievements.create_achievement(%{slug: "revoke_admin", title: "Revoke"})
    {:ok, _} = Achievements.unlock_achievement(user.id, "revoke_admin")

    conn =
      conn
      |> bearer_conn(admin)
      |> post("/api/v1/admin/achievements/revoke", %{
        "user_id" => user.id,
        "achievement_id" => ach.id
      })

    assert json_response(conn, 200)["message"] =~ "revoked"
  end

  test "requires admin auth", %{conn: conn} do
    user = GameServer.AccountsFixtures.user_fixture()

    conn =
      conn
      |> bearer_conn(user)
      |> post("/api/v1/admin/achievements", %{
        "slug" => "no_admin",
        "title" => "No Admin"
      })

    assert conn.status in [401, 403]
  end
end
