defmodule GameServerWeb.Api.V1.LeaderboardControllerTest do
  use GameServerWeb.ConnCase

  alias GameServer.AccountsFixtures
  alias GameServer.Leaderboards
  alias GameServerWeb.Auth.Guardian

  describe "GET /api/v1/leaderboards" do
    test "lists all leaderboards with pagination", %{conn: conn} do
      for i <- 1..3 do
        Leaderboards.create_leaderboard(%{slug: "lb_#{i}", title: "Leaderboard #{i}"})
      end

      conn = get(conn, "/api/v1/leaderboards")
      resp = json_response(conn, 200)

      assert length(resp["data"]) == 3
      assert resp["meta"]["total_count"] == 3
      assert resp["meta"]["page"] == 1
    end

    test "paginates results", %{conn: conn} do
      for i <- 1..5 do
        Leaderboards.create_leaderboard(%{slug: "lb_page_#{i}", title: "Leaderboard #{i}"})
      end

      conn = get(conn, "/api/v1/leaderboards", %{page: 1, page_size: 2})
      resp = json_response(conn, 200)

      assert length(resp["data"]) == 2
      assert resp["meta"]["total_count"] == 5
      assert resp["meta"]["total_pages"] == 3
      assert resp["meta"]["has_more"] == true
    end

    test "filters by active", %{conn: conn} do
      {:ok, active} = Leaderboards.create_leaderboard(%{slug: "active_filter", title: "Active"})
      {:ok, ended} = Leaderboards.create_leaderboard(%{slug: "ended_filter", title: "Ended"})
      Leaderboards.end_leaderboard(ended)

      conn = get(conn, "/api/v1/leaderboards", %{active: "true"})
      resp = json_response(conn, 200)

      ids = Enum.map(resp["data"], & &1["id"])
      assert active.id in ids
      refute ended.id in ids
    end

    test "includes all leaderboard fields", %{conn: conn} do
      {:ok, lb} =
        Leaderboards.create_leaderboard(%{
          slug: "full_fields",
          title: "Full Fields",
          description: "A description",
          sort_order: :asc,
          operator: :incr,
          metadata: %{"prize" => "Badge"}
        })

      conn = get(conn, "/api/v1/leaderboards")
      resp = json_response(conn, 200)
      lb_resp = hd(resp["data"])

      assert lb_resp["id"] == lb.id
      assert lb_resp["slug"] == "full_fields"
      assert lb_resp["title"] == "Full Fields"
      assert lb_resp["description"] == "A description"
      assert lb_resp["sort_order"] == "asc"
      assert lb_resp["operator"] == "incr"
      assert lb_resp["metadata"] == %{"prize" => "Badge"}
    end
  end

  describe "GET /api/v1/leaderboards/:id" do
    test "returns a single leaderboard", %{conn: conn} do
      {:ok, lb} = Leaderboards.create_leaderboard(%{slug: "single_lb", title: "Single"})

      conn = get(conn, "/api/v1/leaderboards/#{lb.id}")
      resp = json_response(conn, 200)

      assert resp["data"]["id"] == lb.id
      assert resp["data"]["slug"] == "single_lb"
      assert resp["data"]["title"] == "Single"
    end

    test "returns 404 for non-existent leaderboard", %{conn: conn} do
      conn = get(conn, "/api/v1/leaderboards/999999")
      assert json_response(conn, 404)
    end
  end

  describe "GET /api/v1/leaderboards with slug filter" do
    test "returns all leaderboards with a given slug", %{conn: conn} do
      {:ok, lb1} = Leaderboards.create_leaderboard(%{slug: "seasonal", title: "Season 1"})
      {:ok, lb2} = Leaderboards.create_leaderboard(%{slug: "seasonal", title: "Season 2"})
      {:ok, _other} = Leaderboards.create_leaderboard(%{slug: "other", title: "Other"})

      conn = get(conn, "/api/v1/leaderboards?slug=seasonal")
      resp = json_response(conn, 200)

      assert length(resp["data"]) == 2
      ids = Enum.map(resp["data"], & &1["id"])
      assert lb1.id in ids
      assert lb2.id in ids
    end

    test "returns empty list for non-existent slug", %{conn: conn} do
      conn = get(conn, "/api/v1/leaderboards?slug=nonexistent")
      resp = json_response(conn, 200)

      assert resp["data"] == []
    end

    test "can filter by slug and active status", %{conn: conn} do
      {:ok, active} = Leaderboards.create_leaderboard(%{slug: "mixed", title: "Active"})
      {:ok, ended} = Leaderboards.create_leaderboard(%{slug: "mixed", title: "Ended"})
      Leaderboards.end_leaderboard(ended)

      conn = get(conn, "/api/v1/leaderboards?slug=mixed&active=true")
      resp = json_response(conn, 200)

      assert length(resp["data"]) == 1
      assert hd(resp["data"])["id"] == active.id
    end
  end

  describe "GET /api/v1/leaderboards with time filters" do
    test "filters by starts_after", %{conn: conn} do
      past = DateTime.add(DateTime.utc_now(), -3600, :second)
      future = DateTime.add(DateTime.utc_now(), 3600, :second)

      {:ok, past_lb} =
        Leaderboards.create_leaderboard(%{slug: "past", title: "Past", starts_at: past})

      {:ok, _future_lb} =
        Leaderboards.create_leaderboard(%{slug: "future", title: "Future", starts_at: future})

      # Get leaderboards starting after now - should only get future one
      now_iso = DateTime.to_iso8601(DateTime.utc_now())
      conn = get(conn, "/api/v1/leaderboards?starts_after=#{now_iso}")
      resp = json_response(conn, 200)

      refute Enum.any?(resp["data"], &(&1["id"] == past_lb.id))
    end

    test "filters by ends_before", %{conn: conn} do
      past = DateTime.add(DateTime.utc_now(), -3600, :second)
      future = DateTime.add(DateTime.utc_now(), 3600, :second)

      {:ok, _past_end} =
        Leaderboards.create_leaderboard(%{slug: "past_end", title: "Past End", ends_at: past})

      {:ok, future_end} =
        Leaderboards.create_leaderboard(%{
          slug: "future_end",
          title: "Future End",
          ends_at: future
        })

      # Get leaderboards ending before now - should not include future_end
      now_iso = DateTime.to_iso8601(DateTime.utc_now())
      conn = get(conn, "/api/v1/leaderboards?ends_before=#{now_iso}")
      resp = json_response(conn, 200)

      refute Enum.any?(resp["data"], &(&1["id"] == future_end.id))
    end
  end

  describe "GET /api/v1/leaderboards/:id/records" do
    setup do
      {:ok, lb} = Leaderboards.create_leaderboard(%{slug: "records_lb", title: "Records"})

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
      conn = get(conn, "/api/v1/leaderboards/999999/records")
      assert json_response(conn, 404)
    end
  end

  describe "GET /api/v1/leaderboards/:id/records/around/:user_id" do
    setup do
      {:ok, lb} = Leaderboards.create_leaderboard(%{slug: "around_lb", title: "Around"})

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
      conn = get(conn, "/api/v1/leaderboards/999999/records/around/1")
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
      {:ok, lb} = Leaderboards.create_leaderboard(%{slug: "me_lb", title: "Me"})

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
        |> get("/api/v1/leaderboards/999999/records/me")

      assert json_response(conn, 404)
    end
  end
end
