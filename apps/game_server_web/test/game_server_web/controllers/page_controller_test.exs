defmodule GameServerWeb.PageControllerTest do
  use GameServerWeb.ConnCase, async: true

  alias GameServer.Theme.JSONConfig

  test "home shows features", %{conn: conn} do
    conn = get(conn, "/")
    body = html_response(conn, 200)

    assert body =~ "Features"
    assert body =~ "Discord"
    assert body =~ "SQLite"
  end

  test "home uses default theme title and tagline when THEME_CONFIG unset", %{conn: conn} do
    orig = System.get_env("THEME_CONFIG")
    System.delete_env("THEME_CONFIG")
    JSONConfig.reload()

    on_exit(fn ->
      if orig, do: System.put_env("THEME_CONFIG", orig), else: System.delete_env("THEME_CONFIG")
      JSONConfig.reload()
    end)

    conn = get(conn, "/")
    body = html_response(conn, 200)

    # Header should show the shipped defaults (read them from packaged file so tests stay stable)
    default_path = Path.join(:code.priv_dir(:game_server_web), "static/theme/default_config.json")
    {:ok, file} = File.read(default_path)
    expected = Jason.decode!(file)

    assert body =~ expected["title"]
    assert body =~ expected["tagline"]
  end

  test "privacy page present", %{conn: conn} do
    conn = get(conn, "/privacy")
    body = html_response(conn, 200)

    assert body =~ "Privacy Policy"
    assert body =~ "Information We Collect"
  end

  test "terms page present", %{conn: conn} do
    conn = get(conn, "/terms")
    body = html_response(conn, 200)

    assert body =~ "Terms and Conditions"
    assert body =~ "Acceptance of Terms"
  end

  test "privacy link present in layout", %{conn: conn} do
    conn = get(conn, "/")
    body = html_response(conn, 200)

    assert body =~ "href=\"/privacy\""
  end

  test "terms link present in layout", %{conn: conn} do
    conn = get(conn, "/")
    body = html_response(conn, 200)

    assert body =~ "href=\"/terms\""
  end
end
