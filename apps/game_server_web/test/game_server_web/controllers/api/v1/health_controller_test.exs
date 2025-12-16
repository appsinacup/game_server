defmodule GameServerWeb.Api.V1.HealthControllerTest do
  use GameServerWeb.ConnCase, async: true

  test "GET /api/v1/health returns ok with timestamp", %{conn: conn} do
    conn = get(conn, "/api/v1/health")
    assert json_response(conn, 200)["status"] == "ok"
    assert is_binary(json_response(conn, 200)["timestamp"]) == true
  end
end
