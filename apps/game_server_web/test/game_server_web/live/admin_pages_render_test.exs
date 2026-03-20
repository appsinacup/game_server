defmodule GameServerWeb.AdminPagesRenderTest do
  @moduledoc """
  Basic render + permission tests for admin LiveView pages
  (live_session :require_admin).
  Ensures unauthenticated and non-admin users are redirected,
  and admin users can render every page.
  """
  use GameServerWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias GameServer.Accounts.User
  alias GameServer.AccountsFixtures
  alias GameServer.Repo

  @admin_routes [
    {"/admin", "Admin"},
    {"/admin/config", "Config"},
    {"/admin/kv", "KV"},
    {"/admin/lobbies", "Lobbies"},
    {"/admin/leaderboards", "Leaderboards"},
    {"/admin/users", "Users"},
    {"/admin/sessions", "Sessions"},
    {"/admin/notifications", "Notifications"},
    {"/admin/groups", "Groups"},
    {"/admin/parties", "Parties"},
    {"/admin/chat", "Chat"},
    {"/admin/achievements", "Achievements"},
    {"/admin/translations", "Translation"}
  ]

  defp create_admin(_context) do
    admin = AccountsFixtures.user_fixture()

    {:ok, admin} =
      admin
      |> User.admin_changeset(%{"is_admin" => true})
      |> Repo.update()

    %{admin: admin}
  end

  describe "unauthenticated users are redirected from all admin pages" do
    for {path, _label} <- @admin_routes do
      test "GET #{path} redirects unauthenticated", %{conn: conn} do
        assert {:error, {:redirect, _}} = live(conn, unquote(path))
      end
    end
  end

  describe "non-admin authenticated users are redirected from all admin pages" do
    setup do
      # Ensure a first user exists so the test user is not auto-promoted
      _first = AccountsFixtures.user_fixture()
      user = AccountsFixtures.user_fixture()
      assert user.is_admin == false
      %{user: user}
    end

    for {path, _label} <- @admin_routes do
      test "GET #{path} redirects non-admin user", %{conn: conn, user: user} do
        conn = log_in_user(conn, user)

        assert {:error, {:redirect, _}} = live(conn, unquote(path))
      end
    end
  end

  describe "admin users can render all admin pages" do
    setup [:create_admin]

    for {path, _label} <- @admin_routes do
      test "GET #{path} renders for admin", %{conn: conn, admin: admin} do
        {:ok, _view, _html} = conn |> log_in_user(admin) |> live(unquote(path))
      end
    end
  end
end
