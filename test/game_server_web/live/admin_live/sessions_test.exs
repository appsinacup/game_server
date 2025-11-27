defmodule GameServerWeb.AdminLive.SessionsTest do
  use GameServerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias GameServer.Accounts.User
  alias GameServer.Accounts.UserToken
  alias GameServer.AccountsFixtures
  alias GameServer.Repo

  test "admin sessions pagination displays totals and disables Next on last page", %{conn: conn} do
    user = AccountsFixtures.user_fixture()

    {:ok, admin} =
      user
      |> User.admin_changeset(%{"is_admin" => true})
      |> Repo.update()

    # create 51 session tokens so listing has two pages (page_size default 50)
    for _i <- 1..51 do
      {_token, user_token} = UserToken.build_session_token(admin)
      Repo.insert!(user_token)
    end

    {:ok, view, html} = conn |> log_in_user(admin) |> live(~p"/admin/sessions")

    # exact count may vary depending on other sessions created during test setup,
    # assert we have a numeric total shown and the pagination shows 2 pages
    assert html =~ ~r/\(\d+\)/
    assert html =~ "/ 2"

    # Next enabled on first page
    assert html =~ ~s(phx-click="admin_sessions_next")
    refute html =~ ~r/<button[^>]*phx-click="admin_sessions_next"[^>]*disabled/

    # go to next page
    view |> element(~S(button[phx-click="admin_sessions_next"])) |> render_click()
    html2 = render(view)

    # on last page Next should be disabled
    assert html2 =~ ~r/<button[^>]*phx-click="admin_sessions_next"[^>]*disabled/
  end
end
