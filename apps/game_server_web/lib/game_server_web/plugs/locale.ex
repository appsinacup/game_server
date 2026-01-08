defmodule GameServerWeb.Plugs.Locale do
  @moduledoc false

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  @session_key :preferred_locale
  @default_locale "en"

  @excluded_prefixes [
    "/assets",
    "/api",
    "/auth",
    "/dev",
    "/locale"
  ]

  @excluded_paths [
    "/admin/dashboard"
  ]

  def init(opts), do: opts

  def call(conn, _opts) do
    known_locales = Gettext.known_locales(GameServerWeb.Gettext)
    param_locale = conn.params["locale"]
    session_locale = get_session(conn, @session_key)

    locale =
      cond do
        is_binary(param_locale) and param_locale in known_locales ->
          param_locale

        is_binary(session_locale) and session_locale in known_locales ->
          session_locale

        true ->
          nil
      end

    conn =
      if locale do
        Gettext.put_locale(GameServerWeb.Gettext, locale)

        conn
        |> assign(:locale, locale)
        |> maybe_persist_locale(param_locale, locale)
      else
        conn
      end

    maybe_redirect_to_locale_prefixed_path(conn, locale, param_locale)
  end

  defp maybe_persist_locale(conn, param_locale, locale) do
    if is_binary(param_locale) and param_locale == locale do
      put_session(conn, @session_key, locale)
    else
      conn
    end
  end

  defp maybe_redirect_to_locale_prefixed_path(conn, locale, param_locale) do
    if should_redirect?(conn, locale, param_locale) do
      location = "/" <> locale <> conn.request_path <> query_suffix(conn.query_string)

      conn
      |> redirect(to: location)
      |> halt()
    else
      conn
    end
  end

  defp should_redirect?(_conn, nil, _param_locale), do: false
  defp should_redirect?(_conn, _locale, param_locale) when is_binary(param_locale), do: false
  defp should_redirect?(_conn, @default_locale, _param_locale), do: false

  defp should_redirect?(conn, locale, _param_locale) do
    path = conn.request_path

    not excluded_path?(path) and
      not String.starts_with?(path, "/" <> locale <> "/") and
      path != "/" <> locale
  end

  defp excluded_path?(path) do
    Enum.any?(@excluded_paths, &(&1 == path)) or
      Enum.any?(@excluded_prefixes, &String.starts_with?(path, &1))
  end

  defp query_suffix(""), do: ""
  defp query_suffix(nil), do: ""
  defp query_suffix(qs), do: "?" <> qs
end
