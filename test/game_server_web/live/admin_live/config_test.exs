defmodule GameServerWeb.AdminLive.ConfigTest do
  use GameServerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders config page with collapsible cards for admin", %{conn: conn} do
    user = GameServer.AccountsFixtures.user_fixture()

    {:ok, user} =
      user
      |> GameServer.Accounts.User.admin_changeset(%{"is_admin" => true})
      |> GameServer.Repo.update()

    {:ok, _lv, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/admin/config")

    assert html =~ "Configuration"
    assert html =~ "data-action=\"toggle-card\""
    assert html =~ "data-card-key=\"config_status\""
    # provider setup content is now moved to the public docs page
    assert html =~ "data-card-key=\"public_docs\""
    # default collapsed state
    assert html =~ "collapsed"
    assert html =~ "aria-expanded=\"false\""
  end
end
