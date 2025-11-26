defmodule GameServerWeb.AdminLive.UsersTest do
  use GameServerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "admin users pagination displays totals and disables Next on last page", %{conn: conn} do
    user = GameServer.AccountsFixtures.user_fixture()

    {:ok, admin} =
      user
      |> GameServer.Accounts.User.admin_changeset(%{"is_admin" => true})
      |> GameServer.Repo.update()

    # create 30 users so admin listing has two pages with default page_size 25
    for i <- 1..30 do
      GameServer.AccountsFixtures.user_fixture(%{email: "pagi-user-#{i}@example.com"})
    end

    {:ok, view, html} = conn |> log_in_user(admin) |> live(~p"/admin/users")

    # total count visible
    assert html =~ "(30)" or html =~ "(31)"

    # page total should show at least "/ 2"
    assert html =~ "/ 2"

    # Next enabled on first page
    assert html =~ ~s(phx-click="admin_users_next")
    refute html =~ ~r/<button[^>]*phx-click="admin_users_next"[^>]*disabled/

    # go to next page
    view |> element("button[phx-click=\"admin_users_next\"]") |> render_click()
    html2 = render(view)

    # on last page Next should be disabled
    assert html2 =~ ~r/<button[^>]*phx-click="admin_users_next"[^>]*disabled/
  end
end
