defmodule GameServerWeb.Api.V1.MeControllerTest do
  use GameServerWeb.ConnCase

  alias GameServer.Accounts

  describe "GET /api/v1/me" do
    test "returns 401 when not authenticated", %{conn: conn} do
      conn = get(conn, "/api/v1/me")
      assert json_response(conn, 401)
    end

    test "returns user info when authenticated", %{conn: conn} do
      user = GameServer.AccountsFixtures.user_fixture()

      token = Accounts.generate_user_session_token(user)
      encoded = Base.url_encode64(token, padding: false)

      conn = conn |> put_req_header("authorization", "Bearer " <> encoded) |> get("/api/v1/me")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == user.id
      assert data["email"] == user.email
      assert Map.has_key?(data, "is_admin")
      assert Map.has_key?(data, "metadata")
    end
  end
end
