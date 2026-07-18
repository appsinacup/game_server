defmodule GameServerWeb.Api.V1.TournamentControllerTest do
  use GameServerWeb.ConnCase, async: false

  alias GameServer.AccountsFixtures
  alias GameServer.Tournaments
  alias GameServerWeb.Auth.Guardian

  setup %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    {:ok, access, _} = Guardian.encode_and_sign(user)

    {:ok, tournament} =
      Tournaments.create_tournament(%{
        slug: "api-cup-#{System.unique_integer([:positive])}",
        title: "API Cup",
        category: "ranked",
        starts_at: DateTime.add(DateTime.utc_now(:second), 3600),
        round_window_sec: 600
      })

    %{
      conn: conn,
      user: user,
      tournament: tournament,
      auth_conn: put_req_header(conn, "authorization", "Bearer " <> access)
    }
  end

  test "GET /api/v1/tournaments lists and filters", %{conn: conn, tournament: tournament} do
    resp = conn |> get("/api/v1/tournaments") |> json_response(200)
    assert Enum.any?(resp["data"], &(&1["id"] == tournament.id))

    resp = conn |> get("/api/v1/tournaments?category=ranked") |> json_response(200)
    assert Enum.any?(resp["data"], &(&1["id"] == tournament.id))

    resp = conn |> get("/api/v1/tournaments?category=other") |> json_response(200)
    refute Enum.any?(resp["data"], &(&1["id"] == tournament.id))
  end

  test "GET /api/v1/tournaments/:id works by id and by slug", %{
    conn: conn,
    tournament: tournament
  } do
    resp = conn |> get("/api/v1/tournaments/#{tournament.id}") |> json_response(200)
    assert resp["data"]["slug"] == tournament.slug
    assert resp["data"]["state"] == "registration"
    assert resp["data"]["my_entry"] == nil

    resp = conn |> get("/api/v1/tournaments/#{tournament.slug}") |> json_response(200)
    assert resp["data"]["id"] == tournament.id

    assert conn |> get("/api/v1/tournaments/#{Ecto.UUID.generate()}") |> json_response(404)
  end

  test "join/leave lifecycle over the API", %{auth_conn: auth_conn, tournament: tournament} do
    resp = auth_conn |> post("/api/v1/tournaments/#{tournament.id}/join") |> json_response(200)
    assert resp["ok"] == true
    assert resp["entry"]["state"] == "registered"

    resp = auth_conn |> get("/api/v1/tournaments/#{tournament.id}") |> json_response(200)
    assert resp["data"]["my_entry"]["state"] == "registered"
    assert resp["data"]["entry_count"] == 1

    resp =
      auth_conn |> post("/api/v1/tournaments/#{tournament.id}/join") |> json_response(400)

    assert resp["error"] == "already_registered"

    resp = auth_conn |> delete("/api/v1/tournaments/#{tournament.id}/join") |> json_response(200)
    assert resp["ok"] == true
  end

  test "join requires authentication", %{conn: conn, tournament: tournament} do
    assert conn |> post("/api/v1/tournaments/#{tournament.id}/join") |> response(401)
  end

  test "bracket, standings and my-match after a draw", %{
    auth_conn: auth_conn,
    conn: conn,
    user: user,
    tournament: tournament
  } do
    opponent = AccountsFixtures.user_fixture()
    {:ok, _} = Tournaments.join_tournament(user, tournament)
    {:ok, _} = Tournaments.join_tournament(opponent, tournament)

    {:ok, tournament} =
      Tournaments.update_tournament(tournament, %{starts_at: DateTime.utc_now(:second)})

    tournament = Tournaments.advance_lifecycle(tournament)
    assert tournament.state == "running"

    resp = conn |> get("/api/v1/tournaments/#{tournament.id}/bracket") |> json_response(200)
    assert [%{"index" => 0, "size" => 2}] = resp["data"]["brackets"]
    assert [match] = resp["data"]["matches"]
    assert match["a_leader_id"] && match["b_leader_id"]

    resp = auth_conn |> get("/api/v1/tournaments/#{tournament.id}/my-match") |> json_response(200)
    assert resp["data"]["id"] == match["id"]

    {:ok, _} = Tournaments.resolve_match(match["id"], match["a_entry_id"])

    resp = conn |> get("/api/v1/tournaments/#{tournament.id}/standings") |> json_response(200)
    assert [champion] = resp["data"]["champions"]
    assert champion["state"] == "winner"
    assert [%{"placement" => 1} | _] = resp["data"]["entries"]
  end
end
