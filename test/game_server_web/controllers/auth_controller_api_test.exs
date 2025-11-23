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

  describe "API callback linking when authenticated" do
    test "links provider to current user when authorized", %{conn: conn} do
      user = user_fixture()

      # mock exchanger to return a discord id not used by others
      mock = %{
        exchange_discord_code: fn _code, _client_id, _secret, _redirect ->
          {:ok, %{"id" => "discord-new", "avatar" => "a.png", "email" => user.email}}
        end
      }

      mod = Module.concat([GameServerWeb, :AuthTestMockExchanger])

      defmodule(mod) do
        def exchange_discord_code(code, _a, _b, _c) do
          case code do
            "OK_CODE" -> {:ok, %{"id" => "discord-new", "avatar" => "a.png", "email" => nil}}
            other -> {:error, other}
          end
        end
      end

      Application.put_env(:game_server, :oauth_exchanger, mod)

      {:ok, token, _claims} = Guardian.encode_and_sign(user, %{}, token_type: "access")

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/v1/auth/discord/callback?code=OK_CODE")

      assert json_response(conn, 200)["data"]["user"]["id"] == user.id

      # ensure DB is updated
      user = Accounts.get_user!(user.id)
      assert user.discord_id == "discord-new"
    end

    test "returns conflict when discord id attached to another account", %{conn: conn} do
      current = user_fixture()
      other = user_fixture()

      other =
        GameServer.Repo.update!(Ecto.Changeset.change(other, %{discord_id: "discord-conflict"}))

      mod = Module.concat([GameServerWeb, :AuthTestMockExchanger2])

      defmodule(mod) do
        def exchange_discord_code(_code, _a, _b, _c) do
          {:ok, %{"id" => "discord-conflict", "email" => nil}}
        end
      end

      Application.put_env(:game_server, :oauth_exchanger, mod)

      {:ok, token, _claims} = Guardian.encode_and_sign(current, %{}, token_type: "access")

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/v1/auth/discord/callback?code=CONFLICT_CODE")

      assert json_response(conn, 409)["error"] == "conflict"
      assert json_response(conn, 409)["conflict_user_id"] == other.id
    end

    test "links provider to current user when authorized (google)", %{conn: conn} do
      user = user_fixture()

      mod = Module.concat([GameServerWeb, :AuthTestMockExchangerGoogle])

      defmodule(mod) do
        def exchange_google_code(code, _a, _b, _c) do
          case code do
            "OK_G" -> {:ok, %{"id" => "g_new", "email" => nil}}
            other -> {:error, other}
          end
        end
      end

      Application.put_env(:game_server, :oauth_exchanger, mod)

      {:ok, token, _claims} = Guardian.encode_and_sign(user, %{}, token_type: "access")

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/v1/auth/google/callback?code=OK_G")

      assert json_response(conn, 200)["data"]["user"]["id"] == user.id

      user = Accounts.get_user!(user.id)
      assert user.google_id == "g_new"
    end

    test "returns conflict when google id is attached to another account", %{conn: conn} do
      current = user_fixture()
      other = user_fixture()
      other = GameServer.Repo.update!(Ecto.Changeset.change(other, %{google_id: "g_conflict"}))

      mod = Module.concat([GameServerWeb, :AuthTestMockExchangerGoogle2])

      defmodule(mod) do
        def exchange_google_code(_code, _a, _b, _c) do
          {:ok, %{"id" => "g_conflict", "email" => nil}}
        end
      end

      Application.put_env(:game_server, :oauth_exchanger, mod)

      {:ok, token, _claims} = Guardian.encode_and_sign(current, %{}, token_type: "access")

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/v1/auth/google/callback?code=CONFLICT_G")

      assert json_response(conn, 409)["error"] == "conflict"
      assert json_response(conn, 409)["conflict_user_id"] == other.id
    end

    test "links provider to current user when authorized (facebook)", %{conn: conn} do
      user = user_fixture()

      mod = Module.concat([GameServerWeb, :AuthTestMockExchangerFacebook])

      defmodule(mod) do
        def exchange_facebook_code(code, _a, _b, _c) do
          case code do
            "OK_F" -> {:ok, %{"id" => "f_new", "email" => nil}}
            other -> {:error, other}
          end
        end
      end

      Application.put_env(:game_server, :oauth_exchanger, mod)

      {:ok, token, _claims} = Guardian.encode_and_sign(user, %{}, token_type: "access")

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/v1/auth/facebook/callback?code=OK_F")

      assert json_response(conn, 200)["data"]["user"]["id"] == user.id

      user = Accounts.get_user!(user.id)
      assert user.facebook_id == "f_new"
    end

    test "returns conflict when facebook id is attached to another account", %{conn: conn} do
      current = user_fixture()
      other = user_fixture()
      other = GameServer.Repo.update!(Ecto.Changeset.change(other, %{facebook_id: "f_conflict"}))

      mod = Module.concat([GameServerWeb, :AuthTestMockExchangerFacebook2])

      defmodule(mod) do
        def exchange_facebook_code(_code, _a, _b, _c) do
          {:ok, %{"id" => "f_conflict", "email" => nil}}
        end
      end

      Application.put_env(:game_server, :oauth_exchanger, mod)

      {:ok, token, _claims} = Guardian.encode_and_sign(current, %{}, token_type: "access")

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get(~p"/api/v1/auth/facebook/callback?code=CONFLICT_F")

      assert json_response(conn, 409)["error"] == "conflict"
      assert json_response(conn, 409)["conflict_user_id"] == other.id
    end
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

      assert json_response(resp, 200)["message"] == "deleted"
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
end
