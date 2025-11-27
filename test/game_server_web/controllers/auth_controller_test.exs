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

  test "request redirects to provider (google)", %{conn: conn} do
    old = System.get_env("GOOGLE_CLIENT_ID")
    System.put_env("GOOGLE_CLIENT_ID", "google-123")

    on_exit(fn -> if old, do: System.put_env("GOOGLE_CLIENT_ID", old) end)

    conn = get(conn, "/auth/google")
    assert redirected_to(conn) =~ "https://accounts.google.com/o/oauth2/v2/auth"
    assert redirected_to(conn) =~ "client_id=google-123"
  end

  test "request redirects to provider (facebook)", %{conn: conn} do
    old = System.get_env("FACEBOOK_CLIENT_ID")
    System.put_env("FACEBOOK_CLIENT_ID", "fb-123")

    on_exit(fn -> if old, do: System.put_env("FACEBOOK_CLIENT_ID", old) end)

    conn = get(conn, "/auth/facebook")
    assert redirected_to(conn) =~ "https://www.facebook.com/v18.0/dialog/oauth"
    assert redirected_to(conn) =~ "client_id=fb-123"
  end

  test "request redirects to provider (apple)", %{conn: conn} do
    old = System.get_env("APPLE_CLIENT_ID")
    System.put_env("APPLE_CLIENT_ID", "apple-123")

    on_exit(fn -> if old, do: System.put_env("APPLE_CLIENT_ID", old) end)

    conn = get(conn, "/auth/apple")
    assert redirected_to(conn) =~ "https://appleid.apple.com/auth/authorize"
    assert redirected_to(conn) =~ "client_id=apple-123"
  end

  test "callback (discord) on error with state creates oauth session", %{conn: conn} do
    orig = Application.get_env(:game_server, :oauth_exchanger)

    defmodule TestExchanger do
      def exchange_discord_code(_code, _client_id, _secret, _redirect), do: {:error, :boom}
    end

    Application.put_env(:game_server, :oauth_exchanger, TestExchanger)

    on_exit(fn -> Application.put_env(:game_server, :oauth_exchanger, orig) end)

    session_id = "session-#{System.unique_integer([:positive])}"

    _conn = get(conn, "/auth/discord/callback?code=abc&state=#{session_id}")

    # session should be created with error status
    sess = OAuthSessions.get_session(session_id)
    assert sess.status == "error"
  end

  test "callback (discord) on error without state shows flash", %{conn: conn} do
    orig = Application.get_env(:game_server, :oauth_exchanger)

    defmodule TestExchanger.ErrorDiscord do
      def exchange_discord_code(_code, _client_id, _secret, _redirect), do: {:error, :boom}
    end

    Application.put_env(:game_server, :oauth_exchanger, TestExchanger.ErrorDiscord)

    on_exit(fn -> Application.put_env(:game_server, :oauth_exchanger, orig) end)

    conn = get(conn, "/auth/discord/callback?code=abc")

    assert redirected_to(conn) =~ "/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Failed to authenticate"
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
    _conn2 = get(conn, "/auth/discord/callback?code=abc&state=#{session_id}")

    session = OAuthSessions.get_session(session_id)
    assert session.status == "completed"
  end

  test "callback (google) success browser and api flows", %{conn: conn} do
    orig = Application.get_env(:game_server, :oauth_exchanger)

    defmodule TestExchanger.SuccessGoogle do
      def exchange_google_code(_code, _client_id, _secret, _redirect) do
        {:ok,
         %{
           "id" => "g123",
           "email" => "g@example.com",
           "picture" => "https://img/1.png",
           "name" => "Gname"
         }}
      end
    end

    Application.put_env(:game_server, :oauth_exchanger, TestExchanger.SuccessGoogle)

    on_exit(fn -> Application.put_env(:game_server, :oauth_exchanger, orig) end)

    # browser flow
    conn1 = get(conn, "/auth/google/callback?code=xxx")
    assert redirected_to(conn1) =~ "/"

    # api flow with state
    session_id = "sid-#{System.unique_integer([:positive])}"
    _conn2 = get(conn, "/auth/google/callback?code=xxx&state=#{session_id}")

    session = OAuthSessions.get_session(session_id)
    assert session.status == "completed"
  end

  test "callback (google) error creates session with error status", %{conn: conn} do
    orig = Application.get_env(:game_server, :oauth_exchanger)

    defmodule TestExchanger.ErrorGoogle do
      def exchange_google_code(_code, _client_id, _secret, _redirect), do: {:error, :failed}
    end

    Application.put_env(:game_server, :oauth_exchanger, TestExchanger.ErrorGoogle)

    on_exit(fn -> Application.put_env(:game_server, :oauth_exchanger, orig) end)

    session_id = "sid-#{System.unique_integer([:positive])}"
    _conn = get(conn, "/auth/google/callback?code=xxx&state=#{session_id}")

    session = OAuthSessions.get_session(session_id)
    assert session.status == "error"
  end

  test "callback (facebook) success browser and api flows", %{conn: conn} do
    orig = Application.get_env(:game_server, :oauth_exchanger)

    defmodule TestExchanger.SuccessFacebook do
      def exchange_facebook_code(_code, _client_id, _secret, _redirect) do
        {:ok,
         %{
           "id" => "fb123",
           "email" => "fb@example.com",
           "picture" => %{"data" => %{"url" => "https://fb/img.png"}},
           "name" => "Fb name"
         }}
      end
    end

    Application.put_env(:game_server, :oauth_exchanger, TestExchanger.SuccessFacebook)

    on_exit(fn -> Application.put_env(:game_server, :oauth_exchanger, orig) end)

    # browser flow
    conn1 = get(conn, "/auth/facebook/callback?code=yyy")
    assert redirected_to(conn1) =~ "/"

    # api flow with state
    session_id = "sid-#{System.unique_integer([:positive])}"
    _conn2 = get(conn, "/auth/facebook/callback?code=yyy&state=#{session_id}")

    session = OAuthSessions.get_session(session_id)
    assert session.status == "completed"
  end

  test "callback (facebook) error creates session with error status", %{conn: conn} do
    orig = Application.get_env(:game_server, :oauth_exchanger)

    defmodule TestExchanger.ErrorFacebook do
      def exchange_facebook_code(_code, _client_id, _secret, _redirect), do: {:error, :failed}
    end

    Application.put_env(:game_server, :oauth_exchanger, TestExchanger.ErrorFacebook)

    on_exit(fn -> Application.put_env(:game_server, :oauth_exchanger, orig) end)

    session_id = "sid-#{System.unique_integer([:positive])}"
    _conn = get(conn, "/auth/facebook/callback?code=yyy&state=#{session_id}")

    session = OAuthSessions.get_session(session_id)
    assert session.status == "error"
  end

  test "callback (apple) success browser and api flows", %{conn: conn} do
    orig = Application.get_env(:game_server, :oauth_exchanger)

    defmodule TestExchanger.SuccessApple do
      def exchange_apple_code(_code, _client_id, _secret, _redirect) do
        {:ok, %{"sub" => "apple123", "email" => "apple@example.com"}}
      end
    end

    Application.put_env(:game_server, :oauth_exchanger, TestExchanger.SuccessApple)

    # Set up Apple client_secret in cache to avoid needing APPLE_PRIVATE_KEY
    case :ets.info(:apple_oauth_cache) do
      :undefined -> :ets.new(:apple_oauth_cache, [:named_table, :public, :set])
      _ -> :ok
    end

    expires_at = System.system_time(:second) + 10_000
    :ets.insert(:apple_oauth_cache, {:client_secret, "test-secret", expires_at})

    on_exit(fn ->
      Application.put_env(:game_server, :oauth_exchanger, orig)
      # Only delete if table exists
      case :ets.info(:apple_oauth_cache) do
        :undefined -> :ok
        _ -> :ets.delete(:apple_oauth_cache)
      end
    end)

    # browser flow
    conn1 = post(conn, "/auth/apple/callback", %{"code" => "xxx"})
    assert redirected_to(conn1) =~ "/"

    # api flow with state
    session_id = "sid-#{System.unique_integer([:positive])}"
    _conn2 = post(conn, "/auth/apple/callback", %{"code" => "xxx", "state" => session_id})

    session = OAuthSessions.get_session(session_id)
    assert session.status == "completed"
  end

  test "callback (apple) error creates session with error status", %{conn: conn} do
    orig = Application.get_env(:game_server, :oauth_exchanger)

    defmodule TestExchanger.ErrorApple do
      def exchange_apple_code(_code, _client_id, _secret, _redirect), do: {:error, :failed}
    end

    Application.put_env(:game_server, :oauth_exchanger, TestExchanger.ErrorApple)

    # Set up Apple client_secret in cache
    case :ets.info(:apple_oauth_cache) do
      :undefined -> :ets.new(:apple_oauth_cache, [:named_table, :public, :set])
      _ -> :ok
    end

    expires_at = System.system_time(:second) + 10_000
    :ets.insert(:apple_oauth_cache, {:client_secret, "test-secret", expires_at})

    on_exit(fn ->
      Application.put_env(:game_server, :oauth_exchanger, orig)
      # Only delete if table exists
      case :ets.info(:apple_oauth_cache) do
        :undefined -> :ok
        _ -> :ets.delete(:apple_oauth_cache)
      end
    end)

    session_id = "sid-#{System.unique_integer([:positive])}"
    _conn = post(conn, "/auth/apple/callback", %{"code" => "xxx", "state" => session_id})

    session = OAuthSessions.get_session(session_id)
    assert session.status == "error"
  end
end
