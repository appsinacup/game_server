defmodule GameServerWeb.Api.V1.MatchmakingControllerTest do
  use GameServerWeb.ConnCase, async: false

  alias GameServer.AccountsFixtures
  alias GameServer.Matchmaking
  alias GameServerWeb.Auth.Guardian

  setup do
    user = AccountsFixtures.user_fixture()
    {:ok, token, _} = Guardian.encode_and_sign(user)
    conn = build_conn() |> put_req_header("authorization", "Bearer " <> token)
    {:ok, conn: conn, user: user}
  end

  describe "POST /api/v1/matchmaking/tickets" do
    test "creates a queued ticket", %{conn: conn} do
      body = %{"match_params" => %{"mode" => "duel"}, "min_players" => 2, "max_players" => 4}
      conn = post(conn, "/api/v1/matchmaking/tickets", body)

      assert %{"data" => data} = json_response(conn, 201)
      assert data["status"] == "queued"
      assert data["match_params"] == %{"mode" => "duel"}
      assert data["min_players"] == 2
      assert data["max_players"] == 4
    end

    test "defaults min/max when omitted", %{conn: conn} do
      conn = post(conn, "/api/v1/matchmaking/tickets", %{})
      assert %{"data" => %{"min_players" => 2, "max_players" => 5}} = json_response(conn, 201)
    end

    test "rejects invalid player bounds", %{conn: conn} do
      body = %{"min_players" => 5, "max_players" => 2}
      conn = post(conn, "/api/v1/matchmaking/tickets", body)

      assert %{"error" => "invalid_data", "errors" => %{"max_players" => _}} =
               json_response(conn, 422)
    end

    test "requires authentication" do
      conn = post(build_conn(), "/api/v1/matchmaking/tickets", %{})
      assert json_response(conn, 401)
    end
  end

  describe "DELETE /api/v1/matchmaking/tickets" do
    test "cancels the caller's queued tickets", %{conn: conn, user: user} do
      {:ok, _} = Matchmaking.join(user, %{"mode" => "duel"})

      conn = delete(conn, "/api/v1/matchmaking/tickets")
      assert %{"data" => %{"cancelled" => 1}} = json_response(conn, 200)
      assert Matchmaking.current_ticket(user.id) == nil
    end

    test "is a no-op when not queued", %{conn: conn} do
      conn = delete(conn, "/api/v1/matchmaking/tickets")
      assert %{"data" => %{"cancelled" => 0}} = json_response(conn, 200)
    end
  end

  describe "GET /api/v1/matchmaking/tickets/me" do
    test "returns the queued ticket", %{conn: conn, user: user} do
      {:ok, ticket} = Matchmaking.join(user, %{"mode" => "duel"})

      conn = get(conn, "/api/v1/matchmaking/tickets/me")
      assert %{"data" => %{"id" => id, "status" => "queued"}} = json_response(conn, 200)
      assert id == ticket.id
    end

    test "returns null when not in the queue", %{conn: conn} do
      conn = get(conn, "/api/v1/matchmaking/tickets/me")
      assert %{"data" => nil} = json_response(conn, 200)
    end
  end

  describe "GET /api/v1/matchmaking/stats" do
    test "returns queue depths without lifetime counters", %{conn: conn, user: user} do
      {:ok, _} = Matchmaking.join(user, %{"mode" => "duel"})

      conn = get(conn, "/api/v1/matchmaking/stats")
      assert %{"data" => data} = json_response(conn, 200)
      assert data["queued"] == 1
      assert [%{"params" => %{"mode" => "duel"}, "waiting" => 1}] = data["queues"]
      refute Map.has_key?(data, "matched")
      refute Map.has_key?(data, "cancelled")
    end
  end
end
