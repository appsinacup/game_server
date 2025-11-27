defmodule GameServerWeb.AdminLive.IndexTest do
  use GameServerWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias GameServer.AccountsFixtures
  alias GameServer.Repo

  test "admin dashboard shows lobbies count in the quick links", %{conn: conn} do
    admin = GameServer.AccountsFixtures.user_fixture()

    {:ok, admin} =
      admin
      |> GameServer.Accounts.User.admin_changeset(%{"is_admin" => true})
      |> GameServer.Repo.update()

    # create two lobbies so count will be 2
    GameServer.Lobbies.create_lobby(%{name: "dash-1", hostless: true})
    GameServer.Lobbies.create_lobby(%{name: "dash-2", hostless: true})

    {:ok, _view, html} = conn |> log_in_user(admin) |> live(~p"/admin")

    assert html =~ "Lobbies (2)"
  end
end
