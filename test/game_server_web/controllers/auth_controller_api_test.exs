defmodule GameServerWeb.AuthControllerApiTest do
  use GameServerWeb.ConnCase, async: true

  setup do
    # allow tests to inject a mock exchanger
    orig = Application.get_env(:game_server, :oauth_exchanger)

    on_exit(fn -> Application.put_env(:game_server, :oauth_exchanger, orig) end)

    :ok
  end

  describe "GET /api/v1/auth/session/:session_id" do
    test "returns 404 for missing session id", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/auth/session/nonexistent-id")

      assert conn.status == 404
      assert json_response(conn, 404)["error"] == "session_not_found"
    end

    test "empty session path returns 400 (router)", %{conn: conn} do
      resp = get(conn, "/api/v1/auth/session/")

      assert resp.status == 400
    end
  end

  describe "GET /api/v1/auth/:provider API request" do
    test "unknown provider returns 400", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/auth/invalid-provider")

      assert conn.status == 400
      assert json_response(conn, 400)["error"] == "invalid_provider"
    end

    test "steam returns OpenID URL and session id", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/auth/steam")

      assert conn.status == 200

      body = json_response(conn, 200)

      assert is_binary(body["authorization_url"]) and
               String.contains?(body["authorization_url"], "steamcommunity.com/openid/login")

      assert is_binary(body["session_id"]) and byte_size(body["session_id"]) > 0

      # server should have created a pending session record
      session = GameServer.OAuthSessions.get_session(body["session_id"])
      assert session != nil
      assert session.provider == "steam"
      assert session.status == "pending"
    end
  end
end
