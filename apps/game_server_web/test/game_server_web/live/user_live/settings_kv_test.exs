defmodule GameServerWeb.UserLive.SettingsKVTest do
  use GameServerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias GameServer.AccountsFixtures
  alias GameServer.KV

  test "user can view their own kv entries", %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    other = AccountsFixtures.user_fixture()

    {:ok, _} = KV.put("my-kv:own", %{v: 1}, %{"m" => "a"}, user_id: user.id)
    {:ok, _} = KV.put("my-kv:other", %{v: 2}, %{"m" => "b"}, user_id: other.id)
    {:ok, _} = KV.put("my-kv:global", %{v: 3}, %{"m" => "g"})

    {:ok, _lv, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/users/settings")

    assert html =~ "Data"
    assert html =~ "my-kv:own"
    refute html =~ "my-kv:other"
    refute html =~ "my-kv:global"
  end

  test "user kv filter works", %{conn: conn} do
    user = AccountsFixtures.user_fixture()

    {:ok, e1} = KV.put("filter:key:aaa", %{v: 1}, %{"m" => "a"}, user_id: user.id)
    {:ok, e2} = KV.put("filter:key:bbb", %{v: 2}, %{"m" => "b"}, user_id: user.id)

    {:ok, lv, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/users/settings")

    _ = render_change(lv, :kv_filters_change, %{"filters" => %{"key" => ":aaa"}})

    assert has_element?(lv, "#user-kv-#{e1.id}")
    refute has_element?(lv, "#user-kv-#{e2.id}")
  end
end
