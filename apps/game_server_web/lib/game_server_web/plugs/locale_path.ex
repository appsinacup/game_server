defmodule GameServerWeb.Plugs.LocalePath do
  @moduledoc false

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  @session_key :preferred_locale
  @default_locale "en"

  # Keep this explicit so path parsing is predictable.
  # If you add locales, add them here too.
  @known_locales ["en", "es"]

  @excluded_prefixes [
    "assets",
    "api",
    "auth",
    "dev",
    "locale"
  ]

  @excluded_paths [
    ["admin", "dashboard"]
  ]

  def init(opts), do: opts

  def call(conn, _opts) do
    {conn, prefix_locale} = maybe_extract_locale_prefix(conn)

    conn =
      conn
      |> maybe_apply_session_locale(prefix_locale)
      |> maybe_redirect_to_prefixed_path(prefix_locale)

    conn
  end

  defp maybe_extract_locale_prefix(%Plug.Conn{path_info: [first | rest]} = conn)
       when first in @known_locales do
    conn =
      conn
      |> put_session(@session_key, first)
      |> rewrite_path(rest)

    {conn, first}
  end

  defp maybe_extract_locale_prefix(conn), do: {conn, nil}

  defp maybe_apply_session_locale(conn, prefix_locale) when is_binary(prefix_locale) do
    Gettext.put_locale(GameServerWeb.Gettext, prefix_locale)
    assign(conn, :locale, prefix_locale)
  end

  defp maybe_apply_session_locale(conn, _prefix_locale) do
    locale = get_session(conn, @session_key)

    if locale in @known_locales do
      Gettext.put_locale(GameServerWeb.Gettext, locale)
      assign(conn, :locale, locale)
    else
      conn
    end
  end

  defp maybe_redirect_to_prefixed_path(conn, prefix_locale) when is_binary(prefix_locale), do: conn

  defp maybe_redirect_to_prefixed_path(conn, nil) do
    locale = get_session(conn, @session_key)

    if locale in @known_locales and locale != @default_locale and not excluded_path?(conn.path_info) do
      location = "/" <> locale <> conn.request_path <> query_suffix(conn.query_string)

      conn
      |> redirect(to: location)
      |> halt()
    else
      conn
    end
  end

  defp excluded_path?([]), do: false

  defp excluded_path?([first | _rest]) when first in @excluded_prefixes, do: true

  defp excluded_path?(path_info) do
    Enum.any?(@excluded_paths, &(&1 == path_info))
  end

  defp rewrite_path(conn, rest_path_info) do
    request_path =
      case rest_path_info do
        [] -> "/"
        _ -> "/" <> Enum.join(rest_path_info, "/")
      end

    %{conn | path_info: rest_path_info, request_path: request_path}
  end

  defp query_suffix(""), do: ""
  defp query_suffix(nil), do: ""
  defp query_suffix(qs), do: "?" <> qs
end
