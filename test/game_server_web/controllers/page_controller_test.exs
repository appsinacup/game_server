defmodule GameServerWeb.PageControllerTest do
  use GameServerWeb.ConnCase, async: true

  test "home shows features", %{conn: conn} do
    conn = get(conn, "/")
    body = html_response(conn, 200)

    assert body =~ "Features"
    assert body =~ "Discord"
    assert body =~ "Sentry"
    assert body =~ "SQLite"
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
