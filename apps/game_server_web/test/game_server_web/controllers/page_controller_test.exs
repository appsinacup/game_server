defmodule GameServerWeb.PageControllerTest do
  use GameServerWeb.ConnCase, async: false

  alias GameServer.Content
  alias GameServer.Theme.JSONConfig

  setup do
    # Ensure a known THEME_CONFIG is active so tests aren't affected by other
    # modules that may delete/restore the env var concurrently.
    # Use a temp file with known content for reliable path resolution.
    orig = System.get_env("THEME_CONFIG")

    base =
      Path.join(System.tmp_dir!(), "theme_page_test_#{System.unique_integer([:positive])}.json")

    en_path = String.trim_trailing(base, ".json") <> ".en.json"

    json =
      Jason.encode!(%{
        "title" => "Gamend",
        "tagline" => "Game + Backend",
        "logo" => "/images/logo.png",
        "banner" => "/images/banner.png",
        "favicon" => "/favicon.ico",
        "features" => [
          %{
            "title" => "Persistence & Caching",
            "description" => "SQLite (in memory) and PostgreSQL.",
            "icon" => "hero-server-stack"
          }
        ],
        "useful_links" => [
          %{
            "title" => "Discord",
            "url" => "https://discord.com/invite/example",
            "icon" => "hero-chat-bubble-left-ellipsis",
            "external" => true
          }
        ],
        "footer_links" => [
          %{"label" => "Privacy Policy", "href" => "/privacy"},
          %{"label" => "Terms and Conditions", "href" => "/terms"}
        ]
      })

    File.write!(en_path, json)
    System.put_env("THEME_CONFIG", base)
    JSONConfig.reload()
    Content.reload()

    on_exit(fn ->
      if orig, do: System.put_env("THEME_CONFIG", orig), else: System.delete_env("THEME_CONFIG")
      JSONConfig.reload()
      Content.reload()
      File.rm(en_path)
    end)

    :ok
  end

  test "home shows features", %{conn: conn} do
    conn = get(conn, "/")
    body = html_response(conn, 200)

    assert body =~ "Features"
    assert body =~ "Online"
    assert body =~ "Discord"
    assert body =~ "SQLite"
  end

  test "home renders without errors when THEME_CONFIG is unset", %{conn: conn} do
    System.delete_env("THEME_CONFIG")
    JSONConfig.reload()
    Content.reload()

    conn = get(conn, "/")
    # Page should render without crashing even with no theme configured
    assert html_response(conn, 200) =~ "<html"
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
