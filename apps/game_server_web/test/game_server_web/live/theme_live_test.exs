defmodule GameServerWeb.ThemeLiveTest do
  use GameServerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias GameServer.Theme.JSONConfig

  test "LiveView pages get theme assigns and show defaults when runtime empty", %{conn: conn} do
    # Ensure THEME_CONFIG unset so packaged defaults are used
    orig = System.get_env("THEME_CONFIG")
    System.delete_env("THEME_CONFIG")
    JSONConfig.reload()

    on_exit(fn ->
      if orig, do: System.put_env("THEME_CONFIG", orig), else: System.delete_env("THEME_CONFIG")
      JSONConfig.reload()
    end)

    {:ok, _lv, html} = live(conn, ~p"/docs/setup")

    default_path = Path.join(:code.priv_dir(:game_server_web), "static/theme/default_config.json")
    {:ok, file} = File.read(default_path)
    expected = Jason.decode!(file)

    # verify header and title area contain the packaged defaults
    assert html =~ expected["title"]
    assert html =~ expected["tagline"]
  end
end
