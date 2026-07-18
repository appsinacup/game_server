defmodule GameServerWeb.TournamentsLiveTest do
  use GameServerWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias GameServer.AccountsFixtures
  alias GameServer.Tournaments

  defp create_tournament(attrs \\ %{}) do
    defaults = %{
      slug: "cup-#{System.unique_integer([:positive])}",
      title: "Public Cup",
      description: "A public bracket cup",
      starts_at: DateTime.add(DateTime.utc_now(:second), 3600),
      round_window_sec: 600,
      bracket_size: 4
    }

    {:ok, tournament} = Tournaments.create_tournament(Map.merge(defaults, attrs))
    tournament
  end

  defp join(tournament, n) do
    for _ <- 1..n do
      {:ok, entry} =
        Tournaments.join_tournament(
          AccountsFixtures.user_fixture(),
          Tournaments.advance_lifecycle(tournament)
        )

      entry
    end
  end

  defp draw!(tournament) do
    {:ok, tournament} =
      Tournaments.update_tournament(tournament, %{starts_at: DateTime.utc_now(:second)})

    Tournaments.advance_lifecycle(tournament)
  end

  test "index shows one card per slug, not per edition", %{conn: conn} do
    slug = "cup-#{System.unique_integer([:positive])}"
    _old = create_tournament(%{slug: slug, state: "finished"})
    current = create_tournament(%{slug: slug})
    join(current, 2)

    {:ok, _view, html} = live(conn, ~p"/tournaments")

    # one card, with the edition count badge, not two "Public Cup" cards
    assert length(String.split(html, "card-title")) - 1 == 1
    assert html =~ "Public Cup"
    assert html =~ "Players: 2"
  end

  test "index paginates", %{conn: conn} do
    for _ <- 1..3, do: create_tournament()

    {:ok, view, _html} = live(conn, ~p"/tournaments")
    # 3 tournaments fit one page (page size 25): no pager rendered
    refute render(view) =~ "Page 1 of"
  end

  test "detail shows registrants before the draw", %{conn: conn} do
    tournament = create_tournament()
    join(tournament, 3)

    {:ok, _view, html} = live(conn, ~p"/tournaments/#{tournament.id}")

    assert html =~ "Registered players"
    # stat cards render the label and value separately
    assert html =~ "Players"
    assert html =~ ~s(<div class="text-2xl font-bold">3</div>)
  end

  test "detail shows brackets after the draw and links into one", %{conn: conn} do
    tournament = create_tournament()
    join(tournament, 4)
    tournament = draw!(tournament)

    {:ok, view, html} = live(conn, ~p"/tournaments/#{tournament.id}")

    assert html =~ "Brackets"
    assert html =~ "Bracket 1"
    assert html =~ "matches decided"

    assert view
           |> element(~s|a[href="/tournaments/#{tournament.id}/brackets/0"]|)
           |> has_element?()
  end

  test "bracket view renders the tree with rounds and winners", %{conn: conn} do
    tournament = create_tournament()
    join(tournament, 4)
    tournament = draw!(tournament)

    [semi | _] = Tournaments.list_matches(tournament.id) |> Enum.filter(&(&1.round == 1))
    {:ok, _} = Tournaments.resolve_match(semi.id, semi.a_entry_id)

    {:ok, _view, html} = live(conn, ~p"/tournaments/#{tournament.id}/brackets/0")

    assert html =~ "Bracket 1"
    # 4-slot bracket: round 1 is the semifinal, round 2 the final
    assert html =~ "Semifinal"
    assert html =~ "Final"
    # the resolved match marks a winner
    assert html =~ "✓"
  end

  test "bracket view shows byes for empty round-1 slots", %{conn: conn} do
    tournament = create_tournament()
    join(tournament, 3)
    tournament = draw!(tournament)

    {:ok, _view, html} = live(conn, ~p"/tournaments/#{tournament.id}/brackets/0")

    assert html =~ "bye"
  end

  test "detail navigates between editions of the same slug", %{conn: conn} do
    slug = "cup-#{System.unique_integer([:positive])}"
    past = create_tournament(%{slug: slug, state: "finished", starts_at: DateTime.add(DateTime.utc_now(:second), -86_400)})
    current = create_tournament(%{slug: slug})

    {:ok, view, html} = live(conn, ~p"/tournaments/#{current.id}")
    assert html =~ "Older"
    assert html =~ "#2"

    html = view |> element("button[phx-click='older_edition']") |> render_click()
    assert html =~ "#1"
    assert_patched(view, ~p"/tournaments/#{past.id}")

    # a one-shot tournament has no edition navigation
    solo = create_tournament()
    {:ok, _view, html} = live(conn, ~p"/tournaments/#{solo.id}")
    refute html =~ "Older"
  end

  test "unknown tournament or bracket redirects to the index", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/tournaments"}}} =
             live(conn, ~p"/tournaments/#{Ecto.UUID.generate()}")

    tournament = create_tournament()

    assert {:error, {:live_redirect, %{to: "/tournaments"}}} =
             live(conn, ~p"/tournaments/#{tournament.id}/brackets/9")
  end

  test "tournament is reachable by slug", %{conn: conn} do
    tournament = create_tournament()

    {:ok, _view, html} = live(conn, ~p"/tournaments/#{tournament.slug}")
    assert html =~ "Public Cup"
  end
end
