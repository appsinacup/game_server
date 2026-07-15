defmodule GameServerWeb.Api.V1.UserControllerTest do
  use GameServerWeb.ConnCase

  alias GameServer.Accounts

  import GameServer.AccountsFixtures

  test "GET /api/v1/users returns search results", %{conn: conn} do
    a = user_fixture(%{email: "search-me@example.com"})
    {:ok, a} = Accounts.update_user_display_name(a, %{"display_name" => "SearchMe"})

    conn = get(conn, "/api/v1/users", %{q: "Search"})
    assert conn.status == 200

    resp = json_response(conn, 200)
    assert is_map(resp)
    assert is_list(resp["data"])
    assert Enum.any?(resp["data"], fn r -> r["id"] == a.id end)
    assert Enum.all?(resp["data"], fn r -> not Map.has_key?(r, "email") end)
  end

  test "GET /api/v1/users does not search by email", %{conn: conn} do
    user = user_fixture(%{email: "hidden-search@example.com"})
    {:ok, _user} = Accounts.update_user_display_name(user, %{"display_name" => "VisibleName"})

    conn = get(conn, "/api/v1/users", %{q: "hidden-search"})
    resp = json_response(conn, 200)

    assert resp["data"] == []
    assert resp["meta"]["total_count"] == 0
  end

  test "search pagination returns total_count and total_pages", %{conn: conn} do
    # create 3 matching users
    for email <- ["many1@example.com", "many2@example.com", "other@example.com"] do
      user = user_fixture(%{email: email})
      {:ok, _user} = Accounts.update_user_display_name(user, %{"display_name" => "Many"})
    end

    # page 1, size 2
    conn1 = get(conn, "/api/v1/users", %{q: "Many", page: 1, page_size: 2})
    resp1 = json_response(conn1, 200)
    assert length(resp1["data"]) == 2

    expected_total = GameServer.Accounts.count_search_users("Many")
    assert resp1["meta"]["total_count"] == expected_total
    assert resp1["meta"]["total_pages"] == div(expected_total + 2 - 1, 2)

    # page 2 should have the remaining results (could be 0..1 depending on fixtures)
    conn2 = get(conn, "/api/v1/users", %{q: "Many", page: 2, page_size: 2})
    resp2 = json_response(conn2, 200)
    remaining = max(0, expected_total - 2)
    assert length(resp2["data"]) == remaining
    assert resp2["meta"]["total_count"] == expected_total
    assert resp2["meta"]["total_pages"] == div(expected_total + 2 - 1, 2)
  end

  test "GET /api/v1/users/:id returns user info", %{conn: conn} do
    u = user_fixture(%{email: "foo-user@example.com"})
    {:ok, u} = Accounts.update_user_display_name(u, %{"display_name" => "FooUser"})

    conn = get(conn, "/api/v1/users/#{u.id}")
    assert conn.status == 200
    resp = json_response(conn, 200)
    assert resp["id"] == u.id
    refute Map.has_key?(resp, "email")
    assert Map.has_key?(resp, "lobby_id")
    assert resp["lobby_id"] == ""
    assert resp["last_seen_at"] == "1970-01-01T00:00:00Z"
  end

  test "GET /api/v1/users/:id returns 404 if not found", %{conn: conn} do
    conn = get(conn, "/api/v1/users/00000000-0000-0000-0000-000000000000")
    assert conn.status == 404
  end
end
