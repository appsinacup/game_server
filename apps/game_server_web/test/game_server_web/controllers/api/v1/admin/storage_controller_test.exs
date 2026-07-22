defmodule GameServerWeb.Api.V1.Admin.StorageControllerTest do
  use GameServerWeb.ConnCase, async: false

  alias GameServer.Accounts.User
  alias GameServer.Repo
  alias GameServer.Storage
  alias GameServerWeb.Auth.Guardian

  setup %{conn: conn} do
    dir = Path.join(System.tmp_dir!(), "gs_admin_storage_#{System.unique_integer([:positive])}")
    old = Application.get_env(:game_server_core, GameServer.Storage.Local)
    Application.put_env(:game_server_core, GameServer.Storage.Local, dir: dir)

    on_exit(fn ->
      File.rm_rf(dir)
      if old, do: Application.put_env(:game_server_core, GameServer.Storage.Local, old)
    end)

    admin = GameServer.AccountsFixtures.user_fixture()
    {:ok, admin} = admin |> User.admin_changeset(%{"is_admin" => true}) |> Repo.update()
    {:ok, token, _} = Guardian.encode_and_sign(admin)
    %{conn: put_req_header(conn, "authorization", "Bearer " <> token)}
  end

  test "requires admin", %{conn: _conn} do
    user = GameServer.AccountsFixtures.user_fixture()
    {:ok, token, _} = Guardian.encode_and_sign(user)
    conn = build_conn() |> put_req_header("authorization", "Bearer " <> token)
    assert json_response(get(conn, "/api/v1/admin/storage"), 403)
  end

  test "lists objects with usage + meta", %{conn: conn} do
    Storage.put("avatars/a/1.png", "xx", content_type: "image/png")
    Storage.put("avatars/b/2.png", "xxxx", content_type: "image/png")

    body = json_response(get(conn, "/api/v1/admin/storage"), 200)

    assert body["usage"]["count"] == 2
    assert body["usage"]["bytes"] == 6
    assert length(body["data"]) == 2
    assert body["meta"]["total_count"] == 2
    assert Enum.all?(body["data"], &Map.has_key?(&1, "key"))
  end

  test "filters by prefix", %{conn: conn} do
    Storage.put("avatars/a/1.png", "x", content_type: "image/png")
    Storage.put("uploads/admin/x.png", "x", content_type: "image/png")

    body = json_response(get(conn, "/api/v1/admin/storage?prefix=avatars/"), 200)
    assert body["usage"]["count"] == 1
    assert hd(body["data"])["key"] == "avatars/a/1.png"
  end

  test "deletes an object", %{conn: conn} do
    Storage.put("avatars/a/1.png", "x", content_type: "image/png")
    assert Storage.exists?("avatars/a/1.png")

    assert json_response(delete(conn, "/api/v1/admin/storage?key=avatars/a/1.png"), 200)["ok"]
    refute Storage.exists?("avatars/a/1.png")
  end

  test "uploads to an arbitrary key and downloads it back", %{conn: conn} do
    key = "custom/path/notes.txt"

    up =
      conn
      |> put_req_header("content-type", "text/plain")
      |> put("/api/v1/admin/storage/object?key=#{URI.encode_www_form(key)}", "ADMIN BYTES")

    assert json_response(up, 200)["key"] == key
    assert Storage.exists?(key)

    down = get(conn, "/api/v1/admin/storage/object?key=#{URI.encode_www_form(key)}")
    assert down.status == 200
    assert down.resp_body == "ADMIN BYTES"
    assert get_resp_header(down, "content-type") |> hd() =~ "text/plain"
  end

  test "download of a missing key is 404", %{conn: conn} do
    assert json_response(get(conn, "/api/v1/admin/storage/object?key=nope/x.txt"), 404)
  end
end
