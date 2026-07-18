defmodule GameServerWeb.AdminLive.BlacklistTest do
  use GameServerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias GameServer.Accounts.User
  alias GameServer.AccountsFixtures
  alias GameServer.Friends
  alias GameServer.Repo

  setup %{conn: conn} do
    admin = AccountsFixtures.user_fixture()
    {:ok, admin} = admin |> User.admin_changeset(%{"is_admin" => true}) |> Repo.update()

    blocker = AccountsFixtures.user_fixture()
    blocked = AccountsFixtures.user_fixture()
    {:ok, block} = Friends.block_user(blocker, blocked.id)

    %{
      conn: log_in_user(conn, admin),
      blocker: blocker,
      blocked: blocked,
      block: block
    }
  end

  test "lists blocks with blocker and blocked on the right sides", %{
    conn: conn,
    blocker: blocker,
    blocked: blocked
  } do
    {:ok, _lv, html} = live(conn, ~p"/admin/blacklist")

    assert html =~ blocker.id
    assert html =~ blocked.id
    assert html =~ "Blacklist (1)"
  end

  test "unblock removes the block and the pairing stops being enforced", %{
    conn: conn,
    blocker: blocker,
    blocked: blocked,
    block: block
  } do
    {:ok, lv, _html} = live(conn, ~p"/admin/blacklist")

    html =
      lv
      |> element("#block-#{block.id} button", "Unblock")
      |> render_click()

    assert html =~ "Block removed"
    assert html =~ "No blocks."
    refute Friends.blocked?(blocker.id, blocked.id)
  end

  test "filters by a user on either side of the block", %{
    conn: conn,
    blocker: blocker,
    blocked: blocked
  } do
    other = AccountsFixtures.user_fixture()
    stranger = AccountsFixtures.user_fixture()
    {:ok, _} = Friends.block_user(other, stranger.id)

    {:ok, lv, _html} = live(conn, ~p"/admin/blacklist")

    # the blocked side matches too, not just the blocker
    html =
      lv
      |> form("#blacklist-filter-form", %{"user_id" => blocked.id})
      |> render_change()

    assert html =~ blocker.id
    refute html =~ stranger.id
  end
end
