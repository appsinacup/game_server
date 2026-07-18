defmodule GameServerWeb.PlayerSearchTest do
  @moduledoc """
  Searching a long player list by name, on the pages that show one.
  """
  use GameServerWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias GameServer.AccountsFixtures
  alias GameServer.Groups
  alias GameServer.Leaderboards
  alias GameServer.Repo

  defp named_user(display_name) do
    AccountsFixtures.user_fixture()
    |> Ecto.Changeset.change(display_name: display_name)
    |> Repo.update!()
  end

  describe "leaderboard records" do
    setup do
      {:ok, leaderboard} =
        Leaderboards.create_leaderboard(%{
          slug: "search_#{System.unique_integer([:positive])}",
          title: "Search Cup"
        })

      ada = named_user("Ada Lovelace")
      grace = named_user("Grace Hopper")

      # Grace outscores Ada, so Grace is rank 1 and Ada rank 2.
      {:ok, _} = Leaderboards.submit_score(leaderboard.id, grace.id, 900)
      {:ok, _} = Leaderboards.submit_score(leaderboard.id, ada.id, 100)

      %{leaderboard: leaderboard}
    end

    test "filters by name and keeps the real rank", %{conn: conn, leaderboard: leaderboard} do
      {:ok, view, html} = live(conn, ~p"/leaderboards/#{leaderboard.slug}")
      assert html =~ "Ada Lovelace"
      assert html =~ "Grace Hopper"

      html = view |> form("#records-search-form", %{"search" => "ada"}) |> render_change()

      assert html =~ "Ada Lovelace"
      refute html =~ "Grace Hopper"
      # rank 2 of the whole board, not "1" because she is the only match left
      assert html =~ ~r|<td class="font-mono">\s*<span[^>]*>\s*2\s*</span>|
    end

    test "search is case-insensitive and matches partial names", %{
      conn: conn,
      leaderboard: leaderboard
    } do
      {:ok, view, _html} = live(conn, ~p"/leaderboards/#{leaderboard.slug}")

      html = view |> form("#records-search-form", %{"search" => "HOPP"}) |> render_change()
      assert html =~ "Grace Hopper"
      refute html =~ "Ada Lovelace"
    end

    test "clearing the search restores the full board", %{conn: conn, leaderboard: leaderboard} do
      {:ok, view, _html} = live(conn, ~p"/leaderboards/#{leaderboard.slug}")

      view |> form("#records-search-form", %{"search" => "ada"}) |> render_change()
      html = view |> form("#records-search-form", %{"search" => ""}) |> render_change()

      assert html =~ "Ada Lovelace"
      assert html =~ "Grace Hopper"
    end

    test "a search matching nobody reports no results", %{conn: conn, leaderboard: leaderboard} do
      {:ok, view, _html} = live(conn, ~p"/leaderboards/#{leaderboard.slug}")

      html = view |> form("#records-search-form", %{"search" => "zzz"}) |> render_change()
      assert html =~ "No results."
    end
  end

  describe "group members" do
    setup do
      owner = named_user("Ada Lovelace")
      grace = named_user("Grace Hopper")

      {:ok, group} =
        Groups.create_group(owner.id, %{"title" => "Search Guild", "type" => "public"})

      {:ok, _} = Groups.join_group(grace.id, group.id)

      %{group: group}
    end

    test "filters members by name", %{conn: conn, group: group} do
      {:ok, view, html} = live(conn, ~p"/groups/#{group.id}")
      assert html =~ "Ada Lovelace"
      assert html =~ "Grace Hopper"

      html = view |> form("#members-search-form", %{"search" => "grace"}) |> render_change()

      assert html =~ "Grace Hopper"
      refute html =~ "Ada Lovelace"
    end

    test "the roster size stat ignores the search", %{conn: conn, group: group} do
      {:ok, view, _html} = live(conn, ~p"/groups/#{group.id}")

      html = view |> form("#members-search-form", %{"search" => "grace"}) |> render_change()

      # the stat card still reports both members, only the table is filtered
      assert html =~ "2 /"
    end
  end
end
