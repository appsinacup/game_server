defmodule GameServerWeb.Api.V1.GroupControllerTest.HooksDenyGroupJoin do
  def before_group_join(_user, _group, _opts), do: {:error, :level_too_low}
end

defmodule GameServerWeb.Api.V1.GroupControllerTest do
  use GameServerWeb.ConnCase

  alias GameServer.AccountsFixtures
  alias GameServer.Groups
  alias GameServerWeb.Auth.Guardian

  setup do
    {:ok, %{}}
  end

  defp auth_conn(conn, user) do
    {:ok, token, _} = Guardian.encode_and_sign(user)
    put_req_header(conn, "authorization", "Bearer " <> token)
  end

  defp create_user do
    AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
  end

  # ---------------------------------------------------------------------------
  # Index / Show
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/groups" do
    test "lists public groups", %{conn: conn} do
      owner = create_user()
      {:ok, _} = Groups.create_group(owner.id, %{"title" => "Listed", "type" => "public"})

      conn = get(conn, "/api/v1/groups")
      assert %{"data" => data} = json_response(conn, 200)
      titles = Enum.map(data, & &1["title"])
      assert "Listed" in titles
    end

    test "excludes hidden groups", %{conn: conn} do
      owner = create_user()
      {:ok, _} = Groups.create_group(owner.id, %{"title" => "Secret", "type" => "hidden"})

      conn = get(conn, "/api/v1/groups")
      %{"data" => data} = json_response(conn, 200)
      titles = Enum.map(data, & &1["title"])
      refute "Secret" in titles
    end

    test "supports pagination params", %{conn: conn} do
      owner = create_user()

      for i <- 1..3 do
        {:ok, _} = Groups.create_group(owner.id, %{"title" => "Pg#{i}", "type" => "public"})
      end

      conn = get(conn, "/api/v1/groups?page=1&page_size=2")
      assert %{"data" => data, "meta" => meta} = json_response(conn, 200)
      assert length(data) == 2
      assert meta["page"] == 1
      assert meta["page_size"] == 2
    end

    test "supports title filter", %{conn: conn} do
      owner = create_user()
      {:ok, _} = Groups.create_group(owner.id, %{"title" => "FilterTarget", "type" => "public"})
      {:ok, _} = Groups.create_group(owner.id, %{"title" => "Other", "type" => "public"})

      conn = get(conn, "/api/v1/groups?title=FilterTarget")
      assert %{"data" => data} = json_response(conn, 200)
      assert length(data) == 1
      assert hd(data)["title"] == "FilterTarget"
    end
  end

  describe "GET /api/v1/groups/:id" do
    test "shows a group", %{conn: conn} do
      owner = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Shown"})

      conn = get(conn, "/api/v1/groups/#{group.id}")
      assert %{"id" => _, "title" => "Shown"} = json_response(conn, 200)
    end

    test "returns 404 for missing group", %{conn: conn} do
      conn = get(conn, "/api/v1/groups/999999")
      assert json_response(conn, 404)
    end

    test "returns 404 for non-numeric id", %{conn: conn} do
      conn = get(conn, "/api/v1/groups/abc")
      assert json_response(conn, 404)
    end
  end

  # ---------------------------------------------------------------------------
  # Create / Update / Delete
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/groups" do
    test "creates a group (authenticated)", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> auth_conn(user)
        |> post("/api/v1/groups", %{title: "Created", type: "public"})

      assert %{"id" => _, "title" => "Created"} = json_response(conn, 201)
    end

    test "returns 401 without auth", %{conn: conn} do
      conn = post(conn, "/api/v1/groups", %{title: "NoAuth"})
      assert conn.status == 401
    end

    test "returns error with missing title", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> auth_conn(user)
        |> post("/api/v1/groups", %{type: "public"})

      assert conn.status == 409
    end
  end

  describe "PATCH /api/v1/groups/:id" do
    test "admin can update group", %{conn: conn} do
      user = create_user()
      {:ok, group} = Groups.create_group(user.id, %{"title" => "Old"})

      conn =
        conn
        |> auth_conn(user)
        # update the title
        |> patch("/api/v1/groups/#{group.id}", %{title: "New"})

      assert %{"title" => "New"} = json_response(conn, 200)
    end

    test "non-admin cannot update", %{conn: conn} do
      owner = create_user()
      other = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Locked"})

      conn =
        conn
        |> auth_conn(other)
        |> patch("/api/v1/groups/#{group.id}", %{title: "Hacked"})

      assert json_response(conn, 403)
    end
  end

  # ---------------------------------------------------------------------------
  # Join / Leave
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/groups/:id/join" do
    test "user can join public group", %{conn: conn} do
      owner = create_user()
      joiner = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "JoinMe", "type" => "public"})

      conn =
        conn
        |> auth_conn(joiner)
        |> post("/api/v1/groups/#{group.id}/join")

      assert json_response(conn, 200)
      assert Groups.member?(group.id, joiner.id)
    end

    test "creates join request when joining private group", %{conn: conn} do
      owner = create_user()
      joiner = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "PrvJoin", "type" => "private"})

      conn =
        conn
        |> auth_conn(joiner)
        |> post("/api/v1/groups/#{group.id}/join")

      assert %{"status" => "pending"} = json_response(conn, 201)
      refute Groups.member?(group.id, joiner.id)
    end

    test "returns 403 when joining hidden group", %{conn: conn} do
      owner = create_user()
      joiner = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "HidJoin", "type" => "hidden"})

      conn =
        conn
        |> auth_conn(joiner)
        |> post("/api/v1/groups/#{group.id}/join")

      assert %{"error" => "not_joinable"} = json_response(conn, 403)
    end

    test "returns 403 when already a member", %{conn: conn} do
      owner = create_user()
      joiner = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "AlrJoin", "type" => "public"})
      {:ok, _} = Groups.join_group(joiner.id, group.id)

      conn =
        conn
        |> auth_conn(joiner)
        |> post("/api/v1/groups/#{group.id}/join")

      assert %{"error" => "already_member"} = json_response(conn, 403)
    end

    test "returns 401 without auth", %{conn: conn} do
      owner = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "NoAuthJoin"})

      conn = post(conn, "/api/v1/groups/#{group.id}/join")
      assert conn.status == 401
    end

    test "returns 403 when blocked by before_group_join hook", %{conn: conn} do
      original = Application.get_env(:game_server_core, :hooks_module)

      on_exit(fn ->
        if original do
          Application.put_env(:game_server_core, :hooks_module, original)
        else
          Application.delete_env(:game_server_core, :hooks_module)
        end
      end)

      Application.put_env(
        :game_server_core,
        :hooks_module,
        GameServerWeb.Api.V1.GroupControllerTest.HooksDenyGroupJoin
      )

      owner = create_user()
      joiner = create_user()

      {:ok, group} =
        Groups.create_group(owner.id, %{"title" => "JoinBlocked", "type" => "public"})

      conn =
        conn
        |> auth_conn(joiner)
        |> post("/api/v1/groups/#{group.id}/join")

      assert %{"error" => "level_too_low"} = json_response(conn, 403)
      refute Groups.member?(group.id, joiner.id)
    end
  end

  describe "POST /api/v1/groups/:id/leave" do
    test "member can leave group", %{conn: conn} do
      owner = create_user()
      member = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "LeaveMe", "type" => "public"})
      {:ok, _} = Groups.join_group(member.id, group.id)

      conn =
        conn
        |> auth_conn(member)
        |> post("/api/v1/groups/#{group.id}/leave")

      assert json_response(conn, 200)
      refute Groups.member?(group.id, member.id)
    end

    test "returns 400 when not a member", %{conn: conn} do
      owner = create_user()
      other = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "CantLeave", "type" => "public"})

      conn =
        conn
        |> auth_conn(other)
        |> post("/api/v1/groups/#{group.id}/leave")

      assert %{"error" => "not_member"} = json_response(conn, 400)
    end
  end

  # ---------------------------------------------------------------------------
  # Kick / Promote / Demote
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/groups/:id/kick" do
    test "admin can kick a member", %{conn: conn} do
      owner = create_user()
      target = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "KickGrp", "type" => "public"})
      {:ok, _} = Groups.join_group(target.id, group.id)

      conn =
        conn
        |> auth_conn(owner)
        |> post("/api/v1/groups/#{group.id}/kick", %{target_user_id: target.id})

      assert json_response(conn, 200)
      refute Groups.member?(group.id, target.id)
    end

    test "non-admin cannot kick", %{conn: conn} do
      owner = create_user()
      member = create_user()
      target = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "NoKick", "type" => "public"})
      {:ok, _} = Groups.join_group(member.id, group.id)
      {:ok, _} = Groups.join_group(target.id, group.id)

      conn =
        conn
        |> auth_conn(member)
        |> post("/api/v1/groups/#{group.id}/kick", %{target_user_id: target.id})

      assert json_response(conn, 403)
    end

    test "returns 401 without auth", %{conn: conn} do
      owner = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "NAKick"})

      conn = post(conn, "/api/v1/groups/#{group.id}/kick", %{target_user_id: 1})
      assert conn.status == 401
    end
  end

  describe "POST /api/v1/groups/:id/promote" do
    test "admin can promote member", %{conn: conn} do
      owner = create_user()
      target = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "PromoGrp", "type" => "public"})
      {:ok, _} = Groups.join_group(target.id, group.id)

      conn =
        conn
        |> auth_conn(owner)
        |> post("/api/v1/groups/#{group.id}/promote", %{target_user_id: target.id})

      assert json_response(conn, 200)
      assert Groups.admin?(group.id, target.id)
    end
  end

  describe "POST /api/v1/groups/:id/demote" do
    test "admin can demote another admin", %{conn: conn} do
      owner = create_user()
      target = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "DemoGrp", "type" => "public"})
      {:ok, _} = Groups.join_group(target.id, group.id)
      {:ok, _} = Groups.promote_member(owner.id, group.id, target.id)

      conn =
        conn
        |> auth_conn(owner)
        |> post("/api/v1/groups/#{group.id}/demote", %{target_user_id: target.id})

      assert json_response(conn, 200)
      refute Groups.admin?(group.id, target.id)
    end
  end

  # ---------------------------------------------------------------------------
  # Join Requests
  # ---------------------------------------------------------------------------

  describe "join request via POST /api/v1/groups/:id/join (private group)" do
    test "user can request to join private group via join endpoint", %{conn: conn} do
      owner = create_user()
      other = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "PrvReq", "type" => "private"})

      conn =
        conn
        |> auth_conn(other)
        |> post("/api/v1/groups/#{group.id}/join")

      assert %{"status" => "pending"} = json_response(conn, 201)
    end

    test "returns error when user already requested", %{conn: conn} do
      owner = create_user()
      other = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "DupReq", "type" => "private"})
      {:ok, _} = Groups.request_join(other.id, group.id)

      conn =
        conn
        |> auth_conn(other)
        |> post("/api/v1/groups/#{group.id}/join")

      assert %{"error" => "already_requested"} = json_response(conn, 403)
    end
  end

  describe "GET /api/v1/groups/:id/join_requests" do
    test "admin can list pending requests", %{conn: conn} do
      owner = create_user()
      other = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "ListReq", "type" => "private"})
      {:ok, _} = Groups.request_join(other.id, group.id)

      conn =
        conn
        |> auth_conn(owner)
        |> get("/api/v1/groups/#{group.id}/join_requests")

      assert %{"data" => [%{"status" => "pending"}]} = json_response(conn, 200)
    end
  end

  describe "POST /api/v1/groups/:id/join_requests/:request_id/approve" do
    test "admin approves join request", %{conn: conn} do
      owner = create_user()
      other = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "ApprReq", "type" => "private"})
      {:ok, request} = Groups.request_join(other.id, group.id)

      conn =
        conn
        |> auth_conn(owner)
        |> post("/api/v1/groups/#{group.id}/join_requests/#{request.id}/approve")

      assert json_response(conn, 200)
      assert Groups.member?(group.id, other.id)
    end
  end

  describe "POST /api/v1/groups/:id/join_requests/:request_id/reject" do
    test "admin rejects join request", %{conn: conn} do
      owner = create_user()
      other = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "RejReq", "type" => "private"})
      {:ok, request} = Groups.request_join(other.id, group.id)

      conn =
        conn
        |> auth_conn(owner)
        |> post("/api/v1/groups/#{group.id}/join_requests/#{request.id}/reject")

      assert %{"status" => "rejected"} = json_response(conn, 200)
    end
  end

  describe "DELETE /api/v1/groups/:id/join_requests/:request_id (cancel)" do
    test "user can cancel own pending request", %{conn: conn} do
      owner = create_user()
      other = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "CnclReq", "type" => "private"})
      {:ok, request} = Groups.request_join(other.id, group.id)

      conn =
        conn
        |> auth_conn(other)
        |> delete("/api/v1/groups/#{group.id}/join_requests/#{request.id}")

      assert json_response(conn, 200)
      assert Groups.list_user_pending_requests(other.id) == []
    end

    test "cannot cancel another user's request", %{conn: conn} do
      owner = create_user()
      other = create_user()
      third = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "NoCncl", "type" => "private"})
      {:ok, request} = Groups.request_join(other.id, group.id)

      conn =
        conn
        |> auth_conn(third)
        |> delete("/api/v1/groups/#{group.id}/join_requests/#{request.id}")

      assert json_response(conn, 403)
    end
  end

  # ---------------------------------------------------------------------------
  # Members
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/groups/:id/members" do
    test "lists group members", %{conn: conn} do
      owner = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "Mems"})

      conn = get(conn, "/api/v1/groups/#{group.id}/members")
      assert %{"data" => members} = json_response(conn, 200)
      assert length(members) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # My Groups
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/groups/me" do
    test "returns user's groups", %{conn: conn} do
      user = create_user()
      {:ok, _} = Groups.create_group(user.id, %{"title" => "Mine1"})

      conn =
        conn
        |> auth_conn(user)
        |> get("/api/v1/groups/me")

      assert %{"data" => [%{"title" => "Mine1"}]} = json_response(conn, 200)
    end

    test "returns 401 without auth", %{conn: conn} do
      conn = get(conn, "/api/v1/groups/me")
      assert conn.status == 401
    end

    test "returns empty list when user has no groups", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> auth_conn(user)
        |> get("/api/v1/groups/me")

      assert %{"data" => []} = json_response(conn, 200)
    end
  end

  # ---------------------------------------------------------------------------
  # Invite / Accept Invite
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/groups/:id/invite" do
    test "admin can invite user to group", %{conn: conn} do
      owner = create_user()
      target = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "InvAPI", "type" => "hidden"})

      conn =
        conn
        |> auth_conn(owner)
        |> post("/api/v1/groups/#{group.id}/invite", %{target_user_id: target.id})

      assert json_response(conn, 200)
    end

    test "non-admin cannot invite", %{conn: conn} do
      owner = create_user()
      non_admin = create_user()
      target = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "NoInvAPI", "type" => "hidden"})

      conn =
        conn
        |> auth_conn(non_admin)
        |> post("/api/v1/groups/#{group.id}/invite", %{target_user_id: target.id})

      assert %{"error" => "not_admin"} = json_response(conn, 403)
    end
  end

  describe "POST /api/v1/groups/:id/accept_invite" do
    test "user can accept invite and join hidden group", %{conn: conn} do
      owner = create_user()
      target = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "AccInv", "type" => "hidden"})
      {:ok, _} = Groups.invite_to_group(owner.id, group.id, target.id)

      conn =
        conn
        |> auth_conn(target)
        |> post("/api/v1/groups/#{group.id}/accept_invite")

      assert json_response(conn, 200)
      assert Groups.member?(group.id, target.id)
    end

    test "returns 403 for non-hidden group", %{conn: conn} do
      owner = create_user()
      target = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "PubAccInv", "type" => "public"})

      conn =
        conn
        |> auth_conn(target)
        |> post("/api/v1/groups/#{group.id}/accept_invite")

      assert %{"error" => "not_hidden"} = json_response(conn, 403)
    end
  end

  # ---------------------------------------------------------------------------
  # Sent Invitations
  # ---------------------------------------------------------------------------

  describe "GET /api/v1/groups/sent_invitations" do
    test "lists invitations sent by user", %{conn: conn} do
      owner = create_user()
      target = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "InvGrp", "type" => "hidden"})
      {:ok, _} = Groups.invite_to_group(owner.id, group.id, target.id)

      conn =
        conn
        |> auth_conn(owner)
        |> get("/api/v1/groups/sent_invitations")

      assert %{"data" => [%{"group_name" => "InvGrp", "recipient_id" => _}]} =
               json_response(conn, 200)
    end

    test "returns empty when no invitations sent", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> auth_conn(user)
        |> get("/api/v1/groups/sent_invitations")

      assert %{"data" => []} = json_response(conn, 200)
    end

    test "returns 401 without auth", %{conn: conn} do
      conn = get(conn, "/api/v1/groups/sent_invitations")
      assert conn.status == 401
    end
  end

  describe "DELETE /api/v1/groups/sent_invitations/:invite_id (cancel_invite)" do
    test "sender can cancel their own invitation", %{conn: conn} do
      owner = create_user()
      target = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "CnclInv", "type" => "hidden"})
      {:ok, _} = Groups.invite_to_group(owner.id, group.id, target.id)

      [%{id: inv_id}] = Groups.list_sent_invitations(owner.id)

      conn =
        conn
        |> auth_conn(owner)
        |> delete("/api/v1/groups/sent_invitations/#{inv_id}")

      assert %{"status" => "cancelled"} = json_response(conn, 200)
      assert Groups.list_sent_invitations(owner.id) == []
    end

    test "cannot cancel another user's invitation", %{conn: conn} do
      owner = create_user()
      target = create_user()
      third = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "NoCancel", "type" => "hidden"})
      {:ok, _} = Groups.invite_to_group(owner.id, group.id, target.id)

      [%{id: inv_id}] = Groups.list_sent_invitations(owner.id)

      conn =
        conn
        |> auth_conn(third)
        |> delete("/api/v1/groups/sent_invitations/#{inv_id}")

      assert json_response(conn, 403)
    end

    test "returns 404 for non-existent invitation", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> auth_conn(user)
        |> delete("/api/v1/groups/sent_invitations/999999")

      assert json_response(conn, 404)
    end

    test "returns 401 without auth", %{conn: conn} do
      conn = delete(conn, "/api/v1/groups/sent_invitations/1")
      assert conn.status == 401
    end
  end

  # ---------------------------------------------------------------------------
  # Notify Group
  # ---------------------------------------------------------------------------

  describe "POST /api/v1/groups/:id/notify" do
    test "member can send notification to group", %{conn: conn} do
      owner = create_user()
      member = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "NotifAPI", "type" => "public"})
      {:ok, _} = Groups.join_group(member.id, group.id)

      conn =
        conn
        |> auth_conn(member)
        |> post("/api/v1/groups/#{group.id}/notify", %{content: "Hello from API!"})

      assert %{"sent" => 1} = json_response(conn, 200)
    end

    test "non-member gets 403", %{conn: conn} do
      owner = create_user()
      outsider = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "NoNotifAPI", "type" => "public"})

      conn =
        conn
        |> auth_conn(outsider)
        |> post("/api/v1/groups/#{group.id}/notify", %{content: "Denied"})

      assert %{"error" => "not_member"} = json_response(conn, 403)
    end

    test "returns 404 for non-existent group", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> auth_conn(user)
        |> post("/api/v1/groups/999999/notify", %{content: "Missing"})

      assert json_response(conn, 404)
    end

    test "returns 401 without auth", %{conn: conn} do
      conn = post(conn, "/api/v1/groups/1/notify", %{content: "No auth"})
      assert conn.status == 401
    end

    test "accepts custom title", %{conn: conn} do
      owner = create_user()
      member = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "TitleAPI", "type" => "public"})
      {:ok, _} = Groups.join_group(member.id, group.id)

      conn =
        conn
        |> auth_conn(member)
        |> post("/api/v1/groups/#{group.id}/notify", %{
          content: "Custom title!",
          title: "game_event"
        })

      assert %{"sent" => 1} = json_response(conn, 200)
    end
  end

  # ---------------------------------------------------------------------------
  # Pagination
  # ---------------------------------------------------------------------------

  describe "pagination" do
    test "members endpoint returns meta", %{conn: conn} do
      owner = create_user()
      {:ok, group} = Groups.create_group(owner.id, %{"title" => "PagMem"})

      conn = get(conn, "/api/v1/groups/#{group.id}/members")
      body = json_response(conn, 200)
      assert is_list(body["data"])
      assert body["meta"]["total_count"] == 1
      assert body["meta"]["page"] == 1
    end

    test "my_groups endpoint returns meta", %{conn: conn} do
      user = create_user()
      {:ok, _} = Groups.create_group(user.id, %{"title" => "PagMine"})

      conn =
        conn
        |> auth_conn(user)
        |> get("/api/v1/groups/me")

      body = json_response(conn, 200)
      assert is_list(body["data"])
      assert body["meta"]["total_count"] == 1
    end

    test "invitations endpoint returns meta", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> auth_conn(user)
        |> get("/api/v1/groups/invitations")

      body = json_response(conn, 200)
      assert is_list(body["data"])
      assert body["meta"]["total_count"] == 0
    end

    test "sent_invitations endpoint returns meta", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> auth_conn(user)
        |> get("/api/v1/groups/sent_invitations")

      body = json_response(conn, 200)
      assert is_list(body["data"])
      assert body["meta"]["total_count"] == 0
    end
  end
end
