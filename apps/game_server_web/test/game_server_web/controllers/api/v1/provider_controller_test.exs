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

      assert response(resp, 200)
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

  describe "POST /api/v1/me/device" do
    setup %{conn: conn} do
      user = user_fixture()

      {:ok, token, _} =
        Guardian.encode_and_sign(user, %{}, token_type: "access")

      {:ok, conn: put_req_header(conn, "authorization", "Bearer #{token}"), user: user}
    end

    test "links device_id to user", %{conn: conn, user: user} do
      device_id = "test-device-#{System.unique_integer([:positive])}"

      resp = post(conn, ~p"/api/v1/me/device", %{device_id: device_id})

      assert response(resp, 200)
      user = Accounts.get_user!(user.id)
      assert user.device_id == device_id
    end

    test "returns error when device_id already used", %{conn: conn} do
      device_id = "test-device-#{System.unique_integer([:positive])}"
      other_user = user_fixture()
      Accounts.link_device_id(other_user, device_id)

      resp = post(conn, ~p"/api/v1/me/device", %{device_id: device_id})

      assert resp.status == 400
      assert json_response(resp, 400)["error"] =~ "Failed to link device_id"
    end

    test "returns error when device_id missing", %{conn: conn} do
      resp = post(conn, ~p"/api/v1/me/device", %{})

      assert resp.status == 400
      assert json_response(resp, 400)["error"] =~ "device_id is required"
    end
  end

  describe "DELETE /api/v1/me/device" do
    setup %{conn: conn} do
      user = user_fixture()

      {:ok, token, _} =
        Guardian.encode_and_sign(user, %{}, token_type: "access")

      {:ok, conn: put_req_header(conn, "authorization", "Bearer #{token}"), user: user}
    end

    test "unlinks device_id when user has other auth methods", %{conn: conn, user: user} do
      device_id = "test-device-#{System.unique_integer([:positive])}"
      user = Repo.update!(Ecto.Changeset.change(user, %{device_id: device_id, discord_id: "d1"}))

      resp = delete(conn, ~p"/api/v1/me/device")

      assert response(resp, 200)
      user = Accounts.get_user!(user.id)
      assert user.device_id == nil
      assert user.discord_id == "d1"
    end

    test "cannot unlink device_id when it's the last auth method", %{conn: conn, user: user} do
      device_id = "test-device-#{System.unique_integer([:positive])}"
      Repo.update!(Ecto.Changeset.change(user, %{device_id: device_id}))

      resp = delete(conn, ~p"/api/v1/me/device")

      assert resp.status == 400
      assert json_response(resp, 400)["error"] =~ "last authentication method"
    end

    test "returns success when device_id already nil", %{conn: conn} do
      resp = delete(conn, ~p"/api/v1/me/device")

      assert response(resp, 200)
    end
  end
end
