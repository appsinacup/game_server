defmodule GameServerWeb.Api.V1.Admin.TournamentsAdminControllerTest do
  use GameServerWeb.ConnCase, async: false

  alias GameServer.Accounts
  alias GameServer.Tournaments
  alias GameServerWeb.Auth.Guardian

  defp bearer_conn(conn, user) do
    {:ok, token, _} = Guardian.encode_and_sign(user)
    put_req_header(conn, "authorization", "Bearer " <> token)
  end

  setup %{conn: conn} do
    user = GameServer.AccountsFixtures.user_fixture()
    {:ok, admin} = Accounts.update_user(user, %{is_admin: true})

    %{admin_conn: bearer_conn(conn, admin), admin: admin}
  end

  defp create_attrs do
    %{
      "slug" => "admin-cup-#{System.unique_integer([:positive])}",
      "title" => "Admin Cup",
      "starts_at" => DateTime.utc_now(:second) |> DateTime.add(3600) |> DateTime.to_iso8601(),
      "round_window_sec" => 600
    }
  end

  test "full admin lifecycle over HTTP: create, update, draw, resolve, finish", %{
    admin_conn: admin_conn
  } do
    resp = admin_conn |> post("/api/v1/admin/tournaments", create_attrs()) |> json_response(200)
    assert %{"id" => id, "state" => "scheduled"} = resp["data"]

    resp =
      admin_conn
      |> patch("/api/v1/admin/tournaments/#{id}", %{"title" => "Renamed"})
      |> json_response(200)

    assert resp["data"]["title"] == "Renamed"

    # Two entries so the draw produces a match.
    tournament = Tournaments.get_tournament(id)

    for _ <- 1..2 do
      {:ok, _} =
        Tournaments.join_tournament(
          GameServer.AccountsFixtures.user_fixture(),
          Tournaments.advance_lifecycle(tournament)
        )
    end

    resp = admin_conn |> post("/api/v1/admin/tournaments/#{id}/draw") |> json_response(200)
    assert resp["data"]["state"] == "running"

    [match] = Tournaments.list_matches(id)

    resp =
      admin_conn
      |> post("/api/v1/admin/tournaments/#{id}/matches/#{match.id}/resolve", %{
        "winner_entry_id" => match.a_entry_id
      })
      |> json_response(200)

    assert resp["winner_entry_id"] == match.a_entry_id

    # Champion decided -> the tournament already finished; finish reports 400.
    resp = admin_conn |> post("/api/v1/admin/tournaments/#{id}/finish") |> json_response(400)
    assert resp["error"] == "not_running"

    assert Tournaments.get_tournament(id).state == "finished"
  end

  test "resolve without a winner records a double forfeit", %{admin_conn: admin_conn} do
    resp = admin_conn |> post("/api/v1/admin/tournaments", create_attrs()) |> json_response(200)
    id = resp["data"]["id"]

    tournament = Tournaments.get_tournament(id)

    for _ <- 1..2 do
      {:ok, _} =
        Tournaments.join_tournament(
          GameServer.AccountsFixtures.user_fixture(),
          Tournaments.advance_lifecycle(tournament)
        )
    end

    _ = admin_conn |> post("/api/v1/admin/tournaments/#{id}/draw") |> json_response(200)
    [match] = Tournaments.list_matches(id)

    resp =
      admin_conn
      |> post("/api/v1/admin/tournaments/#{id}/matches/#{match.id}/resolve", %{})
      |> json_response(200)

    assert resp["winner_entry_id"] == nil

    resp =
      admin_conn
      |> post("/api/v1/admin/tournaments/#{id}/matches/#{match.id}/resolve", %{
        "winner_entry_id" => match.a_entry_id
      })
      |> json_response(400)

    assert resp["error"] == "already_resolved"
  end

  test "cancel and delete", %{admin_conn: admin_conn} do
    resp = admin_conn |> post("/api/v1/admin/tournaments", create_attrs()) |> json_response(200)
    id = resp["data"]["id"]

    resp = admin_conn |> post("/api/v1/admin/tournaments/#{id}/cancel") |> json_response(200)
    assert resp["data"]["state"] == "cancelled"

    resp = admin_conn |> delete("/api/v1/admin/tournaments/#{id}") |> json_response(200)
    assert resp["ok"] == true
    assert Tournaments.get_tournament(id) == nil
  end

  test "cancel then reopen over HTTP", %{admin_conn: admin_conn} do
    resp = admin_conn |> post("/api/v1/admin/tournaments", create_attrs()) |> json_response(200)
    id = resp["data"]["id"]

    resp = admin_conn |> post("/api/v1/admin/tournaments/#{id}/cancel") |> json_response(200)
    assert resp["data"]["state"] == "cancelled"

    resp = admin_conn |> post("/api/v1/admin/tournaments/#{id}/reopen") |> json_response(200)
    assert resp["data"]["state"] == "registration"

    # reopening something that is not cancelled is rejected
    resp = admin_conn |> post("/api/v1/admin/tournaments/#{id}/reopen") |> json_response(400)
    assert resp["error"] == "not_cancelled"
  end

  test "validation errors surface as 422", %{admin_conn: admin_conn} do
    resp =
      admin_conn
      |> post("/api/v1/admin/tournaments", %{"slug" => "bad"})
      |> json_response(422)

    assert resp["error"] == "invalid_data"
    assert resp["errors"]["title"]
  end

  test "non-admins are rejected", %{conn: conn} do
    user = GameServer.AccountsFixtures.user_fixture()

    assert conn
           |> bearer_conn(user)
           |> post("/api/v1/admin/tournaments", create_attrs())
           |> response(403)
  end
end
