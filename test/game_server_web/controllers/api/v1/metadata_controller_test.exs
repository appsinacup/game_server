defmodule GameServerWeb.Api.V1.MetadataControllerTest do
  use GameServerWeb.ConnCase, async: true

  alias GameServer.AccountsFixtures
  alias GameServer.Accounts.Scope

  setup do
    user = AccountsFixtures.user_fixture()
    %{user: user}
  end

  test "GET /api/v1/metadata returns metadata for authenticated user", %{conn: conn, user: user} do
    conn = conn |> assign(:current_scope, Scope.for_user(user)) |> get("/api/v1/metadata")
    assert json_response(conn, 200)["data"] == (user.metadata || %{})
  end

  test "GET /api/v1/metadata returns 401 for unauthenticated", %{conn: conn} do
    conn = get(conn, "/api/v1/metadata")
    assert json_response(conn, 401)["error"] == "Not authenticated"
  end
end
defmodule GameServerWeb.Api.V1.MetadataControllerTest do
  use GameServerWeb.ConnCase

  describe "GET /api/v1/me/metadata (removed)" do
    test "returns 404 Not Found (route removed)", %{conn: conn} do
      conn = get(conn, "/api/v1/me/metadata")
      assert response(conn, 404)
    end
  end
end
