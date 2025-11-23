defmodule GameServerWeb.Api.V1.ProviderControllerTest do
  use GameServerWeb.ConnCase, async: true

  alias GameServer.Accounts
  import GameServer.AccountsFixtures

  describe "DELETE /api/v1/me/providers/:provider" do
    setup %{conn: conn} do
      user = user_fixture()

      {:ok, token, _} =
        GameServerWeb.Auth.Guardian.encode_and_sign(user, %{}, token_type: "access")

      {:ok, conn: put_req_header(conn, "authorization", "Bearer #{token}"), user: user}
    end

    test "unlinks provider when multiple providers present", %{conn: conn, user: user} do
      user =
        GameServer.Repo.update!(Ecto.Changeset.change(user, %{discord_id: "d1", google_id: "g1"}))

      resp = delete(conn, ~p"/api/v1/me/providers/discord")

      assert json_response(resp, 200)["message"] == "unlinked"
      user = Accounts.get_user!(user.id)
      assert user.discord_id == nil
      assert user.google_id == "g1"
    end

    test "cannot unlink last provider", %{conn: conn, user: user} do
      user = GameServer.Repo.update!(Ecto.Changeset.change(user, %{discord_id: "donly"}))

      resp = delete(conn, ~p"/api/v1/me/providers/discord")

      assert resp.status == 400
      assert json_response(resp, 400)["error"] =~ "last"
    end
  end
end
