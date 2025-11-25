defmodule GameServerWeb.AdminLive.LobbiesTest do
  use GameServerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "admin can view lobbies", %{conn: conn} do
    user = GameServer.AccountsFixtures.user_fixture()

    {:ok, user} =
      user
      |> GameServer.Accounts.User.admin_changeset(%{"is_admin" => true})
      |> GameServer.Repo.update()

    # create a few lobbies (one hosted, one hostless)
    {:ok, lobby1} =
      GameServer.Lobbies.create_lobby(%{
        title: "admin-lobby-1",
        name: "admin-lobby-1",
        host_id: user.id
      })

    {:ok, lobby2} =
      GameServer.Lobbies.create_lobby(%{
        title: "admin-lobby-2",
        name: "admin-lobby-2",
        hostless: true
      })

    {:ok, _lv, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/admin/lobbies")

    assert html =~ "Admin — Lobbies"
    assert html =~ "admin-lobby-1"
    assert html =~ "admin-lobby-2"

    # ensure back to admin link exists
    assert html =~ "← Back to Admin"

    # test edit flow via live view: open manage UI, change title and save
    {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/admin/lobbies")

    # open edit modal for first lobby
    edit_btn = element(view, "#admin-lobby-#{lobby1.id} button", "Edit")
    render_click(edit_btn)

    # submit save with new title
    form = form(view, "#lobby-form", %{"lobby" => %{"title" => "Updated Title"}})
    render_submit(form)

    # ensure update is persisted
    assert GameServer.Lobbies.get_lobby!(lobby1.id).title == "Updated Title"

    # now delete second lobby
    delete_btn = element(view, "#admin-lobby-#{lobby2.id} button", "Delete")
    render_click(delete_btn)

    # re-fetch the page and ensure it's gone
    html2 = render(view)
    refute html2 =~ "admin-lobby-2"
  end
end
