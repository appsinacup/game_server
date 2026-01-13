defmodule GameServerWeb.Plugs.LocalePath do
  @moduledoc false

  import Plug.Conn

  @session_key :preferred_locale
  @default_locale "en"

  # Keep this explicit so path parsing is predictable.
  # If you add locales, add them here too.
  @known_locales ["en", "es"]

  def init(opts), do: opts

  def call(conn, _opts) do
    # Skip locale processing for WebSocket upgrades
    if websocket_request?(conn) do
      conn
    else
      conn = fetch_session(conn)
      {conn, prefix_locale} = maybe_extract_locale_prefix(conn)
      maybe_apply_session_locale(conn, prefix_locale)
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
    # Extract locale from URL, rewrite path, store in session
    script_name = conn.script_name |> :lists.reverse() |> then(&[first | &1]) |> :lists.reverse()

    conn = %{conn | script_name: script_name, path_info: rest}
    {conn, first}
  end

  defp maybe_extract_locale_prefix(conn), do: {conn, nil}

  defp maybe_apply_session_locale(conn, prefix_locale) when is_binary(prefix_locale) do
    # URL has locale prefix - treat it as source of truth and remember it.
    Gettext.put_locale(GameServerWeb.Gettext, prefix_locale)

    conn
    |> assign(:locale, prefix_locale)
    |> put_session(@session_key, prefix_locale)
  end

  defp maybe_apply_session_locale(conn, nil) do
    # No locale prefix in URL - do not redirect. Treat unprefixed URLs as default locale.
    Gettext.put_locale(GameServerWeb.Gettext, @default_locale)
    assign(conn, :locale, @default_locale)
  end
end
