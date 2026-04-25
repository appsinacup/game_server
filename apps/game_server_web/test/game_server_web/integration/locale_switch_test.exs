defmodule GameServerWeb.LocaleSwitchTest do
  use GameServerWeb.ConnCase, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  test "locale-prefixed navigation persists locale and renders translated host labels", %{
    conn: conn
  } do
    conn = get(conn, "/es/leaderboards")

    assert redirected_to(conn) == "/leaderboards"
    assert get_session(conn, :preferred_locale) == "es"

    {:ok, _view, html} = conn |> recycle() |> live("/leaderboards")

    assert html =~ "Clasificaciones"
    assert html =~ "Iniciar sesi"
  end

  test "region locale prefixes normalize back to the canonical locale", %{conn: conn} do
    conn = get(conn, "/pt-br/leaderboards")

    assert redirected_to(conn) == "/leaderboards"
    assert get_session(conn, :preferred_locale) == "pt_BR"
  end
end
