defmodule GameServerWeb.Api.V1.MetadataControllerTest do
  use GameServerWeb.ConnCase

  alias GameServerWeb.Auth.Guardian

  describe "GET /api/v1/me/metadata" do
    test "returns 401 when not authenticated", %{conn: conn} do
      conn = get(conn, "/api/v1/me/metadata")
      assert json_response(conn, 401)
    end

    test "returns metadata when authenticated", %{conn: conn} do
      user = GameServer.AccountsFixtures.user_fixture()
      # set metadata via admin_changeset (metadata not part of default registration)
      {:ok, user} =
        user
        |> GameServer.Accounts.User.admin_changeset(%{
          "metadata" => %{"display_name" => "Tester"}
        })
        |> GameServer.Repo.update()

      {:ok, token, _claims} = Guardian.encode_and_sign(user)

      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> token)
        |> get("/api/v1/me/metadata")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["display_name"] == "Tester"
    end
  end
end
