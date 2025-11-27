defmodule GameServerWeb.Api.V1.MetadataControllerTest do
  use GameServerWeb.ConnCase, async: true

  # Note: The /api/v1/metadata route has been removed from the router.
  # The MetadataController exists but is not currently routed.
  # If this route is needed in the future, add it to router.ex:
  #   get "/metadata", MetadataController, :show

  describe "GET /api/v1/me/metadata (removed)" do
    test "returns 404 Not Found (route removed)", %{conn: conn} do
      conn = get(conn, "/api/v1/me/metadata")
      assert response(conn, 404)
    end
  end
end
