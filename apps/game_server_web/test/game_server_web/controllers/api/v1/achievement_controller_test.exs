defmodule GameServerWeb.Api.V1.AchievementControllerTest do
  use GameServerWeb.ConnCase

  alias GameServer.AccountsFixtures
  alias GameServer.Achievements
  alias GameServerWeb.Auth.Guardian

  defp auth_conn(conn, user) do
    {:ok, token, _} = Guardian.encode_and_sign(user)
    put_req_header(conn, "authorization", "Bearer " <> token)
  end

  defp create_achievement(attrs \\ %{}) do
    defaults = %{slug: "ach_#{System.unique_integer([:positive])}", title: "Test"}
    {:ok, ach} = Achievements.create_achievement(Map.merge(defaults, attrs))
    ach
  end

  describe "GET /api/v1/achievements" do
    test "lists achievements with pagination", %{conn: conn} do
      for i <- 1..3 do
        create_achievement(%{slug: "list_#{i}", title: "Ach #{i}"})
      end

      conn = get(conn, "/api/v1/achievements")
      resp = json_response(conn, 200)

      assert length(resp["data"]) == 3
      assert resp["meta"]["total_count"] == 3
      assert resp["meta"]["page"] == 1
    end

    test "paginates results", %{conn: conn} do
      for i <- 1..5 do
        create_achievement(%{slug: "page_#{i}", title: "Ach #{i}"})
      end

      conn = get(conn, "/api/v1/achievements", %{page: 1, page_size: 2})
      resp = json_response(conn, 200)

      assert length(resp["data"]) == 2
      assert resp["meta"]["total_count"] == 5
      assert resp["meta"]["has_more"] == true
    end

    test "excludes hidden achievements", %{conn: conn} do
      create_achievement(%{slug: "visible_api", hidden: false})
      create_achievement(%{slug: "hidden_api", hidden: true})

      conn = get(conn, "/api/v1/achievements")
      resp = json_response(conn, 200)

      slugs = Enum.map(resp["data"], & &1["slug"])
      assert "visible_api" in slugs
      refute "hidden_api" in slugs
    end

    test "includes zero progress for unauthenticated requests", %{conn: conn} do
      create_achievement(%{slug: "with_prog", progress_target: 10})

      conn = get(conn, "/api/v1/achievements")

      resp = json_response(conn, 200)
      item = Enum.find(resp["data"], &(&1["slug"] == "with_prog"))
      assert item["progress"] == 0
      assert item["unlocked_at"] == nil
    end

    test "includes achievement fields", %{conn: conn} do
      create_achievement(%{
        slug: "full_fields_api",
        title: "Full",
        description: "Desc",
        progress_target: 5,
        hidden: false
      })

      conn = get(conn, "/api/v1/achievements")
      resp = json_response(conn, 200)
      item = hd(resp["data"])

      assert item["slug"] == "full_fields_api"
      assert item["title"] == "Full"
      assert item["description"] == "Desc"
      assert item["progress_target"] == 5
    end
  end

  describe "GET /api/v1/achievements/:slug" do
    test "returns a single achievement by slug", %{conn: conn} do
      ach = create_achievement(%{slug: "show_slug", title: "Show Me"})

      conn = get(conn, "/api/v1/achievements/show_slug")
      resp = json_response(conn, 200)

      assert resp["data"]["slug"] == "show_slug"
      assert resp["data"]["title"] == "Show Me"
    end

    test "returns 404 for non-existent slug", %{conn: conn} do
      conn = get(conn, "/api/v1/achievements/nonexistent")
      assert json_response(conn, 404)
    end
  end

  describe "GET /api/v1/achievements/me" do
    test "returns authenticated user's unlocked achievements", %{conn: conn} do
      user = AccountsFixtures.user_fixture()
      ach = create_achievement(%{slug: "my_ach"})
      {:ok, _} = Achievements.unlock_achievement(user.id, "my_ach")

      conn =
        conn
        |> auth_conn(user)
        |> get("/api/v1/achievements/me")

      resp = json_response(conn, 200)
      assert length(resp["data"]) == 1
      assert hd(resp["data"])["slug"] == "my_ach"
    end

    test "requires authentication", %{conn: conn} do
      conn = get(conn, "/api/v1/achievements/me")
      assert conn.status == 401
    end
  end

  describe "GET /api/v1/achievements/user/:user_id" do
    test "returns another user's unlocked achievements", %{conn: conn} do
      user = AccountsFixtures.user_fixture()
      create_achievement(%{slug: "their_ach"})
      {:ok, _} = Achievements.unlock_achievement(user.id, "their_ach")

      conn = get(conn, "/api/v1/achievements/user/#{user.id}")
      resp = json_response(conn, 200)

      assert length(resp["data"]) == 1
    end
  end
end
