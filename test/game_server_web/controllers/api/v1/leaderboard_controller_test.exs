defmodule GameServerWeb.Api.V1.LeaderboardControllerTest do
  use GameServerWeb.ConnCase

  alias GameServer.AccountsFixtures
  alias GameServer.Leaderboards
  alias GameServerWeb.Auth.Guardian

  describe "GET /api/v1/leaderboards" do
    test "lists all leaderboards with pagination", %{conn: conn} do
      for i <- 1..3 do
        Leaderboards.create_leaderboard(%{id: "lb_#{i}", title: "Leaderboard #{i}"})
      end

      conn = get(conn, "/api/v1/leaderboards")
      resp = json_response(conn, 200)

      assert length(resp["data"]) == 3
      assert resp["meta"]["total_count"] == 3
      assert resp["meta"]["page"] == 1
    end

    test "paginates results", %{conn: conn} do
      for i <- 1..5 do
        Leaderboards.create_leaderboard(%{id: "lb_page_#{i}", title: "Leaderboard #{i}"})
      end

      conn = get(conn, "/api/v1/leaderboards", %{page: 1, page_size: 2})
      resp = json_response(conn, 200)

      assert length(resp["data"]) == 2
      assert resp["meta"]["total_count"] == 5
      assert resp["meta"]["total_pages"] == 3
      assert resp["meta"]["has_more"] == true
    end

    test "filters by active", %{conn: conn} do
      {:ok, active} = Leaderboards.create_leaderboard(%{id: "active_filter", title: "Active"})
      {:ok, ended} = Leaderboards.create_leaderboard(%{id: "ended_filter", title: "Ended"})
      Leaderboards.end_leaderboard(ended)

      conn = get(conn, "/api/v1/leaderboards", %{active: "true"})
      resp = json_response(conn, 200)

      ids = Enum.map(resp["data"], & &1["id"])
      assert active.id in ids
      refute ended.id in ids
    end

    test "includes all leaderboard fields", %{conn: conn} do
      {:ok, _} =
        Leaderboards.create_leaderboard(%{
          id: "full_fields",
          title: "Full Fields",
          description: "A description",
          sort_order: :asc,
          operator: :incr,
          metadata: %{"prize" => "Badge"}
        })

      conn = get(conn, "/api/v1/leaderboards")
      resp = json_response(conn, 200)
      lb = hd(resp["data"])

      assert lb["id"] == "full_fields"
      assert lb["title"] == "Full Fields"
      assert lb["description"] == "A description"
      assert lb["sort_order"] == "asc"
      assert lb["operator"] == "incr"
      assert lb["metadata"] == %{"prize" => "Badge"}
    end
  end

  describe "GET /api/v1/leaderboards/:id" do
    test "returns a single leaderboard", %{conn: conn} do
      {:ok, lb} = Leaderboards.create_leaderboard(%{id: "single_lb", title: "Single"})

      conn = get(conn, "/api/v1/leaderboards/#{lb.id}")
      resp = json_response(conn, 200)

      assert resp["data"]["id"] == lb.id
      assert resp["data"]["title"] == "Single"
    end

    test "returns 404 for non-existent leaderboard", %{conn: conn} do
      conn = get(conn, "/api/v1/leaderboards/nonexistent")
      assert json_response(conn, 404)
    end
  end

  describe "GET /api/v1/leaderboards/:id/records" do
    setup do
      {:ok, lb} = Leaderboards.create_leaderboard(%{id: "records_lb", title: "Records"})

      users =
        for i <- 1..5 do
          user = AccountsFixtures.user_fixture()
          Leaderboards.submit_score(lb.id, user.id, i * 100)
          user
        end

      %{leaderboard: lb, users: users}
    end

    test "returns records with ranks", %{conn: conn, leaderboard: lb} do
      conn = get(conn, "/api/v1/leaderboards/#{lb.id}/records")
      resp = json_response(conn, 200)

      assert length(resp["data"]) == 5
      # First record should have rank 1 and highest score (500)
      first = hd(resp["data"])
      assert first["rank"] == 1
      assert first["score"] == 500
    end

    test "paginates records", %{conn: conn, leaderboard: lb} do
      conn = get(conn, "/api/v1/leaderboards/#{lb.id}/records", %{page: 1, page_size: 2})
      resp = json_response(conn, 200)

      assert length(resp["data"]) == 2
      assert resp["meta"]["total_count"] == 5
      assert resp["meta"]["has_more"] == true
    end

    test "includes user display info", %{conn: conn, leaderboard: lb} do
      conn = get(conn, "/api/v1/leaderboards/#{lb.id}/records")
      resp = json_response(conn, 200)

      first = hd(resp["data"])
      assert Map.has_key?(first, "user_id")
      assert Map.has_key?(first, "display_name")
      assert Map.has_key?(first, "profile_url")
    end

    test "returns 404 for non-existent leaderboard", %{conn: conn} do
      conn = get(conn, "/api/v1/leaderboards/nonexistent/records")
      assert json_response(conn, 404)
    end
  end

  describe "GET /api/v1/leaderboards/:id/records/around/:user_id" do
    setup do
      {:ok, lb} = Leaderboards.create_leaderboard(%{id: "around_lb", title: "Around"})

      users =
        for i <- 1..10 do
          user = AccountsFixtures.user_fixture()
          Leaderboards.submit_score(lb.id, user.id, i * 100)
          user
        end

      %{leaderboard: lb, users: users}
    end

    test "returns records around the user", %{conn: conn, leaderboard: lb, users: users} do
      target_user = Enum.at(users, 4)

      conn = get(conn, "/api/v1/leaderboards/#{lb.id}/records/around/#{target_user.id}")
      resp = json_response(conn, 200)

      # Should include the target user
      assert Enum.any?(resp["data"], fn r -> r["user_id"] == target_user.id end)
    end

    test "respects limit parameter", %{conn: conn, leaderboard: lb, users: users} do
      target_user = Enum.at(users, 4)

      conn =
        get(conn, "/api/v1/leaderboards/#{lb.id}/records/around/#{target_user.id}", %{limit: 1})

      resp = json_response(conn, 200)

      # With limit 1, should get 1 above + user + 1 below = 3 max
      assert length(resp["data"]) <= 3
    end

    test "returns 404 for non-existent leaderboard", %{conn: conn} do
      conn = get(conn, "/api/v1/leaderboards/nonexistent/records/around/1")
      assert json_response(conn, 404)
    end

    test "returns empty for user without record", %{conn: conn, leaderboard: lb} do
      user = AccountsFixtures.user_fixture()

      conn = get(conn, "/api/v1/leaderboards/#{lb.id}/records/around/#{user.id}")
      resp = json_response(conn, 200)

      assert resp["data"] == []
    end
  end

  describe "GET /api/v1/leaderboards/:id/records/me" do
    setup do
      {:ok, lb} = Leaderboards.create_leaderboard(%{id: "me_lb", title: "Me"})

      users =
        for i <- 1..5 do
          user = AccountsFixtures.user_fixture()
          Leaderboards.submit_score(lb.id, user.id, i * 100)
          user
        end

      %{leaderboard: lb, users: users}
    end

    test "requires authentication", %{conn: conn, leaderboard: lb} do
      conn = get(conn, "/api/v1/leaderboards/#{lb.id}/records/me")
      assert conn.status == 401
    end

    test "returns the current user's record with rank", %{
      conn: conn,
      leaderboard: lb,
      users: users
    } do
      # User with score 300
      user = Enum.at(users, 2)
      {:ok, token, _} = Guardian.encode_and_sign(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> token)
        |> get("/api/v1/leaderboards/#{lb.id}/records/me")

      resp = json_response(conn, 200)

      assert resp["data"]["user_id"] == user.id
      assert resp["data"]["score"] == 300
      assert resp["data"]["rank"] == 3
    end

    test "returns 404 for user without record", %{conn: conn, leaderboard: lb} do
      user = AccountsFixtures.user_fixture()
      {:ok, token, _} = Guardian.encode_and_sign(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> token)
        |> get("/api/v1/leaderboards/#{lb.id}/records/me")

      resp = json_response(conn, 404)
      assert resp["error"] == "No record found for this user"
    end

    test "returns 404 for non-existent leaderboard", %{conn: conn} do
      user = AccountsFixtures.user_fixture()
      {:ok, token, _} = Guardian.encode_and_sign(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> token)
        |> get("/api/v1/leaderboards/nonexistent/records/me")

      assert json_response(conn, 404)
    end
  end
end
