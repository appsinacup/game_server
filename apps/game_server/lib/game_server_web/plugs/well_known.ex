defmodule GameServerWeb.Plugs.WellKnown do
  @moduledoc """
  Plug to serve special `.well-known` files with strict headers.

  Currently used to ensure `/.well-known/apple-app-site-association` is
  always served with Content-Type: application/json and **without** any
  `Content-Encoding` header (Apple requires the file to be uncompressed).
  """

  import Plug.Conn

  @aasa_rel_path "static/.well-known/apple-app-site-association"

  def init(opts), do: opts

  def call(%Plug.Conn{request_path: "/.well-known/apple-app-site-association"} = conn, _opts) do
    path = Path.join(:code.priv_dir(:game_server), @aasa_rel_path)

    case File.read(path) do
      {:ok, body} when is_binary(body) ->
        conn
        |> put_resp_content_type("application/json")
        |> delete_resp_header("content-encoding")
        |> put_resp_header("content-length", Integer.to_string(byte_size(body)))
        |> send_resp(200, body)
        |> halt()

      _ ->
        # Let Plug.Static (or other plugs) handle the request if file missing
        conn
    end
  end

  def call(conn, _opts), do: conn
end
