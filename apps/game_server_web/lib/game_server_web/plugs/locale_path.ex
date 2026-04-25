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
  @known_locales GameServerWeb.GettextSync.known_locales()

  def init(opts), do: opts

  def call(%Plug.Conn{path_info: ["api" | _]} = conn, _opts) do
    # API routes never use locale prefixes or sessions — skip entirely
    GameServerWeb.GettextSync.put_locale(@default_locale)
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
       when is_binary(first) do
    case GameServerWeb.GettextSync.normalize_locale(first) do
      locale when is_binary(locale) and locale in @known_locales ->
        clean_path =
          case rest do
            [] -> "/"
            _ -> "/" <> Enum.join(rest, "/")
          end

        query = conn.query_string
        redirect_path = if query != "", do: clean_path <> "?" <> query, else: clean_path

        {:redirect, conn, locale, redirect_path}

      _ ->
        {:ok, conn}
    end
  end

  defp maybe_extract_locale_prefix(conn), do: {:ok, conn}

  # Read locale from session (set by a prior redirect) or fall back to default.
  defp apply_session_locale(conn) do
    locale =
      conn
      |> get_session(@session_key)
      |> GameServerWeb.GettextSync.normalize_locale()
      |> Kernel.||(@default_locale)

    GameServerWeb.GettextSync.put_locale(locale)
    assign(conn, :locale, locale)
  end
end
