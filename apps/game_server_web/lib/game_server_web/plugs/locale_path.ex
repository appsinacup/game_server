defmodule GameServerWeb.Plugs.LocalePath do
  @moduledoc """
  Extracts an optional locale prefix from the URL path (e.g. `/es/settings`)
  and sets the Gettext locale accordingly.

  When a locale prefix is found the plug stores the chosen locale in the session
  under `:preferred_locale` and **redirects** to the unprefixed path.  This
  ensures the router always sees clean paths and LiveView WebSocket reconnects
  never hit an unmatched `/es/...` URL.

  Known locales are derived from `Gettext.known_locales/1` at compile time.
  """

  import Plug.Conn

  @session_key :preferred_locale
  @default_locale "en"
  @known_locales Gettext.known_locales(GameServerWeb.Gettext)

  def init(opts), do: opts

  def call(%Plug.Conn{path_info: ["api" | _]} = conn, _opts) do
    # API routes never use locale prefixes or sessions — skip entirely
    Gettext.put_locale(GameServerWeb.Gettext, @default_locale)
    Plug.Conn.assign(conn, :locale, @default_locale)
  end

  def call(conn, _opts) do
    # Skip locale processing for WebSocket upgrades
    if websocket_request?(conn) do
      conn
    else
      conn = fetch_session(conn)

      case maybe_extract_locale_prefix(conn) do
        {:redirect, conn, locale, redirect_path} ->
          # Store locale in session and redirect to unprefixed URL.
          # This avoids LiveView WebSocket URL mismatches.
          conn
          |> put_session(@session_key, locale)
          |> Phoenix.Controller.redirect(to: redirect_path)
          |> halt()

        {:ok, conn} ->
          apply_session_locale(conn)
      end
    end
  end

  defp websocket_request?(conn) do
    case Plug.Conn.get_req_header(conn, "upgrade") do
      [upgrade] -> String.downcase(upgrade) == "websocket"
      _ -> false
    end
  end

  defp maybe_extract_locale_prefix(%Plug.Conn{path_info: [first | rest]} = conn)
       when first in @known_locales do
    clean_path =
      case rest do
        [] -> "/"
        _ -> "/" <> Enum.join(rest, "/")
      end

    query = conn.query_string
    redirect_path = if query != "", do: clean_path <> "?" <> query, else: clean_path

    {:redirect, conn, first, redirect_path}
  end

  defp maybe_extract_locale_prefix(conn), do: {:ok, conn}

  # Read locale from session (set by a prior redirect) or fall back to default.
  defp apply_session_locale(conn) do
    locale = get_session(conn, @session_key) || @default_locale

    locale =
      if locale in @known_locales, do: locale, else: @default_locale

    Gettext.put_locale(GameServerWeb.Gettext, locale)
    assign(conn, :locale, locale)
  end
end
