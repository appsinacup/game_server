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

  test "admin can filter kv entries by key and user", %{conn: conn} do
    admin = AccountsFixtures.user_fixture()

    {:ok, admin} =
      admin
      |> User.admin_changeset(%{"is_admin" => true})
      |> Repo.update()

    u1 = AccountsFixtures.user_fixture()
    u2 = AccountsFixtures.user_fixture()

    {:ok, e1} = KV.put("filter:key:aaa", %{v: 1}, %{"m" => "a"}, user_id: u1.id)
    {:ok, e2} = KV.put("filter:key:bbb", %{v: 2}, %{"m" => "b"}, user_id: u2.id)

    {:ok, lv, _html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/admin/kv")

    _ =
      render_change(lv, :filters_change, %{
        "filters" => %{"key" => ":aaa", "user_id" => ""}
      })

    assert has_element?(lv, "#admin-kv-#{e1.id}")
    refute has_element?(lv, "#admin-kv-#{e2.id}")

    _ =
      render_change(lv, :filters_change, %{
        "filters" => %{"key" => "", "user_id" => Integer.to_string(u2.id)}
      })

    assert has_element?(lv, "#admin-kv-#{e2.id}")
    refute has_element?(lv, "#admin-kv-#{e1.id}")
  end

  test "admin creating a duplicate key does not crash", %{conn: conn} do
    admin = AccountsFixtures.user_fixture()

    {:ok, admin} =
      admin
      |> User.admin_changeset(%{"is_admin" => true})
      |> Repo.update()

    {:ok, lv, _html} =
      conn
      |> log_in_user(admin)
      |> live(~p"/admin/kv")

    params = %{
      "id" => "",
      "key" => "admin-kv:duplicate-key",
      "user_id" => "",
      "value_json" => "{}",
      "metadata_json" => "{}"
    }

    _ =
      lv
      |> form("#admin-kv-form", kv: params)
      |> render_submit()

    assert KV.count_entries(key: "admin-kv:duplicate-key") == 1

    html =
      lv
      |> form("#admin-kv-form", kv: params)
      |> render_submit()

    assert KV.count_entries(key: "admin-kv:duplicate-key") == 1
    assert html =~ "Create failed"
  end
end
