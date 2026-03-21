defmodule GameServerWeb.AdminPagesRenderTest do
  @moduledoc """
  Basic render + permission tests for admin LiveView pages
  (live_session :require_admin).
  Ensures unauthenticated and non-admin users are redirected,
  and admin users can render every page.
  Also verifies pages render correctly when data exists (catches
  struct field access errors in templates).
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

  # ---------------------------------------------------------------------------
  # Data-seeded render tests — catches struct field access errors in templates
  # ---------------------------------------------------------------------------

  @seeded_routes [
    {"/admin/lobbies", "Lobbies"},
    {"/admin/parties", "Parties"},
    {"/admin/groups", "Groups"},
    {"/admin/leaderboards", "Leaderboards"},
    {"/admin/achievements", "Achievements"},
    {"/admin/kv", "KV"},
    {"/admin/notifications", "Notifications"},
    {"/admin/users", "Users"}
  ]

  defp seed_data(admin) do
    # Create a second user for relationships
    other = AccountsFixtures.user_fixture()

    # Lobby with a member
    {:ok, _lobby} =
      GameServer.Lobbies.create_lobby(%{title: "Seeded Lobby", hostless: true, max_users: 10})

    # Group with a member
    {:ok, _group} =
      GameServer.Groups.create_group(admin.id, %{
        "title" => "Seeded Group",
        "type" => "public",
        "max_members" => 50
      })

    # Party (requires friendship for invite, so just create with leader)
    {:ok, _party} = GameServer.Parties.create_party(admin, %{max_size: 4})

    # Leaderboard with a score
    {:ok, lb} =
      GameServer.Leaderboards.create_leaderboard(%{
        slug: "seeded_lb_#{System.unique_integer([:positive])}",
        title: "Seeded LB",
        sort_order: :desc,
        operator: :incr
      })

    GameServer.Leaderboards.submit_score(lb.id, admin.id, 100)

    # Achievement (unlocked for the admin user)
    slug = "seeded_ach_#{System.unique_integer([:positive])}"

    {:ok, _ach} =
      GameServer.Achievements.create_achievement(%{
        slug: slug,
        title: "Seeded Achievement",
        progress_target: 1
      })

    GameServer.Achievements.unlock_achievement(admin.id, slug)

    # KV entry
    GameServer.KV.put("seeded:key", %{v: 1}, %{"meta" => "data"})

    # Notification
    GameServer.Notifications.admin_create_notification(admin.id, other.id, %{
      "title" => "Seeded Notification",
      "content" => "Test",
      "metadata" => %{"type" => "system"}
    })

    :ok
  end

  describe "admin pages render correctly with actual data" do
    setup [:create_admin]

    setup %{admin: admin} do
      seed_data(admin)
      :ok
    end

    for {path, label} <- @seeded_routes do
      test "GET #{path} renders with #{label} data", %{conn: conn, admin: admin} do
        {:ok, _view, _html} = conn |> log_in_user(admin) |> live(unquote(path))
      end
    end
  end
end
