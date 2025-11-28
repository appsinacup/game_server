defmodule GameServerWeb.AdminLive.ConfigTest do
  use GameServerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias GameServer.Accounts.User
  alias GameServer.AccountsFixtures
  alias GameServer.Repo

  test "renders config page with collapsible cards for admin", %{conn: conn} do
    user = AccountsFixtures.user_fixture()

    {:ok, user} =
      user
      |> User.admin_changeset(%{"is_admin" => true})
      |> Repo.update()

    {:ok, _lv, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/admin/config")

    assert html =~ "Configuration"
    assert html =~ "data-action=\"toggle-card\""
    assert html =~ "data-card-key=\"config_status\""
    # default collapsed state
    assert html =~ "collapsed"
    assert html =~ "aria-expanded=\"false\""
    # Database diagnostics should render (show adapter and diagnostic keys)
    assert html =~ "Database"
    assert html =~ "POSTGRES_HOST" or html =~ "SQLite"
  end

  test "secrets are masked and DB adapter shows Postgres when env is set", %{conn: conn} do
    # Arrange - set env vars to predictable values and ensure cleanup after test
    System.put_env("DISCORD_CLIENT_ID", "discord12345")
    System.put_env("DISCORD_CLIENT_SECRET", "disSecret9876")
    System.put_env("GOOGLE_CLIENT_ID", "go123456")
    System.put_env("GOOGLE_CLIENT_SECRET", "goSecret987")
    System.put_env("SECRET_KEY_BASE", "myverylongsecret_key_value_here")
    System.put_env("SENTRY_DSN", "https://abcdef@o123.ingest")
    System.put_env("SENTRY_LOG_LEVEL", "info")
    System.put_env("SMTP_USERNAME", "smtpuser")
    System.put_env("SMTP_PASSWORD", "smtppass")
    System.put_env("POSTGRES_HOST", "localhost")
    System.put_env("POSTGRES_USER", "postgres")
    System.put_env("POSTGRES_DB", "game_server_test")
    System.put_env("POSTGRES_PASSWORD", "pg_secret_very_long")

    on_exit(fn ->
      for k <- [
            "DISCORD_CLIENT_ID",
            "DISCORD_CLIENT_SECRET",
            "GOOGLE_CLIENT_ID",
            "GOOGLE_CLIENT_SECRET",
            "SECRET_KEY_BASE",
            "SENTRY_DSN",
            "SENTRY_LOG_LEVEL",
            "SMTP_USERNAME",
            "SMTP_PASSWORD",
            "POSTGRES_HOST",
            "POSTGRES_USER",
            "POSTGRES_DB",
            "POSTGRES_PASSWORD"
          ] do
        System.delete_env(k)
      end
    end)

    {:ok, user} =
      AccountsFixtures.user_fixture()
      |> User.admin_changeset(%{"is_admin" => true})
      |> Repo.update()

    {:ok, _lv, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/admin/config")

    # verify postgres adapter detection
    assert html =~ "Postgres"

    # secrets should be masked according to the UI helper and present in the page
    mask = fn s ->
      if is_nil(s) or s == "" do
        "<unset>"
      else
        len = byte_size(s)

        if len <= 4 do
          String.duplicate("*", len)
        else
          n = max(1, div(len + 3, 4))
          first = String.slice(s, 0, n)
          last = String.slice(s, -n, n)
          "#{first}...#{last}"
        end
      end
    end

    assert html =~ mask.("discord12345")
    assert html =~ mask.("disSecret9876")
    assert html =~ mask.("go123456")
    assert html =~ mask.("goSecret987")
    assert html =~ mask.("myverylongsecret_key_value_here")
    assert html =~ mask.("https://abcdef@o123.ingest")
    assert html =~ mask.("smtppass")
    assert html =~ mask.("pg_secret_very_long")

    # ensure secret and sentry env label presence
    assert html =~ "SECRET_KEY_BASE"
    assert html =~ "SENTRY_DSN"
    assert html =~ "SENTRY_LOG_LEVEL"

    # ensure we've rendered env-var style labels for client config and hooks/device env names
    assert html =~ "DISCORD_CLIENT_ID"
    assert html =~ "GOOGLE_CLIENT_ID"
    assert html =~ "HOOKS_FILE_PATH"
    assert html =~ "DEVICE_AUTH_ENABLED"

    # SMTP env var label should be shown
    assert html =~ "SMTP_USERNAME"

    # if no hooks watch interval set, these should not be visible
    refute html =~ "Watch interval (app): <unset>"
    refute html =~ "GAME_SERVER_HOOKS_WATCH_INTERVAL"
  end

  test "clicking function name pre-fills function and example args", %{conn: conn} do
    user = AccountsFixtures.user_fixture()

    {:ok, user} =
      user
      |> User.admin_changeset(%{"is_admin" => true})
      |> Repo.update()

    # Ensure example hook source is compiled & registered so exported_functions
    # includes signatures and example args.
    path = Path.join(File.cwd!(), "modules/example_hook.ex")
    Application.put_env(:game_server, :hooks_file_path, path)
    assert {:ok, _mod} = GameServer.Hooks.register_file(path)

    {:ok, lv, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/admin/config")

    # click the function name for hello2 (should auto-prefill args too)
    # trigger the phx-click on the span element and assert the inputs were updated
    hello2_el = element(lv, "span[phx-click='prefill_hook'][phx-value-fn='hello2']")
    html_after = render_click(hello2_el)

    # function input should contain hello2
    assert html_after =~ "id=\"hooks-fn-input\""
    assert html_after =~ "value=\"hello2\""

    # args input should contain a generated example args JSON containing both parameter examples
    assert html_after =~ "id=\"hooks-args-input\""
    assert html_after =~ "name" and html_after =~ "name2"

    # the full docs panel should appear and contain the doc text
    assert html_after =~ "Full docs: hello2/2"
    assert html_after =~ "Say hi with two names"

    # cleanup env
    Application.delete_env(:game_server, :hooks_file_path)
    Application.delete_env(:game_server, :hooks_module)
  end
end
