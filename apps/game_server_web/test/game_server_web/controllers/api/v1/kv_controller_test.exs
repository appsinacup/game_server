defmodule GameServerWeb.Api.V1.KvControllerTest do
  use GameServerWeb.ConnCase

  alias GameServer.AccountsFixtures
  alias GameServer.KV
  alias GameServer.Repo

  setup do
    # Ensure default hooks module
    orig = Application.get_env(:game_server_core, :hooks_module)
    on_exit(fn -> Application.put_env(:game_server_core, :hooks_module, orig) end)
    :ok
  end

  test "GET /api/v1/kv/:key requires auth and returns public global value", %{conn: conn} do
    KV.put("global_foo", %{"a" => 1}, %{})

    # unauthenticated should be rejected (route requires auth)
    resp_unauth = get(conn, "/api/v1/kv/global_foo")
    assert resp_unauth.status == 401

    # authenticated non-admin user can retrieve public kv
    user = AccountsFixtures.user_fixture()
    {:ok, token, _} = GameServerWeb.Auth.Guardian.encode_and_sign(user)
    conn_auth = put_req_header(conn, "authorization", "Bearer " <> token)

    resp = get(conn_auth, "/api/v1/kv/global_foo") |> json_response(200)
    assert resp["data"] == %{"a" => 1}
  end

  test "private global kv is forbidden for anonymous and allowed for admin", %{conn: conn} do
    # install a test hooks module that marks "secret" as private
    mod_name = String.to_atom("TestHooksPrivate_#{System.unique_integer([:positive])}")

    Module.create(
      mod_name,
      quote do
        def before_kv_get(key, _opts) when key == "secret", do: :private
        def before_kv_get(_k, _o), do: :public
      end,
      Macro.Env.location(__ENV__)
    )

    Application.put_env(:game_server_core, :hooks_module, mod_name)

    KV.put("secret", %{"x" => 1}, %{})

    # unauthenticated should be 401 (route requires auth)
    conn_anon = get(conn, "/api/v1/kv/secret")
    assert conn_anon.status == 401

    # admin user can access
    admin = AccountsFixtures.user_fixture()

    {:ok, admin} =
      GameServer.Accounts.User.admin_changeset(admin, %{"is_admin" => true}) |> Repo.update()

    {:ok, token, _} = GameServerWeb.Auth.Guardian.encode_and_sign(admin)
    conn_admin = put_req_header(conn, "authorization", "Bearer " <> token)
    resp = get(conn_admin, "/api/v1/kv/secret") |> json_response(200)
    assert resp["data"] == %{"x" => 1}
  end

  test "private per-user kv readable only by owner", %{conn: conn} do
    mod_name = String.to_atom("TestHooksPrivateAll_#{System.unique_integer([:positive])}")

    Module.create(
      mod_name,
      quote do
        def before_kv_get(_k, _opts), do: :private
      end,
      Macro.Env.location(__ENV__)
    )

    Application.put_env(:game_server_core, :hooks_module, mod_name)

    owner = AccountsFixtures.user_fixture()
    {:ok, _entry} = KV.put("user_key", %{"v" => 2}, %{}, user_id: owner.id)

    # owner can get
    {:ok, token, _} = GameServerWeb.Auth.Guardian.encode_and_sign(owner)
    conn_owner = put_req_header(conn, "authorization", "Bearer " <> token)
    resp = get(conn_owner, "/api/v1/kv/user_key?user_id=#{owner.id}") |> json_response(200)
    assert resp["data"] == %{"v" => 2}

    # another user cannot
    other = AccountsFixtures.user_fixture()
    {:ok, token2, _} = GameServerWeb.Auth.Guardian.encode_and_sign(other)
    conn_other = put_req_header(conn, "authorization", "Bearer " <> token2)
    r = get(conn_other, "/api/v1/kv/user_key?user_id=#{owner.id}")
    assert r.status == 403
  end
end
