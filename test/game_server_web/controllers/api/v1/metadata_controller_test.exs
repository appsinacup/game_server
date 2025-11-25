defmodule GameServerWeb.Api.V1.MetadataControllerTest do
  use GameServerWeb.ConnCase

  describe "GET /api/v1/me/metadata (removed)" do
    test "returns 404 Not Found (route removed)", %{conn: conn} do
      conn = get(conn, "/api/v1/me/metadata")
      assert response(conn, 404)
    end
  end
end
