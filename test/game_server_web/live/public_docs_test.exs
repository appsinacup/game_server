defmodule GameServerWeb.PublicDocsTest do
  use GameServerWeb.ConnCase
  import Phoenix.LiveViewTest

  test "public docs header includes lobbies link when unauthenticated", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/docs/setup")

    assert html =~ "Lobbies"
    assert html =~ "href=\"/lobbies\""
    # our new theming docs should render
    assert html =~ "Runtime theming (JSON)"
  end

  test "public docs header includes lobbies link when authenticated", %{conn: conn} do
    user = GameServer.AccountsFixtures.user_fixture()
    logged_conn = conn |> log_in_user(user)

    {:ok, _view, html} = live(logged_conn, "/docs/setup")

    assert html =~ "Lobbies"
    assert html =~ "href=\"/lobbies\""
  end
end
