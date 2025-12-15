defmodule GameServerWeb.AdminLive.KVTest do
  use GameServerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias GameServer.Accounts.User
  alias GameServer.AccountsFixtures
  alias GameServer.KV
  alias GameServer.Repo

  test "admin can view kv entries", %{conn: conn} do
    admin = AccountsFixtures.user_fixture()

    {:ok, admin} =
      admin
      |> User.admin_changeset(%{"is_admin" => true})
      |> Repo.update()

    u = AccountsFixtures.user_fixture()

    {:ok, _} = KV.put("admin-kv:global", %{v: 1}, %{"plugin" => "admin"})
    {:ok, _} = KV.put("admin-kv:user", %{v: 2}, %{"plugin" => "admin"}, user_id: u.id)

    {:ok, _lv, html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/admin/kv")

    assert html =~ "KV Entries"
    assert html =~ "admin-kv:global"
    assert html =~ "admin-kv:user"
  end
end
