defmodule GameServerWeb.Api.V1.ProviderControllerTest do
  use GameServerWeb.ConnCase, async: true

  alias GameServer.Accounts
  alias GameServerWeb.Auth.Guardian
  import GameServer.AccountsFixtures
  alias GameServer.Repo

  describe "DELETE /api/v1/me/providers/:provider" do
    setup %{conn: conn} do
      user = user_fixture()

      {:ok, token, _} =
        Guardian.encode_and_sign(user, %{}, token_type: "access")

      {:ok, conn: put_req_header(conn, "authorization", "Bearer #{token}"), user: user}
    end

    test "unlinks provider when multiple providers present", %{conn: conn, user: user} do
      user =
        Repo.update!(Ecto.Changeset.change(user, %{discord_id: "d1", google_id: "g1"}))

      resp = delete(conn, ~p"/api/v1/me/providers/discord")

      assert response(resp, 204)
      user = Accounts.get_user!(user.id)
      assert user.discord_id == nil
      assert user.google_id == "g1"
    end

    test "cannot unlink last provider", %{conn: conn, user: user} do
      Repo.update!(Ecto.Changeset.change(user, %{discord_id: "donly"}))

      resp = delete(conn, ~p"/api/v1/me/providers/discord")

      assert resp.status == 400
      assert json_response(resp, 400)["error"] =~ "last"
    end

    test "invalid provider returns 400", %{conn: conn} do
      resp = delete(conn, ~p"/api/v1/me/providers/invalid-provider")

      assert resp.status == 400
      assert json_response(resp, 400)["error"] =~ "Unknown provider"
    end
  end
end
