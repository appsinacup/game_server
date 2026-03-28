defmodule GameServerWeb.ThemeLiveTest do
  use GameServerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias GameServer.Content
  alias GameServer.Theme.JSONConfig

  test "LiveView pages render without errors when THEME_CONFIG is unset", %{conn: conn} do
    # Ensure THEME_CONFIG unset so no theme is loaded
    orig = System.get_env("THEME_CONFIG")
    System.delete_env("THEME_CONFIG")
    JSONConfig.reload()
    Content.reload()

    on_exit(fn ->
      if orig, do: System.put_env("THEME_CONFIG", orig), else: System.delete_env("THEME_CONFIG")
      JSONConfig.reload()
      Content.reload()
    end)

    {:ok, _lv, html} = live(conn, ~p"/docs/setup")

    # Page should render without crashing even with no theme
    assert html =~ "<html"
  end
end
