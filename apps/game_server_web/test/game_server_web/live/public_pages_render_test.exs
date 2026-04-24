defmodule GameServerWeb.PublicPagesRenderTest do
  @moduledoc """
  Basic render tests for public LiveView pages (live_session :current_user).
  These catch crashes like missing assigns or template errors.
  """
  use GameServerWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "unauthenticated" do
    test "GET /leaderboards renders", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/leaderboards")
      assert html =~ "Leaderboards"
    end

    test "GET /achievements renders", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/achievements")
      assert html =~ "Achievements"
    end

    test "GET /groups renders", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/groups")
      assert html =~ "Groups"
    end

    test "GET /docs/setup renders", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/docs/setup")
      assert html =~ "Documentation"
      assert html =~ "Core Setup"
      assert html =~ "Elixir App Starter"
    end

    test "GET /changelog renders", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/changelog")
      assert html =~ "Changelog"
    end

    test "GET /blog renders", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/blog")
      assert html =~ "Blog"
    end
  end

  describe "authenticated" do
    setup :register_and_log_in_user

    test "GET /leaderboards renders when logged in", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/leaderboards")
      assert html =~ "Leaderboards"
    end

    test "GET /achievements renders when logged in", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/achievements")
      assert html =~ "Achievements"
    end

    test "GET /groups renders when logged in", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/groups")
      assert html =~ "Groups"
    end
  end
end
