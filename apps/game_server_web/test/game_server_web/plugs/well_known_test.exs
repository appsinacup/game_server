defmodule GameServerWeb.WellKnownPlugTest do
  use GameServerWeb.ConnCase, async: true

  setup do
    # The host endpoint owns .well-known files directly under game_server_host.
    host_app = :game_server_host
    well_known_dir = Path.join(:code.priv_dir(host_app), "static/.well-known")
    aasa_path = Path.join(well_known_dir, "apple-app-site-association")
    assetlinks_path = Path.join(well_known_dir, "assetlinks.json")

    :ok = File.mkdir_p!(well_known_dir)
    File.write!(aasa_path, "{\"applinks\":{\"apps\":[],\"details\":[]}}")
    File.write!(assetlinks_path, "[{\"f\":1}]")

    on_exit(fn ->
      File.rm(aasa_path)
      File.rm(assetlinks_path)
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

  test "serves assetlinks.json with application/json", %{conn: conn} do
    conn = get(conn, "/.well-known/assetlinks.json")

    assert conn.status == 200
    assert [ct | _] = get_resp_header(conn, "content-type")
    assert String.starts_with?(ct, "application/json")
  end
end
