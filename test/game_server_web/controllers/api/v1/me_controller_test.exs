defmodule GameServerWeb.Api.V1.MeControllerTest do
  use GameServerWeb.ConnCase

  alias GameServerWeb.Auth.Guardian

  describe "GET /api/v1/me" do
    test "returns 401 when not authenticated", %{conn: conn} do
      conn = get(conn, "/api/v1/me")
      assert json_response(conn, 401)
    end

    test "returns user info when authenticated", %{conn: conn} do
      user = GameServer.AccountsFixtures.user_fixture()

      {:ok, token, _claims} = Guardian.encode_and_sign(user)

      conn = conn |> put_req_header("authorization", "Bearer " <> token) |> get("/api/v1/me")

      body = json_response(conn, 200)
      assert body["id"] == user.id
      assert body["email"] == user.email
      refute Map.has_key?(body, "is_admin")
      assert Map.has_key?(body, "metadata")
    end
  end
end
