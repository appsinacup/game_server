defmodule GameServerWeb.Api.V1.PartyControllerTest do
  use GameServerWeb.ConnCase

  alias GameServer.AccountsFixtures
  alias GameServer.Lobbies
  alias GameServer.Parties
  alias GameServerWeb.Auth.Guardian

  setup do
    {:ok, %{}}
  end

  defp auth_conn(conn, user) do
    {:ok, token, _} = Guardian.encode_and_sign(user)
    put_req_header(conn, "authorization", "Bearer " <> token)
  end

  describe "POST /api/v1/parties" do
    test "creates a party", %{conn: conn} do
      user = AccountsFixtures.user_fixture()

      conn =
        conn
        |> auth_conn(user)
        |> post("/api/v1/parties", %{max_size: 4})

      assert conn.status == 201
      body = json_response(conn, 201)
      assert body["leader_id"] == user.id
      assert body["max_size"] == 4
      assert length(body["members"]) == 1
    end

    test "returns conflict if already in a party", %{conn: conn} do
      user = AccountsFixtures.user_fixture()
      {:ok, _party} = Parties.create_party(user, %{})

      conn =
        conn
        |> auth_conn(user)
        |> post("/api/v1/parties", %{})

      assert json_response(conn, 409)["error"] == "already_in_party"
    end

    test "requires auth", %{conn: conn} do
      conn = post(conn, "/api/v1/parties", %{})
      assert conn.status == 401
    end
  end

  describe "GET /api/v1/parties/me" do
    test "returns current party", %{conn: conn} do
      user = AccountsFixtures.user_fixture()
      {:ok, party} = Parties.create_party(user, %{max_size: 4})

      conn =
        conn
        |> auth_conn(user)
        |> get("/api/v1/parties/me")

      body = json_response(conn, 200)
      assert body["id"] == party.id
      assert body["leader_id"] == user.id
    end

    test "returns 404 when not in a party", %{conn: conn} do
      user = AccountsFixtures.user_fixture()

      conn =
        conn
        |> auth_conn(user)
        |> get("/api/v1/parties/me")

      assert json_response(conn, 404)["error"] == "not_in_party"
    end
  end

  describe "POST /api/v1/parties/invite" do
    test "leader can invite a user", %{conn: conn} do
      leader = AccountsFixtures.user_fixture()
      target = AccountsFixtures.user_fixture()
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})

      conn =
        conn
        |> auth_conn(leader)
        |> post("/api/v1/parties/invite", %{target_user_id: target.id})

      body = json_response(conn, 201)
      assert body["message"] == "invite_sent"
    end

    test "returns error when not in a party", %{conn: conn} do
      user = AccountsFixtures.user_fixture()
      target = AccountsFixtures.user_fixture()

      conn =
        conn
        |> auth_conn(user)
        |> post("/api/v1/parties/invite", %{target_user_id: target.id})

      assert json_response(conn, 400)["error"] == "not_in_party"
    end

    test "returns error when not leader", %{conn: conn} do
      leader = AccountsFixtures.user_fixture()
      member = AccountsFixtures.user_fixture()
      target = AccountsFixtures.user_fixture()
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      {:ok, _} = Parties.join_party(member, party.id)

      conn =
        conn
        |> auth_conn(member)
        |> post("/api/v1/parties/invite", %{target_user_id: target.id})

      assert json_response(conn, 403)["error"] == "not_leader"
    end

    test "returns error when inviting self", %{conn: conn} do
      leader = AccountsFixtures.user_fixture()
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})

      conn =
        conn
        |> auth_conn(leader)
        |> post("/api/v1/parties/invite", %{target_user_id: leader.id})

      assert json_response(conn, 400)["error"] == "self_invite"
    end

    test "requires auth", %{conn: conn} do
      conn = post(conn, "/api/v1/parties/invite", %{target_user_id: 1})
      assert conn.status == 401
    end
  end

  describe "GET /api/v1/parties/invites" do
    test "lists pending invites", %{conn: conn} do
      leader = AccountsFixtures.user_fixture()
      target = AccountsFixtures.user_fixture()
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})
      {:ok, _} = Parties.invite_to_party(leader, target.id)

      conn =
        conn
        |> auth_conn(target)
        |> get("/api/v1/parties/invites")

      body = json_response(conn, 200)
      assert length(body["data"]) == 1
      assert body["meta"]["total_count"] == 1
    end

    test "returns empty list when no invites", %{conn: conn} do
      user = AccountsFixtures.user_fixture()

      conn =
        conn
        |> auth_conn(user)
        |> get("/api/v1/parties/invites")

      body = json_response(conn, 200)
      assert body["data"] == []
      assert body["meta"]["total_count"] == 0
    end
  end

  describe "GET /api/v1/parties/sent_invites" do
    test "lists sent invites", %{conn: conn} do
      leader = AccountsFixtures.user_fixture()
      target = AccountsFixtures.user_fixture()
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})
      {:ok, _} = Parties.invite_to_party(leader, target.id)

      conn =
        conn
        |> auth_conn(leader)
        |> get("/api/v1/parties/sent_invites")

      body = json_response(conn, 200)
      assert length(body["data"]) == 1
    end
  end

  describe "POST /api/v1/parties/invites/:id/accept" do
    test "user can accept an invite", %{conn: conn} do
      leader = AccountsFixtures.user_fixture()
      target = AccountsFixtures.user_fixture()
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      {:ok, notification} = Parties.invite_to_party(leader, target.id)

      conn =
        conn
        |> auth_conn(target)
        |> post("/api/v1/parties/invites/#{notification.id}/accept")

      body = json_response(conn, 200)
      assert body["id"] == party.id
      assert length(body["members"]) == 2
    end

    test "returns 404 for non-existent invite", %{conn: conn} do
      user = AccountsFixtures.user_fixture()

      conn =
        conn
        |> auth_conn(user)
        |> post("/api/v1/parties/invites/999999/accept")

      assert json_response(conn, 404)["error"] == "invite_not_found"
    end

    test "returns error when party is full", %{conn: conn} do
      leader = AccountsFixtures.user_fixture()
      member = AccountsFixtures.user_fixture()
      target = AccountsFixtures.user_fixture()
      {:ok, party} = Parties.create_party(leader, %{max_size: 2})
      {:ok, notification} = Parties.invite_to_party(leader, target.id)

      # Fill the party
      {:ok, _} = Parties.join_party(member, party.id)

      conn =
        conn
        |> auth_conn(target)
        |> post("/api/v1/parties/invites/#{notification.id}/accept")

      assert json_response(conn, 403)["error"] == "party_full"
    end
  end

  describe "POST /api/v1/parties/invites/:id/decline" do
    test "user can decline an invite", %{conn: conn} do
      leader = AccountsFixtures.user_fixture()
      target = AccountsFixtures.user_fixture()
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})
      {:ok, notification} = Parties.invite_to_party(leader, target.id)

      conn =
        conn
        |> auth_conn(target)
        |> post("/api/v1/parties/invites/#{notification.id}/decline")

      body = json_response(conn, 200)
      assert body["message"] == "invite_declined"
    end

    test "returns 404 for non-existent invite", %{conn: conn} do
      user = AccountsFixtures.user_fixture()

      conn =
        conn
        |> auth_conn(user)
        |> post("/api/v1/parties/invites/999999/decline")

      assert json_response(conn, 404)["error"] == "invite_not_found"
    end
  end

  describe "DELETE /api/v1/parties/invites/:id" do
    test "leader can cancel a sent invite", %{conn: conn} do
      leader = AccountsFixtures.user_fixture()
      target = AccountsFixtures.user_fixture()
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})
      {:ok, notification} = Parties.invite_to_party(leader, target.id)

      conn =
        conn
        |> auth_conn(leader)
        |> delete("/api/v1/parties/invites/#{notification.id}")

      body = json_response(conn, 200)
      assert body["message"] == "invite_cancelled"
    end

    test "returns 404 for non-existent invite", %{conn: conn} do
      leader = AccountsFixtures.user_fixture()
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})

      conn =
        conn
        |> auth_conn(leader)
        |> delete("/api/v1/parties/invites/999999")

      assert json_response(conn, 404)["error"] == "invite_not_found"
    end

    test "returns error when not sender", %{conn: conn} do
      leader = AccountsFixtures.user_fixture()
      target = AccountsFixtures.user_fixture()
      other = AccountsFixtures.user_fixture()
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})
      {:ok, notification} = Parties.invite_to_party(leader, target.id)

      conn =
        conn
        |> auth_conn(other)
        |> delete("/api/v1/parties/invites/#{notification.id}")

      assert json_response(conn, 403)["error"] == "not_sender"
    end
  end

  describe "POST /api/v1/parties/leave" do
    test "leaves the party", %{conn: conn} do
      leader = AccountsFixtures.user_fixture()
      member = AccountsFixtures.user_fixture()
      {:ok, party} = Parties.create_party(leader, %{})
      {:ok, _} = Parties.join_party(member, party.id)

      conn =
        conn
        |> auth_conn(member)
        |> post("/api/v1/parties/leave")

      assert json_response(conn, 200) == %{}

      # Party should still exist (leader didn't leave)
      assert Parties.get_party(party.id) != nil
    end

    test "leader leaving disbands the party", %{conn: conn} do
      leader = AccountsFixtures.user_fixture()
      {:ok, party} = Parties.create_party(leader, %{})

      conn =
        conn
        |> auth_conn(leader)
        |> post("/api/v1/parties/leave")

      assert json_response(conn, 200) == %{}
      assert is_nil(Parties.get_party(party.id))
    end
  end

  describe "POST /api/v1/parties/kick" do
    test "leader can kick a member", %{conn: conn} do
      leader = AccountsFixtures.user_fixture()
      member = AccountsFixtures.user_fixture()
      {:ok, party} = Parties.create_party(leader, %{})
      {:ok, _} = Parties.join_party(member, party.id)

      conn =
        conn
        |> auth_conn(leader)
        |> post("/api/v1/parties/kick", %{target_user_id: member.id})

      assert json_response(conn, 200) == %{}
    end

    test "non-leader cannot kick", %{conn: conn} do
      leader = AccountsFixtures.user_fixture()
      member = AccountsFixtures.user_fixture()
      {:ok, party} = Parties.create_party(leader, %{})
      {:ok, _} = Parties.join_party(member, party.id)

      conn =
        conn
        |> auth_conn(member)
        |> post("/api/v1/parties/kick", %{target_user_id: leader.id})

      assert json_response(conn, 403)["error"] == "not_leader"
    end
  end

  describe "PATCH /api/v1/parties" do
    test "leader can update party", %{conn: conn} do
      leader = AccountsFixtures.user_fixture()
      {:ok, _party} = Parties.create_party(leader, %{max_size: 4})

      conn =
        conn
        |> auth_conn(leader)
        |> patch("/api/v1/parties", %{max_size: 8})

      body = json_response(conn, 200)
      assert body["max_size"] == 8
    end
  end

  describe "POST /api/v1/parties/create_lobby" do
    test "leader creates lobby for whole party", %{conn: conn} do
      leader = AccountsFixtures.user_fixture()
      member = AccountsFixtures.user_fixture()
      {:ok, party} = Parties.create_party(leader, %{})
      {:ok, _} = Parties.join_party(member, party.id)

      conn =
        conn
        |> auth_conn(leader)
        |> post("/api/v1/parties/create_lobby", %{title: "party-lobby", max_users: 8})

      assert conn.status == 201
      body = json_response(conn, 201)
      assert body["title"] == "party-lobby"

      # Party should still exist
      assert Parties.get_party(party.id) != nil
    end

    test "non-leader cannot create lobby", %{conn: conn} do
      leader = AccountsFixtures.user_fixture()
      member = AccountsFixtures.user_fixture()
      {:ok, party} = Parties.create_party(leader, %{})
      {:ok, _} = Parties.join_party(member, party.id)

      conn =
        conn
        |> auth_conn(member)
        |> post("/api/v1/parties/create_lobby", %{title: "nope"})

      assert json_response(conn, 403)["error"] == "not_leader"
    end
  end

  describe "POST /api/v1/parties/join_lobby/:id" do
    test "leader joins lobby with whole party", %{conn: conn} do
      leader = AccountsFixtures.user_fixture()
      member = AccountsFixtures.user_fixture()
      {:ok, party} = Parties.create_party(leader, %{})
      {:ok, _} = Parties.join_party(member, party.id)

      # Create lobby with different host
      host = AccountsFixtures.user_fixture()
      {:ok, lobby} = Lobbies.create_lobby(%{title: "existing-lobby", host_id: host.id})

      conn =
        conn
        |> auth_conn(leader)
        |> post("/api/v1/parties/join_lobby/#{lobby.id}")

      body = json_response(conn, 200)
      assert body["id"] == lobby.id

      # Party should still exist
      assert Parties.get_party(party.id) != nil
    end

    test "fails when lobby too full", %{conn: conn} do
      leader = AccountsFixtures.user_fixture()
      member1 = AccountsFixtures.user_fixture()
      member2 = AccountsFixtures.user_fixture()
      {:ok, party} = Parties.create_party(leader, %{max_size: 4})
      {:ok, _} = Parties.join_party(member1, party.id)
      {:ok, _} = Parties.join_party(member2, party.id)

      # Create a tiny lobby
      host = AccountsFixtures.user_fixture()

      {:ok, lobby} =
        Lobbies.create_lobby(%{title: "tiny-lobby", host_id: host.id, max_users: 3})

      conn =
        conn
        |> auth_conn(leader)
        |> post("/api/v1/parties/join_lobby/#{lobby.id}")

      assert json_response(conn, 403)["error"] == "not_enough_space"
    end
  end
end
