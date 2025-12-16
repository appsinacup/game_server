defmodule GameServerWeb.LobbyLiveTest do
  use GameServerWeb.ConnCase
  import Phoenix.LiveViewTest

  alias GameServer.Lobbies

  test "listing and creating lobbies (requires auth)", %{conn: conn} do
    # create/auth user
    user = GameServer.AccountsFixtures.user_fixture()

    logged_conn = conn |> log_in_user(user)

    {:ok, view, html} = live(logged_conn, "/lobbies")
    assert html =~ "Lobbies"

    # create a lobby using form (authenticated) - only title now
    form = form(view, "form", %{title: "LiveView Room"})
    render_submit(form)

    assert view |> render() =~ "LiveView Room"
  end

  test "user cannot create multiple lobbies (already host)", %{conn: conn} do
    user = GameServer.AccountsFixtures.user_fixture()
    logged_conn = conn |> log_in_user(user)

    {:ok, view, _html} = live(logged_conn, "/lobbies")

    # create first lobby
    form1 = form(view, "form", %{title: "Solo"})
    render_submit(form1)

    # attempt to create another
    form2 = form(view, "form", %{title: "Second"})
    render_submit(form2)

    # show flash and ensure second not created
    assert view |> render() =~ "You are already in a lobby"
    # only one lobby should exist
    assert length(Lobbies.list_lobbies()) == 1
  end

  test "join redirects to login when unauthenticated", %{conn: conn} do
    {:ok, lobby} = Lobbies.create_lobby(%{title: "lv-join", hostless: true})

    {:ok, view, _html} = live(conn, "/lobbies")
    # simulate join click for existing lobby
    ref = element(view, "#lobby-#{lobby.id} button", "Join")
    render_click(ref)
    # not authenticated so should redirect to login
    assert_redirect(view, "/users/log-in")
  end

  test "password protected lobby requires password to join", %{conn: conn} do
    {:ok, lobby} = Lobbies.create_lobby(%{title: "pw-room", hostless: true, password: "s3cret"})

    user = GameServer.AccountsFixtures.user_fixture()
    logged_conn = conn |> log_in_user(user)

    {:ok, view, _html} = live(logged_conn, "/lobbies")

    # click Join to reveal password form
    join_button = element(view, "#lobby-#{lobby.id} button", "Join")
    render_click(join_button)

    # submit invalid password
    pw_form = form(view, "#lobby-#{lobby.id} form", %{"_id" => lobby.id, "password" => "wrong"})
    render_submit(pw_form)

    # still not joined
    reloaded_user = GameServer.Accounts.get_user!(user.id)
    assert reloaded_user.lobby_id == nil

    # submit correct password
    pw_form_ok =
      form(view, "#lobby-#{lobby.id} form", %{"_id" => lobby.id, "password" => "s3cret"})

    render_submit(pw_form_ok)

    reloaded_user = GameServer.Accounts.get_user!(user.id)
    assert reloaded_user.lobby_id == lobby.id
  end

  test "host can manage lobby and kick members", %{conn: conn} do
    host = GameServer.AccountsFixtures.user_fixture()
    member = GameServer.AccountsFixtures.user_fixture(%{email: "member@example.com"})

    {:ok, lobby} = Lobbies.create_lobby(%{title: "host-room", host_id: host.id})

    # member joins
    {:ok, _} = Lobbies.join_lobby(member, lobby.id)

    logged_host_conn = conn |> log_in_user(host)
    {:ok, view, _html} = live(logged_host_conn, "/lobbies")

    # host is in lobby, so they see Manage button for the lobby they are in
    # But since host is also in that lobby, they should see "Leave" first, then Manage
    # Actually, per new UI logic: if user.lobby_id == lobby.id -> Leave, if user.id == lobby.host_id -> Manage, else -> View
    # So host should see Manage button when their lobby_id matches AND they are host
    # Actually, the condition first checks if user is in the lobby (shows Leave), then if user is host (shows Manage)
    # So if host is in their own lobby, they see Leave first due to cond ordering
    # Let me verify the UI shows "Leave" because host is in the lobby
    # Actually, looking at the render code: user.lobby_id == lobby.id -> Leave, user.id == lobby.host_id -> Manage
    # Since host.lobby_id == lobby.id (from create_lobby), they see Leave, not Manage
    # Let's adjust the test to click Manage via start_manage event
    render_click(view, "start_manage", %{"id" => lobby.id})

    # update lobby attributes
    form_el =
      form(view, "#lobby-#{lobby.id} form", %{
        "_id" => lobby.id,
        "title" => "New Title",
        "max_users" => "4",
        "is_locked" => "true"
      })

    render_submit(form_el)

    l2 = Lobbies.get_lobby!(lobby.id)
    assert l2.title == "New Title"
    assert l2.max_users == 4
    assert l2.is_locked == true

    # kick member
    kick_btn = element(view, "#member-#{member.id} button", "Kick")
    render_click(kick_btn)

    reloaded_member = GameServer.Accounts.get_user!(member.id)
    assert reloaded_member.lobby_id == nil
  end

  test "member can leave a lobby from lobbies view", %{conn: conn} do
    # Create a hostless lobby for a user to join
    {:ok, lobby} = Lobbies.create_lobby(%{title: "join-room", hostless: true})

    user = GameServer.AccountsFixtures.user_fixture()
    logged = conn |> log_in_user(user)

    {:ok, view, _html} = live(logged, "/lobbies")

    # user joins the lobby (not as host)
    join_button = element(view, "#lobby-#{lobby.id} button", "Join")
    render_click(join_button)

    # After joining, user sees "View" button to open the detail panel
    assert render(view) =~ "View"

    # Click View to open the manage/view panel
    view_button = element(view, "#lobby-#{lobby.id} button", "View")
    render_click(view_button)

    # Now we're in the view panel, there should be a Leave button in the members list
    assert render(view) =~ "Leave"

    # click leave
    leave_btn = element(view, "button", "Leave")
    render_click(leave_btn)

    refreshed = GameServer.Accounts.get_user!(user.id)
    assert refreshed.lobby_id == nil
  end

  test "non-host cannot see kick buttons in view mode", %{conn: conn} do
    host = GameServer.AccountsFixtures.user_fixture()
    member = GameServer.AccountsFixtures.user_fixture(%{email: "member2@example.com"})

    {:ok, lobby} = Lobbies.create_lobby(%{title: "view-only-room", host_id: host.id})

    # member joins
    {:ok, _} = Lobbies.join_lobby(member, lobby.id)

    logged_member_conn = conn |> log_in_user(member)
    {:ok, view, _html} = live(logged_member_conn, "/lobbies")

    # member clicks View to open the detail panel
    view_button = element(view, "#lobby-#{lobby.id} button", "View")
    render_click(view_button)

    html = render(view)

    # member should see Leave button for themselves
    assert html =~ "Leave"
    # member should NOT see Kick buttons (only host can kick)
    refute html =~ "Kick"
  end

  test "non-host cannot kick via direct event", %{conn: conn} do
    host = GameServer.AccountsFixtures.user_fixture()
    member = GameServer.AccountsFixtures.user_fixture(%{email: "member3@example.com"})
    target = GameServer.AccountsFixtures.user_fixture(%{email: "target@example.com"})

    {:ok, lobby} = Lobbies.create_lobby(%{title: "kick-attempt-room", host_id: host.id})
    {:ok, _} = Lobbies.join_lobby(member, lobby.id)
    {:ok, _} = Lobbies.join_lobby(target, lobby.id)

    logged_member_conn = conn |> log_in_user(member)
    {:ok, view, _html} = live(logged_member_conn, "/lobbies")

    # member tries to kick target by sending the event directly
    render_click(view, "kick", %{"lobby_id" => lobby.id, "target_id" => target.id})

    # target should still be in the lobby (kick should fail because member is not host)
    refreshed_target = GameServer.Accounts.get_user!(target.id)
    assert refreshed_target.lobby_id == lobby.id

    # should show error flash
    assert render(view) =~ "not_host"
  end

  test "lobbies pagination displays totals and enables/disables Next", %{conn: conn} do
    # create more than default page_size=12 so we have multiple pages
    for i <- 1..15 do
      GameServer.Lobbies.create_lobby(%{title: "pagi-#{i}", hostless: true})
    end

    {:ok, view, html} = live(conn, "/lobbies")

    assert html =~ "(15 total)"
    assert html =~ "/ 2"

    # first page Next should be enabled (no disabled attr on lobbies_next)
    assert html =~ ~s(phx-click="lobbies_next")
    refute html =~ ~r/<button[^>]*phx-click="lobbies_next"[^>]*disabled/

    # go to next page
    render_click(view, "lobbies_next", %{})
    html2 = render(view)

    # on last page Next should be disabled
    assert html2 =~ ~r/<button[^>]*phx-click="lobbies_next"[^>]*disabled/
  end
end
