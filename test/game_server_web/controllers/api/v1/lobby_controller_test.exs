defmodule GameServerWeb.Api.V1.LobbyControllerTest do
  use GameServerWeb.ConnCase

  alias GameServer.AccountsFixtures
  alias GameServer.Lobbies
  alias GameServerWeb.Auth.Guardian

  setup do
    {:ok, %{}}
  end

  test "GET /api/v1/lobbies lists lobbies but hides hidden ones", %{conn: conn} do
    host = AccountsFixtures.user_fixture()
    {:ok, lobby1} = Lobbies.create_lobby(%{name: "visible-room", host_id: host.id})
    {:ok, _hidden} = Lobbies.create_lobby(%{name: "hidden-room", hostless: true, is_hidden: true})

    conn = get(conn, "/api/v1/lobbies")
    resp = json_response(conn, 200)
    lobbies = resp["data"]
    assert Enum.any?(lobbies, fn l -> l["id"] == lobby1.id end)
    refute Enum.any?(lobbies, fn l -> l["id"] == _hidden.id end)
    # meta should include totals
    assert resp["meta"]["total_count"] == 1
    assert resp["meta"]["total_pages"] == 1
  end

  test "POST /api/v1/lobbies (hosted) requires auth and creates a lobby", %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    {:ok, token, _} = Guardian.encode_and_sign(user)

    conn =
      conn
      |> put_req_header("authorization", "Bearer " <> token)
      |> post("/api/v1/lobbies", %{name: "api-room"})

    assert conn.status == 201
    lobby = json_response(conn, 201)
    assert lobby["host_id"] == user.id
    # 'name' (slug) is omitted from API responses - the unique id is used instead
    refute Map.has_key?(lobby, "name")

    # 'name' intentionally omitted
  end

  test "POST /api/v1/lobbies hostless creation removed from public API returns unauthorized", %{
    conn: conn
  } do
    conn = post(conn, "/api/v1/lobbies", %{name: "service-room", hostless: true})
    assert conn.status == 401
  end

  test "POST /api/v1/lobbies/:id/join requires auth and manages lobby membership", %{conn: conn} do
    host = AccountsFixtures.user_fixture()
    other = AccountsFixtures.user_fixture()
    {:ok, lobby} = Lobbies.create_lobby(%{name: "api-join-room", host_id: host.id, max_users: 2})

    {:ok, token, _} = Guardian.encode_and_sign(other)

    conn =
      conn
      |> put_req_header("authorization", "Bearer " <> token)
      |> post("/api/v1/lobbies/#{lobby.id}/join", %{})

    # join returns 204 No Content now
    assert conn.status == 204

    reloaded = GameServer.Repo.get(GameServer.Accounts.User, other.id)
    assert reloaded.lobby_id == lobby.id
  end

  test "POST /api/v1/lobbies/:id/join with password requires correct password", %{conn: conn} do
    host = AccountsFixtures.user_fixture()
    other = AccountsFixtures.user_fixture()
    pw = "s3cret"
    phash = Bcrypt.hash_pwd_salt(pw)

    {:ok, lobby} =
      Lobbies.create_lobby(%{name: "pw-room-api", host_id: host.id, password_hash: phash})

    {:ok, token, _} = Guardian.encode_and_sign(other)

    conn1 =
      conn
      |> put_req_header("authorization", "Bearer " <> token)
      |> post("/api/v1/lobbies/#{lobby.id}/join", %{})

    assert conn1.status == 403

    conn2 =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token)
      |> post("/api/v1/lobbies/#{lobby.id}/join", %{password: "wrong"})

    assert conn2.status == 403

    conn3 =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> token)
      |> post("/api/v1/lobbies/#{lobby.id}/join", %{password: pw})

    # join should return 204 No Content now (no payload)
    assert conn3.status == 204
  end

  test "PATCH /api/v1/lobbies/:id update allowed for host only", %{conn: conn} do
    host = AccountsFixtures.user_fixture()
    other = AccountsFixtures.user_fixture()
    {:ok, lobby} = Lobbies.create_lobby(%{name: "update-room", host_id: host.id})

    {:ok, token_host, _} = Guardian.encode_and_sign(host)
    {:ok, token_other, _} = Guardian.encode_and_sign(other)

    conn1 =
      conn
      |> put_req_header("authorization", "Bearer " <> token_other)
      |> patch("/api/v1/lobbies/#{lobby.id}", %{title: "bad"})

    assert conn1.status in [403, 422]

    conn2 =
      conn
      |> put_req_header("authorization", "Bearer " <> token_host)
      |> patch("/api/v1/lobbies/#{lobby.id}", %{title: "New Title"})

    assert json_response(conn2, 200)["title"] == "New Title"
  end

  test "PATCH /api/v1/lobbies/:id cannot shrink max_users below current membership", %{conn: conn} do
    host = AccountsFixtures.user_fixture()
    member1 = AccountsFixtures.user_fixture()
    member2 = AccountsFixtures.user_fixture()
    {:ok, lobby} = Lobbies.create_lobby(%{name: "resize-room", host_id: host.id, max_users: 3})

    # two members join making total 3 (host + 2)
    assert {:ok, _} = Lobbies.join_lobby(member1, lobby)
    assert {:ok, _} = Lobbies.join_lobby(member2, lobby)

    {:ok, token_host, _} = Guardian.encode_and_sign(host)

    # attempt to shrink to 2 should fail
    conn_fail =
      conn
      |> put_req_header("authorization", "Bearer " <> token_host)
      |> patch("/api/v1/lobbies/#{lobby.id}", %{max_users: 2})

    assert conn_fail.status == 422
    assert json_response(conn_fail, 422)["error"] == "too_small"

    # increasing works
    conn_ok =
      conn
      |> put_req_header("authorization", "Bearer " <> token_host)
      |> patch("/api/v1/lobbies/#{lobby.id}", %{max_users: 6})

    assert json_response(conn_ok, 200)["max_users"] == 6
  end

  test "POST /api/v1/lobbies/:id/kick allowed for host", %{conn: conn} do
    host = AccountsFixtures.user_fixture()
    other = AccountsFixtures.user_fixture()
    {:ok, lobby} = Lobbies.create_lobby(%{name: "kick-api-room", host_id: host.id})
    assert {:ok, _} = Lobbies.join_lobby(other, lobby)

    {:ok, token_host, _} = Guardian.encode_and_sign(host)

    conn =
      conn
      |> put_req_header("authorization", "Bearer " <> token_host)
      |> post("/api/v1/lobbies/#{lobby.id}/kick", %{target_user_id: other.id})

    # kick returns 204 No Content now
    assert conn.status == 204

    reloaded = GameServer.Repo.get(GameServer.Accounts.User, other.id)
    assert is_nil(reloaded.lobby_id)
  end

  test "POST /api/v1/lobbies/:id/kick forbidden for non-host", %{conn: conn} do
    host = AccountsFixtures.user_fixture()
    member1 = AccountsFixtures.user_fixture()
    member2 = AccountsFixtures.user_fixture()
    {:ok, lobby} = Lobbies.create_lobby(%{name: "kick-forbidden-room", host_id: host.id})
    assert {:ok, _} = Lobbies.join_lobby(member1, lobby)
    assert {:ok, _} = Lobbies.join_lobby(member2, lobby)

    # member1 tries to kick member2 - should be forbidden
    {:ok, token_member1, _} = Guardian.encode_and_sign(member1)

    conn =
      conn
      |> put_req_header("authorization", "Bearer " <> token_member1)
      |> post("/api/v1/lobbies/#{lobby.id}/kick", %{target_user_id: member2.id})

    assert conn.status == 403
    assert json_response(conn, 403)["error"] == "not_host"

    # member2 should still be in the lobby
    reloaded = GameServer.Repo.get(GameServer.Accounts.User, member2.id)
    assert reloaded.lobby_id == lobby.id
  end

  test "POST /api/v1/lobbies/:id/kick host cannot kick self", %{conn: conn} do
    host = AccountsFixtures.user_fixture()
    {:ok, lobby} = Lobbies.create_lobby(%{name: "self-kick-room", host_id: host.id})

    {:ok, token_host, _} = Guardian.encode_and_sign(host)

    conn =
      conn
      |> put_req_header("authorization", "Bearer " <> token_host)
      |> post("/api/v1/lobbies/#{lobby.id}/kick", %{target_user_id: host.id})

    assert conn.status == 403
    assert json_response(conn, 403)["error"] == "cannot_kick_self"

    # host should still be in the lobby
    reloaded = GameServer.Repo.get(GameServer.Accounts.User, host.id)
    assert reloaded.lobby_id == lobby.id
  end

  test "POST /api/v1/lobbies/:id/leave removes user from lobby", %{conn: conn} do
    host = AccountsFixtures.user_fixture()
    member = AccountsFixtures.user_fixture()
    {:ok, lobby} = Lobbies.create_lobby(%{name: "leave-room", host_id: host.id})
    assert {:ok, _} = Lobbies.join_lobby(member, lobby)

    {:ok, token_member, _} = Guardian.encode_and_sign(member)

    conn =
      conn
      |> put_req_header("authorization", "Bearer " <> token_member)
      |> post("/api/v1/lobbies/#{lobby.id}/leave")

    # leave now returns 204 No Content
    assert conn.status == 204

    reloaded = GameServer.Repo.get(GameServer.Accounts.User, member.id)
    assert is_nil(reloaded.lobby_id)
  end
end
