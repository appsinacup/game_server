defmodule GameServerWeb.AdminLive.MatchmakingTest do
  use GameServerWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias GameServer.Accounts
  alias GameServer.AccountsFixtures
  alias GameServer.Matchmaking

  setup %{conn: conn} do
    # First user in an empty DB may be auto-promoted; create a decoy first.
    _decoy = AccountsFixtures.user_fixture()
    user = AccountsFixtures.user_fixture()
    {:ok, admin} = Accounts.update_user(user, %{is_admin: true})

    %{conn: log_in_user(conn, admin)}
  end

  defp named_player(display_name) do
    {:ok, user} =
      Accounts.update_user_display_name(AccountsFixtures.user_fixture(), %{
        "display_name" => display_name
      })

    # The sweep prunes tickets of offline users, so mark them online.
    {:ok, user} = user |> Ecto.Changeset.change(is_online: true) |> GameServer.Repo.update()
    user
  end

  test "shows stats, queues and tickets with player names, not UUIDs", %{conn: conn} do
    player = named_player("Ada Lovelace")
    {:ok, ticket} = Matchmaking.join(player, %{"mode" => "duel"})

    {:ok, _view, html} = live(conn, ~p"/admin/matchmaking")

    assert html =~ "Ada Lovelace"
    refute html =~ ticket.user_id
    assert html =~ "mode=duel"
    assert html =~ "Queued"
  end

  test "filters by status", %{conn: conn} do
    queued = named_player("Queued Player")
    cancelled = named_player("Cancelled Player")
    {:ok, _} = Matchmaking.join(queued, %{"mode" => "duel"})
    {:ok, ticket} = Matchmaking.join(cancelled, %{"mode" => "duel"})
    {:ok, _} = Matchmaking.cancel_ticket(ticket.id)

    {:ok, view, _html} = live(conn, ~p"/admin/matchmaking")

    html =
      view
      |> form("#matchmaking-filter-form", %{"status" => "cancelled", "user_id" => ""})
      |> render_change()

    assert html =~ "Cancelled Player"
    refute html =~ "Queued Player"
  end

  test "force-cancels a queued ticket", %{conn: conn} do
    player = named_player("To Cancel")
    {:ok, ticket} = Matchmaking.join(player, %{"mode" => "duel"})

    {:ok, view, _html} = live(conn, ~p"/admin/matchmaking")

    html =
      view
      |> element(~s|#ticket-#{ticket.id} button[phx-click="cancel_ticket"]|)
      |> render_click()

    assert html =~ "Ticket cancelled"
    assert Matchmaking.current_ticket(player.id) == nil
  end

  test "run sweep now forms matches from the page", %{conn: conn} do
    {:ok, _} = Matchmaking.join(named_player("P One"), %{"mode" => "duel"}, 2, 2)
    {:ok, _} = Matchmaking.join(named_player("P Two"), %{"mode" => "duel"}, 2, 2)

    {:ok, view, _html} = live(conn, ~p"/admin/matchmaking")

    html = view |> element("#sweep-now-btn") |> render_click()
    assert html =~ "1 match(es) formed"
  end
end
