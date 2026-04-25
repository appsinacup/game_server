defmodule GameServerWeb.Plugs.WellKnown do
  @moduledoc """
  Serves `.well-known` files with strict headers from the configured static app.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(%Plug.Conn{request_path: "/.well-known/apple-app-site-association"} = conn, _opts) do
    serve(conn, "apple-app-site-association", delete_resp_encoding: true)
  end

  def call(%Plug.Conn{request_path: "/.well-known/assetlinks.json"} = conn, _opts) do
    serve(conn, "assetlinks.json")
  end

  def call(conn, _opts), do: conn

  defp serve(conn, filename, opts \\ []) do
    static_app =
      Application.get_env(:game_server_web, :well_known_static_app) ||
        Application.get_env(:game_server_web, :host_static_app, :game_server_web)

    path = Path.join(:code.priv_dir(static_app), "static/.well-known/#{filename}")

    case File.read(path) do
      {:ok, body} when is_binary(body) ->
        conn =
          conn
          |> put_resp_content_type("application/json")
          |> put_resp_header("content-length", Integer.to_string(byte_size(body)))

        conn =
          if opts[:delete_resp_encoding],
            do: delete_resp_header(conn, "content-encoding"),
            else: conn

        conn
        |> send_resp(200, body)
        |> halt()

      _ ->
        conn
    end
  end
end
