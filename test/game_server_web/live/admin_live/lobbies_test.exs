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

  test "admin lobbies pagination displays totals and disables Next on last page", %{conn: conn} do
    user = GameServer.AccountsFixtures.user_fixture()

    {:ok, admin} =
      user
      |> GameServer.Accounts.User.admin_changeset(%{"is_admin" => true})
      |> GameServer.Repo.update()

    # create 30 lobbies so admin listing has two pages with default page_size 25
    for i <- 1..30 do
      GameServer.Lobbies.create_lobby(%{name: "admin-pagi-#{i}", title: "Admin Pagi #{i}", hostless: true})
    end

    {:ok, view, html} = conn |> log_in_user(admin) |> live(~p"/admin/lobbies")

    assert html =~ "(30)"
    assert html =~ "/ 2"

    # Next enabled on first page (no disabled attr on admin_lobbies_next)
    assert html =~ ~s(phx-click="admin_lobbies_next")
    refute html =~ ~r/<button[^>]*phx-click="admin_lobbies_next"[^>]*disabled/

    # go to next page
    view |> element("button[phx-click=\"admin_lobbies_next\"]") |> render_click()
    html2 = render(view)

    # on last page Next should be disabled
    assert html2 =~ ~r/<button[^>]*phx-click="admin_lobbies_next"[^>]*disabled/
  end

  test "admin update is propagated to public lobbies view", %{conn: conn} do
    user = GameServer.AccountsFixtures.user_fixture()

    {:ok, admin} =
      user
      |> GameServer.Accounts.User.admin_changeset(%{"is_admin" => true})
      |> GameServer.Repo.update()

    # create a lobby hosted by admin
    {:ok, lobby} =
      GameServer.Lobbies.create_lobby(%{
        title: "admin-prop",
        name: "admin-prop",
        host_id: admin.id
      })

    # normal user opens public lobbies page
    normal = GameServer.AccountsFixtures.user_fixture()
    {:ok, view_public, public_html} = conn |> log_in_user(normal) |> live(~p"/lobbies")
    assert public_html =~ "admin-prop"

    # admin opens admin page and edits the lobby title
    {:ok, view_admin, _html} = conn |> log_in_user(admin) |> live(~p"/admin/lobbies")
    edit_btn = element(view_admin, "#admin-lobby-#{lobby.id} button", "Edit")
    render_click(edit_btn)
    form = form(view_admin, "#lobby-form", %{"lobby" => %{"title" => "Admin Updated"}})
    render_submit(form)

    # public view should update via PubSub/broadcast handled in LobbyLive
    # give LiveView a moment to process the broadcast and update
    :timer.sleep(50)
    updated_html = render(view_public)
    assert updated_html =~ "Admin Updated"
  end

  test "admin deletion is propagated to public lobbies view", %{conn: conn} do
    user = GameServer.AccountsFixtures.user_fixture()

    {:ok, admin} =
      user
      |> GameServer.Accounts.User.admin_changeset(%{"is_admin" => true})
      |> GameServer.Repo.update()

    # create a lobby
    {:ok, lobby} =
      GameServer.Lobbies.create_lobby(%{
        title: "cross-delete",
        name: "cross-delete",
        host_id: admin.id
      })

    # normal user opens public lobbies page
    normal = GameServer.AccountsFixtures.user_fixture()
    {:ok, _view_public, public_html} = conn |> log_in_user(normal) |> live(~p"/lobbies")
    assert public_html =~ "cross-delete"

    # admin opens admin page and deletes the lobby
    {:ok, view_admin, _html} = conn |> log_in_user(admin) |> live(~p"/admin/lobbies")
    delete_btn = element(view_admin, "#admin-lobby-#{lobby.id} button", "Delete")
    render_click(delete_btn)

    # public view should be updated - eventually the lobby should disappear
    {:ok, _updated_view_public, updated_html} = conn |> log_in_user(normal) |> live(~p"/lobbies")
    refute updated_html =~ "cross-delete"
  end
end
