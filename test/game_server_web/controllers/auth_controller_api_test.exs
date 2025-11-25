defmodule GameServerWeb.AuthControllerApiTest do
  use GameServerWeb.ConnCase, async: true

  alias GameServer.Accounts
  alias GameServerWeb.Auth.Guardian

  import GameServer.AccountsFixtures

  setup do
    # allow tests to inject a mock exchanger
    orig = Application.get_env(:game_server, :oauth_exchanger)

    on_exit(fn -> Application.put_env(:game_server, :oauth_exchanger, orig) end)

    :ok
  end

  describe "POST /api/v1/auth/:provider/conflict-delete" do
    test "deletes provider-only conflicting account", %{conn: conn} do
      current = user_fixture()
      other = user_fixture(%{discord_id: "d_conflict"})

      {:ok, token, _} = Guardian.encode_and_sign(current, %{}, token_type: "access")

      resp =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/v1/auth/discord/conflict-delete?conflict_user_id=#{other.id}")

      assert response(resp, 204)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(other.id) end
    end

    test "cannot delete an account you do not own (forbidden)", %{conn: conn} do
      current = user_fixture()
      other = user_fixture()
      other = GameServer.AccountsFixtures.set_password(other)
      other = GameServer.Repo.update!(Ecto.Changeset.change(other, %{discord_id: "d_conf"}))

      {:ok, token, _} = Guardian.encode_and_sign(current, %{}, token_type: "access")

      resp =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/v1/auth/discord/conflict-delete?conflict_user_id=#{other.id}")

      assert resp.status == 400
      assert json_response(resp, 400)["error"] == "Cannot delete an account you do not own"
    end

    test "cannot delete your own logged-in account", %{conn: conn} do
      current = user_fixture()

      {:ok, token, _} = Guardian.encode_and_sign(current, %{}, token_type: "access")

      resp =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/v1/auth/discord/conflict-delete?conflict_user_id=#{current.id}")

      assert resp.status == 400
      assert json_response(resp, 400)["error"] == "Cannot delete your own logged-in account"
    end

    test "invalid id returns bad request", %{conn: conn} do
      current = user_fixture()
      {:ok, token, _} = Guardian.encode_and_sign(current, %{}, token_type: "access")

      resp =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post(~p"/api/v1/auth/discord/conflict-delete?conflict_user_id=abc")

      assert resp.status == 400
      assert json_response(resp, 400)["error"] == "invalid id"
    end
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
  end
end
