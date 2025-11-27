defmodule GameServerWeb.AuthControllerTest do
  use GameServerWeb.ConnCase, async: true

  alias GameServer.OAuthSessions

  test "request redirects to provider (discord)", %{conn: conn} do
    old = System.get_env("DISCORD_CLIENT_ID")
    System.put_env("DISCORD_CLIENT_ID", "cid-123")

    on_exit(fn -> if old, do: System.put_env("DISCORD_CLIENT_ID", old) end)

    conn = get(conn, "/auth/discord")
    assert redirected_to(conn) =~ "https://discord.com/oauth2/authorize"
    assert redirected_to(conn) =~ "client_id=cid-123"
  end

  test "callback (discord) on error with state creates oauth session", %{conn: conn} do
    orig = Application.get_env(:game_server, :oauth_exchanger)

    defmodule TestExchanger do
      def exchange_discord_code(_code, _client_id, _secret, _redirect), do: {:error, :boom}
    end

    Application.put_env(:game_server, :oauth_exchanger, TestExchanger)

    on_exit(fn -> Application.put_env(:game_server, :oauth_exchanger, orig) end)

    session_id = "session-#{System.unique_integer([:positive])}"

    conn = get(conn, "/auth/discord/callback?code=abc&state=#{session_id}")

    # session should be created with error status
    sess = OAuthSessions.get_session(session_id)
    assert sess.status == "error"
  end

  test "callback (discord) success browser and api flows", %{conn: conn} do
    orig = Application.get_env(:game_server, :oauth_exchanger)

    defmodule TestExchanger.SuccessDiscord do
      def exchange_discord_code(_code, _client_id, _secret, _redirect) do
        {:ok, %{"id" => "d123", "email" => "d@example.com", "username" => "duser"}}
      end
    end

    Application.put_env(:game_server, :oauth_exchanger, TestExchanger.SuccessDiscord)

    on_exit(fn -> Application.put_env(:game_server, :oauth_exchanger, orig) end)

    # browser flow (no state) should login / redirect
    conn1 = get(conn, "/auth/discord/callback?code=abc")
    assert redirected_to(conn1) =~ "/"

    # api flow with state should create a completed session
    session_id = "sid-#{System.unique_integer([:positive])}"
    conn2 = get(conn, "/auth/discord/callback?code=abc&state=#{session_id}")

    session = OAuthSessions.get_session(session_id)
    assert session.status == "completed"
  end

  test "callback (google, facebook) success browser flows", %{conn: conn} do
    orig = Application.get_env(:game_server, :oauth_exchanger)

    defmodule TestExchanger.SuccessGoogle do
      def exchange_google_code(_code, _client_id, _secret, _redirect) do
        {:ok, %{"id" => "g123", "email" => "g@example.com", "picture" => "https://img/1.png", "name" => "Gname"}}
      end
    end

    defmodule TestExchanger.SuccessFacebook do
      def exchange_facebook_code(_code, _client_id, _secret, _redirect) do
        {:ok, %{"id" => "fb123", "email" => "fb@example.com", "picture" => %{"data" => %{"url" => "https://fb/img.png"}}, "name" => "Fb name"}}
      end
    end

    # google browser flow
    Application.put_env(:game_server, :oauth_exchanger, TestExchanger.SuccessGoogle)
    conn1 = get(conn, "/auth/google/callback?code=xxx")
    assert redirected_to(conn1) =~ "/"

    # facebook browser flow
    Application.put_env(:game_server, :oauth_exchanger, TestExchanger.SuccessFacebook)
    conn2 = get(conn, "/auth/facebook/callback?code=yyy")
    assert redirected_to(conn2) =~ "/"

    Application.put_env(:game_server, :oauth_exchanger, orig)
  end
end
