defmodule GameServerWeb.Api.V1.Admin.MatchmakingAdminControllerTest do
  use GameServerWeb.ConnCase, async: false

  alias GameServer.Accounts
  alias GameServer.AccountsFixtures
  alias GameServer.Matchmaking
  alias GameServerWeb.Auth.Guardian

  defp bearer_conn(conn, user) do
    {:ok, token, _} = Guardian.encode_and_sign(user)
    put_req_header(conn, "authorization", "Bearer " <> token)
  end

  setup %{conn: conn} do
    user = AccountsFixtures.user_fixture()
    {:ok, admin} = Accounts.update_user(user, %{is_admin: true})
    player = AccountsFixtures.user_fixture()

    %{admin_conn: bearer_conn(conn, admin), player: player, plain_conn: conn}
  end

  test "GET /tickets lists with filters, pagination meta and user names", %{
    admin_conn: admin_conn,
    player: player
  } do
    {:ok, ticket} = Matchmaking.join(player, %{"mode" => "duel"})
    {:ok, other} = Matchmaking.join(AccountsFixtures.user_fixture(), %{"mode" => "ffa"})
    {:ok, _} = Matchmaking.cancel_ticket(other.id)

    conn = get(admin_conn, "/api/v1/admin/matchmaking/tickets", %{"status" => "queued"})
    assert %{"data" => [row], "meta" => meta} = json_response(conn, 200)
    assert row["id"] == ticket.id
    assert row["user_id"] == player.id
    assert meta["total_count"] == 1
    assert meta["page"] == 1
    assert Map.has_key?(meta, "has_more")

    conn = get(admin_conn, "/api/v1/admin/matchmaking/tickets", %{"user_id" => player.id})
    assert %{"data" => [%{"id" => id}]} = json_response(conn, 200)
    assert id == ticket.id
  end

  test "DELETE /tickets/:id force-cancels a queued ticket", %{
    admin_conn: admin_conn,
    player: player
  } do
    {:ok, ticket} = Matchmaking.join(player, %{"mode" => "duel"})

    conn = delete(admin_conn, "/api/v1/admin/matchmaking/tickets/#{ticket.id}")
    assert %{"data" => %{"status" => "cancelled"}} = json_response(conn, 200)

    conn = delete(admin_conn, "/api/v1/admin/matchmaking/tickets/#{ticket.id}")
    assert %{"error" => "not_found"} = json_response(conn, 404)
  end

  test "GET /stats returns full counters", %{admin_conn: admin_conn, player: player} do
    {:ok, ticket} = Matchmaking.join(player, %{"mode" => "duel"})
    {:ok, _} = Matchmaking.cancel_ticket(ticket.id)

    conn = get(admin_conn, "/api/v1/admin/matchmaking/stats")
    assert %{"data" => data} = json_response(conn, 200)
    assert data["queued"] == 0
    assert data["cancelled"] == 1
    assert Map.has_key?(data, "matched")
  end

  test "requires an admin", %{plain_conn: conn, player: player} do
    conn = bearer_conn(conn, player)
    conn = get(conn, "/api/v1/admin/matchmaking/tickets")
    assert response(conn, 403)
  end
end
