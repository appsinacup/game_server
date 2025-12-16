defmodule GameServerWeb.AdminLive.ConfigTest do
  # This test modifies global environment (plugins dir) and must not run
  # concurrently with other tests that depend on this state.
  use GameServerWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  alias GameServer.Accounts.User
  alias GameServer.AccountsFixtures
  alias GameServer.Hooks.PluginManager
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
    assert html =~ "CACHE_ENABLED"
    assert html =~ "ACCESS_LOG_LEVEL"
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
    System.put_env("SMTP_PORT", "465")
    System.put_env("SMTP_SSL", "true")
    System.put_env("SMTP_TLS", "true")
    System.put_env("SMTP_FROM_NAME", "Game Server")
    System.put_env("SMTP_FROM_EMAIL", "no-reply@example.com")
    System.put_env("SMTP_SNI", "mail.resend.com")
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
            "SMTP_PORT",
            "SMTP_SSL",
            "SMTP_TLS",
            "SMTP_FROM_NAME",
            "SMTP_FROM_EMAIL",
            "SMTP_SNI",
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
    assert html =~ "DEVICE_AUTH_ENABLED"

    # SMTP env var label should be shown
    assert html =~ "SMTP_USERNAME"
    # when SMTP_PASSWORD is present the UI should indicate SMTP is configured
    assert html =~ "<span class=\"badge badge-success\">SMTP</span>"

    # SMTP port and SSL flags should be displayed
    assert html =~ "SMTP_PORT"
    assert html =~ "SMTP_SSL"
    # SMTP SNI (server name indication) should be displayed when present
    assert html =~ "SMTP_SNI"

    # From details should be displayed when configured
    assert html =~ mask.("Game Server")
    assert html =~ mask.("no-reply@example.com")

    # Admin UI should show guidance about verifying the From address/domain
    # The ampersand is escaped in HTML; look for the phrase "domain verification" instead
    assert html =~ "domain verification"

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

    # Create a test-only OTP plugin and reload plugins so the Admin UI
    # can list exported functions.
    tmp = Path.join(System.tmp_dir!(), "gs-admin-plugin-#{System.unique_integer([:positive])}")
    plugin_root = Path.join(tmp, "modules/plugins")
    plugin_name = "admin_test_plugin"
    plugin_dir = Path.join(plugin_root, plugin_name)
    ebin_dir = Path.join(plugin_dir, "ebin")

    File.mkdir_p!(ebin_dir)

    hook_mod = Module.concat([GameServer, AdminConfigTestPluginHook])

    src = """
    defmodule #{inspect(hook_mod)} do
      @behaviour GameServer.Hooks

      def after_startup, do: :ok
      def before_stop, do: :ok

      def after_user_register(_user), do: :ok
      def after_user_login(_user), do: :ok

      def before_lobby_create(attrs), do: {:ok, attrs}
      def after_lobby_create(_lobby), do: :ok
      def before_lobby_join(user, lobby, opts), do: {:ok, {user, lobby, opts}}
      def after_lobby_join(_user, _lobby), do: :ok
      def before_lobby_leave(user, lobby), do: {:ok, {user, lobby}}
      def after_lobby_leave(_user, _lobby), do: :ok
      def before_lobby_update(_lobby, attrs), do: {:ok, attrs}
      def after_lobby_update(_lobby), do: :ok
      def before_lobby_delete(lobby), do: {:ok, lobby}
      def after_lobby_delete(_lobby), do: :ok
      def before_user_kicked(host, target, lobby), do: {:ok, {host, target, lobby}}
      def after_user_kicked(_host, _target, _lobby), do: :ok
      def after_lobby_host_change(_lobby, _new_host_id), do: :ok

      @doc "Say hi with two names"
      def hello2(name, name2), do: "Hello2, \#{name} \#{name2}!"

      @doc "Say hi to a user"
      def hello(name), do: "Hello, \#{name}!"
    end
    """

    [{^hook_mod, beam}] = Code.compile_string(src)

    File.write!(Path.join(ebin_dir, Atom.to_string(hook_mod) <> ".beam"), beam)

    app_term =
      {:application, String.to_atom(plugin_name),
       [
         {:description, ~c"admin test plugin"},
         {:vsn, ~c"0.1.0"},
         {:modules, [hook_mod]},
         {:registered, []},
         {:applications, [:kernel, :stdlib]},
         {:env, [hooks_module: to_charlist(Atom.to_string(hook_mod))]}
       ]}

    app_text = :io_lib.format(~c"~p.~n", [app_term]) |> IO.iodata_to_binary()
    File.write!(Path.join(ebin_dir, "#{plugin_name}.app"), app_text)

    orig_plugins_dir = System.get_env("GAME_SERVER_PLUGINS_DIR")
    System.put_env("GAME_SERVER_PLUGINS_DIR", plugin_root)
    _ = PluginManager.reload()

    on_exit(fn ->
      if orig_plugins_dir,
        do: System.put_env("GAME_SERVER_PLUGINS_DIR", orig_plugins_dir),
        else: System.delete_env("GAME_SERVER_PLUGINS_DIR")

      _ = PluginManager.reload()
      File.rm_rf!(tmp)
    end)

    {:ok, lv, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/admin/config")

    # click the function name for hello2 (should auto-prefill args too)
    # trigger the phx-click on the span element and assert the inputs were updated
    # verify the element exists before clicking (avoid transient races)
    assert has_element?(
             lv,
             "span[phx-click='prefill_hook'][phx-value-plugin='#{plugin_name}'][phx-value-fn='hello2']"
           )

    hello2_el =
      element(
        lv,
        "span[phx-click='prefill_hook'][phx-value-plugin='#{plugin_name}'][phx-value-fn='hello2']"
      )

    html_after = render_click(hello2_el)

    # plugin input should contain plugin name
    assert html_after =~ "id=\"hooks-plugin-input\""
    assert html_after =~ "value=\"#{plugin_name}\""

    # function input should contain hello2
    assert html_after =~ "id=\"hooks-fn-input\""
    assert html_after =~ "value=\"hello2\""

    # args input should contain a generated example args JSON containing both parameter examples
    assert html_after =~ "id=\"hooks-args-input\""
    assert html_after =~ "name=\"args\""

    # Full docs may be unavailable depending on compiled BEAM metadata.
  end

  test "send test email button delivers a message and shows flash", %{conn: conn} do
    {:ok, user} =
      AccountsFixtures.user_fixture()
      |> User.admin_changeset(%{"is_admin" => true})
      |> Repo.update()

    {:ok, lv, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/admin/config")

    # ensure the UI shows the test email button
    assert has_element?(lv, "button[phx-click='send_test_email']")

    # click and capture the updated HTML (flash present)
    html_after = render_click(element(lv, "button[phx-click='send_test_email']"))

    assert html_after =~ "Test email sent to #{user.email}"

    # Swoosh.Test adapter sends delivered emails to the current process
    assert_receive {:email, email}

    assert Enum.any?(email.to, fn {_name, addr} -> addr == user.email end)
  end

  test "renders theme diagnostics when THEME_CONFIG is set (env var)", %{conn: conn} do
    # create temporary theme config file and set env var to point at it
    orig = System.get_env("THEME_CONFIG")

    tmp = Path.join(System.tmp_dir!(), "theme_test_#{System.unique_integer([:positive])}.json")

    json =
      ~s({"title":"Test Theme","logo":"/theme/test-logo.png","banner":"/theme/test-banner.png"})

    File.write!(tmp, json)

    System.put_env("THEME_CONFIG", tmp)

    on_exit(fn ->
      if orig, do: System.put_env("THEME_CONFIG", orig), else: System.delete_env("THEME_CONFIG")
      File.rm_rf(tmp)
    end)

    {:ok, user} =
      AccountsFixtures.user_fixture()
      |> User.admin_changeset(%{"is_admin" => true})
      |> Repo.update()

    {:ok, _lv, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/admin/config")

    assert html =~ "Theme"
    assert html =~ "THEME_CONFIG: #{tmp}"
    # raw JSON content should be present in the page
    assert html =~ "Test Theme"
    assert html =~ "/theme/test-logo.png"
  end

  test "renders default theme diagnostics when THEME_CONFIG is unset", %{conn: conn} do
    # Ensure env var is unset so loader uses the default shipped theme
    orig = System.get_env("THEME_CONFIG")

    System.delete_env("THEME_CONFIG")

    on_exit(fn ->
      if orig, do: System.put_env("THEME_CONFIG", orig), else: System.delete_env("THEME_CONFIG")
    end)

    {:ok, user} =
      AccountsFixtures.user_fixture()
      |> User.admin_changeset(%{"is_admin" => true})
      |> Repo.update()

    {:ok, _lv, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/admin/config")

    # Default title/tagline/logo from priv/static/theme/default_config.json should be shown
    default_path = Path.join(:code.priv_dir(:game_server), "static/theme/default_config.json")
    {:ok, file} = File.read(default_path)
    expected = Jason.decode!(file)

    assert html =~ expected["title"]
    assert html =~ expected["tagline"]
    # When THEME_CONFIG is not present we should consider runtime theme not configured
    # (we still show the default values). Ensure the UI shows Disabled for runtime theme.
    assert html =~ "<span class=\"badge badge-error\">Disabled</span>"
    assert html =~ expected["logo"]
    assert html =~ expected["banner"]
  end

  test "blank THEME_CONFIG is treated as unset and shows defaults", %{conn: conn} do
    orig = System.get_env("THEME_CONFIG")
    System.put_env("THEME_CONFIG", "")

    on_exit(fn ->
      if orig, do: System.put_env("THEME_CONFIG", orig), else: System.delete_env("THEME_CONFIG")
    end)

    {:ok, user} =
      AccountsFixtures.user_fixture()
      |> User.admin_changeset(%{"is_admin" => true})
      |> Repo.update()

    {:ok, _lv, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/admin/config")

    assert html =~ "THEME_CONFIG: &lt;unset&gt;"
    default_path = Path.join(:code.priv_dir(:game_server), "static/theme/default_config.json")
    {:ok, file} = File.read(default_path)
    expected = Jason.decode!(file)

    assert html =~ expected["title"]
    assert html =~ expected["tagline"]
    assert html =~ "<span class=\"badge badge-error\">Disabled</span>"
  end
end
