defmodule GameServerWeb.PageControllerTest do
  use GameServerWeb.ConnCase, async: true

  test "home shows features", %{conn: conn} do
    conn = get(conn, "/")
    body = html_response(conn, 200)

    assert body =~ "Features included"
    assert body =~ "Discord OAuth"
    assert body =~ "Sentry"
    assert body =~ "SQLite"
  end
end
