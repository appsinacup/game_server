defmodule GameServerWeb.Auth.PipelineTest do
  use GameServerWeb.ConnCase

  alias GameServerWeb.Auth.Guardian

  describe "JWT authentication pipeline" do
    test "allows access with valid JWT token", %{conn: conn} do
      user = GameServer.AccountsFixtures.user_fixture()
      {:ok, token, _claims} = Guardian.encode_and_sign(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> token)
        |> get("/api/v1/me")

      assert json_response(conn, 200)
    end

    test "denies access without token", %{conn: conn} do
      conn = get(conn, "/api/v1/me")

      assert json_response(conn, 401)
      assert %{"error" => _message} = json_response(conn, 401)
    end

    test "denies access with malformed token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer invalid.token.here")
        |> get("/api/v1/me")

      assert json_response(conn, 401)
    end

    test "denies access with missing Bearer prefix", %{conn: conn} do
      user = GameServer.AccountsFixtures.user_fixture()
      {:ok, token, _claims} = Guardian.encode_and_sign(user)

      conn =
        conn
        |> put_req_header("authorization", token)
        |> get("/api/v1/me")

      assert json_response(conn, 401)
    end

    test "assigns current_scope from JWT token", %{conn: conn} do
      user = GameServer.AccountsFixtures.user_fixture()
      {:ok, token, _claims} = Guardian.encode_and_sign(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> token)
        |> get("/api/v1/me")

      body = json_response(conn, 200)
      assert body["id"] == user.id
      assert body["email"] == user.email
    end
  end
end
