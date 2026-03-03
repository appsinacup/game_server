defmodule GameServerWeb.Plugs.GameHeaders do
  @moduledoc """
  Adds Cross-Origin headers required by Godot 4 web exports.

  Godot 4 uses `SharedArrayBuffer` for threading, which requires the page
  to be served with:

    - `Cross-Origin-Opener-Policy: same-origin`
    - `Cross-Origin-Embedder-Policy: require-corp`

  This plug sets those headers for requests under `/game/` and `/play`.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(%{request_path: "/game" <> _} = conn, _opts), do: add_isolation_headers(conn)
  def call(%{request_path: "/play" <> _} = conn, _opts), do: add_isolation_headers(conn)
  def call(conn, _opts), do: conn

  defp add_isolation_headers(conn) do
    conn
    |> put_resp_header("cross-origin-opener-policy", "same-origin")
    |> put_resp_header("cross-origin-embedder-policy", "require-corp")
  end
end
