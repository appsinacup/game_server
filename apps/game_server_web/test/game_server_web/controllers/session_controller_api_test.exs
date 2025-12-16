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

    test "refresh works without Authorization header (happy path)", %{conn: conn} do
      # create a user and set password
      user =
        GameServer.AccountsFixtures.user_fixture() |> GameServer.AccountsFixtures.set_password()

      # login to get a refresh token
      login_resp =
        post(conn, "/api/v1/login", %{
          email: user.email,
          password: GameServer.AccountsFixtures.valid_user_password()
        })

      assert login_resp.status == 200
      refresh_token = json_response(login_resp, 200)["data"]["refresh_token"]

      # call refresh without Authorization header
      resp = post(conn, "/api/v1/refresh", %{refresh_token: refresh_token})
      assert resp.status == 200
      body = json_response(resp, 200)

      assert is_binary(body["data"]["access_token"]) and
               byte_size(body["data"]["access_token"]) > 0

      assert body["data"]["expires_in"] == 900
    end
  end
end
