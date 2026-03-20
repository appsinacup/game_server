defmodule GameServerWeb.AdminPagesRenderTest do
  @moduledoc """
  Basic render tests for admin LiveView pages (live_session :require_admin).
  These catch crashes like missing assigns or template errors.
  """
  use GameServerWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias GameServer.Accounts.User
  alias GameServer.AccountsFixtures
  alias GameServer.Repo

  defp create_admin(_context) do
    admin = AccountsFixtures.user_fixture()

    {:ok, admin} =
      admin
      |> User.admin_changeset(%{"is_admin" => true})
      |> Repo.update()

    %{admin: admin}
  end

  describe "redirects non-admin users" do
    test "GET /admin/leaderboards redirects unauthenticated", %{conn: conn} do
      assert {:error, {:redirect, _}} = live(conn, ~p"/admin/leaderboards")
    end

    test "GET /admin/notifications redirects unauthenticated", %{conn: conn} do
      assert {:error, {:redirect, _}} = live(conn, ~p"/admin/notifications")
    end

    test "GET /admin/groups redirects unauthenticated", %{conn: conn} do
      assert {:error, {:redirect, _}} = live(conn, ~p"/admin/groups")
    end
  end

  describe "admin pages render" do
    setup [:create_admin]

    test "GET /admin/leaderboards renders", %{conn: conn, admin: admin} do
      {:ok, _view, html} = conn |> log_in_user(admin) |> live(~p"/admin/leaderboards")
      assert html =~ "Leaderboards"
    end

    test "GET /admin/notifications renders", %{conn: conn, admin: admin} do
      {:ok, _view, html} = conn |> log_in_user(admin) |> live(~p"/admin/notifications")
      assert html =~ "Notifications"
    end

    test "GET /admin/groups renders", %{conn: conn, admin: admin} do
      {:ok, _view, html} = conn |> log_in_user(admin) |> live(~p"/admin/groups")
      assert html =~ "Groups"
    end

    test "GET /admin/parties renders", %{conn: conn, admin: admin} do
      {:ok, _view, html} = conn |> log_in_user(admin) |> live(~p"/admin/parties")
      assert html =~ "Parties"
    end

    test "GET /admin/chat renders", %{conn: conn, admin: admin} do
      {:ok, _view, html} = conn |> log_in_user(admin) |> live(~p"/admin/chat")
      assert html =~ "Chat"
    end

    test "GET /admin/achievements renders", %{conn: conn, admin: admin} do
      {:ok, _view, html} = conn |> log_in_user(admin) |> live(~p"/admin/achievements")
      assert html =~ "Achievements"
    end

    test "GET /admin/translations renders", %{conn: conn, admin: admin} do
      {:ok, _view, html} = conn |> log_in_user(admin) |> live(~p"/admin/translations")
      assert html =~ "Translation"
    end
  end
end
