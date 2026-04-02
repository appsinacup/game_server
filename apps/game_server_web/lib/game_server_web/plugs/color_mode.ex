defmodule GameServerWeb.Plugs.ColorMode do
  @moduledoc """
  Reads the `phx_theme` cookie (set by the client-side theme switcher) and
  assigns `:color_mode` so that the root layout can render the `data-theme`
  attribute server-side, preventing a Flash of Unstyled Content (FOUC) when
  the user has selected dark mode.

  Only accepts `"dark"` or `"light"` — any other value is ignored.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn = fetch_cookies(conn)

    case conn.cookies["phx_theme"] do
      theme when theme in ["dark", "light"] ->
        assign(conn, :color_mode, theme)

      _ ->
        conn
    end
  end
end
