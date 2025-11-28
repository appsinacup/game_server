defmodule GameServerWeb.AdminLive.UsersTest do
  use GameServerWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Ecto.Query
  alias GameServer.Accounts
  alias GameServer.Accounts.User
  alias GameServer.AccountsFixtures
  alias GameServer.Repo

  test "admin users pagination displays totals and disables Next on last page", %{conn: conn} do
    user = AccountsFixtures.user_fixture()

    {:ok, admin} =
      user
      |> User.admin_changeset(%{"is_admin" => true})
      |> Repo.update()

    # create 30 users so admin listing has two pages with default page_size 25
    for i <- 1..30 do
      AccountsFixtures.user_fixture(%{email: "pagi-user-#{i}@example.com"})
    end

    # sanity-check: DB has users we created (pagination test)
    assert Repo.aggregate(User, :count, :id) >= 4

    {:ok, view, html} = conn |> log_in_user(admin) |> live(~p"/admin/users")

    # total count visible
    assert html =~ "(30)" or html =~ "(31)"

    # page total should show at least "/ 2"
    assert html =~ "/ 2"

    # Next enabled on first page
    assert html =~ ~s(phx-click="admin_users_next")
    refute html =~ ~r/<button[^>]*phx-click="admin_users_next"[^>]*disabled/

    # go to next page
    view |> element(~S(button[phx-click="admin_users_next"])) |> render_click()
    html2 = render(view)

    # on last page Next should be disabled
    assert html2 =~ ~r/<button[^>]*phx-click="admin_users_next"[^>]*disabled/
  end

  test "filter by provider checkboxes works and updates counts", %{conn: conn} do
    # admin user
    user = AccountsFixtures.user_fixture()

    {:ok, admin} =
      user
      |> User.admin_changeset(%{"is_admin" => true})
      |> Repo.update()

    # create users with provider fields using provider helpers
    {:ok, _d1} =
      Accounts.find_or_create_from_discord(%{
        discord_id: "d1",
        email: "discord1@example.com"
      })

    {:ok, _d2} =
      Accounts.find_or_create_from_discord(%{
        discord_id: "d2",
        email: "discord2@example.com"
      })

    {:ok, _g1} =
      Accounts.find_or_create_from_google(%{
        google_id: "g1",
        email: "google1@example.com"
      })

    {:ok, _s1} =
      Accounts.find_or_create_from_steam(%{
        steam_id: "s1"
      })

    _plain = AccountsFixtures.user_fixture(%{email: "plain@example.com"})
    # create a user with a password so they show up in the email/password filter
    _password_user =
      AccountsFixtures.user_fixture(%{email: "pw@example.com"})
      |> AccountsFixtures.set_password()

    {:ok, view, html} = conn |> log_in_user(admin) |> live(~p"/admin/users")

    # verify all users present initially
    assert html =~ "discord1@example.com"
    assert html =~ "discord2@example.com"
    assert html =~ "google1@example.com"
    assert html =~ "s1"
    assert html =~ "plain@example.com"

    # confirm DB-level provider counts match expectations
    discord_count =
      Repo.one(
        from(u in User,
          where: not is_nil(u.discord_id) and u.discord_id != "",
          select: count(u.id)
        )
      )

    assert discord_count >= 2

    # toggle discord filter on
    view
    |> element(~S(input[phx-click="toggle_provider"][phx-value-provider="discord"]))
    |> render_click(%{"provider" => "discord"})

    html2 = render(view)

    # only discord users should remain
    assert html2 =~ "discord1@example.com"
    assert html2 =~ "discord2@example.com"
    refute html2 =~ "google1@example.com"
    refute html2 =~ "plain@example.com"

    # heading count should reflect 2 users (may include other system users depending on fixtures)
    assert html2 =~ "(2)" or html2 =~ "(3)"

    # toggle discord off and google on
    view
    |> element(~S(input[phx-click="toggle_provider"][phx-value-provider="discord"]))
    |> render_click(%{"provider" => "discord"})

    view
    |> element(~S(input[phx-click="toggle_provider"][phx-value-provider="google"]))
    |> render_click(%{"provider" => "google"})

    html3 = render(view)

    assert html3 =~ "google1@example.com"
    refute html3 =~ "discord1@example.com"
    refute html3 =~ "discord2@example.com"

    # now test email/password filter
    view
    |> element(~S(input[phx-click="toggle_provider"][phx-value-provider="google"]))
    |> render_click(%{"provider" => "google"})

    # toggle on email filter
    view
    |> element(~S(input[phx-click="toggle_provider"][phx-value-provider="email"]))
    |> render_click(%{"provider" => "email"})

    html4 = render(view)

    assert html4 =~ "pw@example.com"
    # toggle steam filter on
    view
    |> element(~S(input[phx-click="toggle_provider"][phx-value-provider="steam"]))
    |> render_click(%{"provider" => "steam"})

    html5 = render(view)

    assert html5 =~ "s1"
    refute html5 =~ "discord1@example.com"
    refute html5 =~ "google1@example.com"
    refute html4 =~ "discord1@example.com"
    refute html4 =~ "google1@example.com"
  end
end
