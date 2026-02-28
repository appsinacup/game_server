defmodule GameServerWeb.Plugs.ContentStatic do
  @moduledoc """
  Serves blog & changelog images directly from the endpoint plug pipeline,
  bypassing the code-reloader and full browser pipeline.

  This prevents concurrent image requests from being serialized by
  `Phoenix.CodeReloader` in dev mode, which would cause intermittent timeouts.

  Matched paths:  `GET /content/:type/*rest`
  """

  @behaviour Plug

  alias GameServer.Content

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{method: "GET", path_info: ["content", type | rest]} = conn, _opts)
      when type in ["blog", "changelog"] do
    relative = Path.join(rest)

    case Content.content_asset_path(type, relative) do
      nil ->
        conn

      abs_path ->
        content_type = MIME.from_path(abs_path)

        conn
        |> Plug.Conn.put_resp_content_type(content_type, nil)
        |> Plug.Conn.send_file(200, abs_path)
        |> Plug.Conn.halt()
    end
  end

  def call(conn, _opts), do: conn
end
