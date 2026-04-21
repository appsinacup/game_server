defmodule GameServerHost.Plugs.WellKnown do
  @moduledoc """
  Serves host-owned `.well-known` files with strict headers.

  Currently used to ensure `/.well-known/apple-app-site-association` is
  always served with Content-Type: application/json and without any
  `Content-Encoding` header (Apple requires the file to be uncompressed).
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(%Plug.Conn{request_path: "/.well-known/apple-app-site-association"} = conn, _opts) do
    path =
      Path.join(
        :code.priv_dir(:game_server_host),
        "static/.well-known/apple-app-site-association"
      )

    case File.read(path) do
      {:ok, body} when is_binary(body) ->
        conn
        |> put_resp_content_type("application/json")
        |> delete_resp_header("content-encoding")
        |> put_resp_header("content-length", Integer.to_string(byte_size(body)))
        |> send_resp(200, body)
        |> halt()

      _ ->
        conn
    end
  end

  def call(%Plug.Conn{request_path: "/.well-known/assetlinks.json"} = conn, _opts) do
    path = Path.join(:code.priv_dir(:game_server_host), "static/.well-known/assetlinks.json")

    case File.read(path) do
      {:ok, body} when is_binary(body) ->
        conn
        |> put_resp_content_type("application/json")
        |> put_resp_header("content-length", Integer.to_string(byte_size(body)))
        |> send_resp(200, body)
        |> halt()

      _ ->
        conn
    end
  end

  def call(conn, _opts), do: conn
end
