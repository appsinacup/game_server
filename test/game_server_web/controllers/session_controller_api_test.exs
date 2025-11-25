defmodule GameServerWeb.SessionControllerApiTest do
  use GameServerWeb.ConnCase, async: true

  describe "POST /api/v1/refresh" do
    test "returns 400 when refresh_token missing", %{conn: conn} do
      conn = post(conn, "/api/v1/refresh", %{})

      assert conn.status == 400
      assert json_response(conn, 400)["error"] == "refresh_token is required"
    end

    test "returns 401 when refresh_token invalid", %{conn: conn} do
      conn = post(conn, "/api/v1/refresh", %{refresh_token: "invalid-token"})

      assert conn.status == 401

      assert json_response(conn, 401)["error"] in [
               "Invalid or expired refresh token",
               "Invalid refresh token"
             ]
    end
  end
end
