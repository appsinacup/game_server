defmodule GameServerWeb.WellKnownPlugTest do
  use GameServerWeb.ConnCase, async: true

  @aasa_path "priv/static/.well-known/apple-app-site-association"

  setup do
    # Ensure directory exists and write a known file for the endpoint to serve
    :ok = File.mkdir_p!(Path.dirname(@aasa_path))
    File.write!(@aasa_path, "{\"applinks\":{\"apps\":[],\"details\":[]}}")

    on_exit(fn ->
      # cleanup
      File.rm(@aasa_path)
    end)

    :ok
  end

  test "serves apple-app-site-association with application/json and no content-encoding", %{
    conn: conn
  } do
    conn = get(conn, "/.well-known/apple-app-site-association")

    assert conn.status == 200
    assert [ct | _] = get_resp_header(conn, "content-type")
    assert String.starts_with?(ct, "application/json")

    # must NOT include content-encoding header
    assert get_resp_header(conn, "content-encoding") == []
  end
end
