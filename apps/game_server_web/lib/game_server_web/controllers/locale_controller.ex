defmodule GameServerWeb.LocaleController do
  use GameServerWeb, :controller

  @session_key :preferred_locale
  @default_locale "en"

  def set(conn, %{"locale" => locale}) do
    locale = normalize_locale(locale)

    return_to = return_path(conn) || ~p"/"
    {path, query} = split_path_and_query(return_to)
    path = strip_locale_prefix(path)
    destination = build_destination(locale, path, query)

    conn
    |> put_session(@session_key, locale)
    |> redirect(to: destination)
  end

  defp normalize_locale(locale) when is_binary(locale) do
    locale = String.downcase(locale)

    if locale in Gettext.known_locales(GameServerWeb.Gettext) do
      locale
    else
      "en"
    end
  end

  defp normalize_locale(_), do: "en"

  defp split_path_and_query(path_with_query) when is_binary(path_with_query) do
    uri = URI.parse(path_with_query)
    path = if(is_binary(uri.path) and String.starts_with?(uri.path, "/"), do: uri.path, else: "/")
    {path, uri.query}
  end

  defp split_path_and_query(_), do: {"/", nil}

  defp strip_locale_prefix(path) when is_binary(path) do
    known_locales = Gettext.known_locales(GameServerWeb.Gettext)

    segments = String.split(path, "/", trim: true)

    case segments do
      [first | rest] ->
        if Enum.member?(known_locales, first) do
          case rest do
            [] -> "/"
            _ -> "/" <> Enum.join(rest, "/")
          end
        else
          path
        end

      _ ->
        path
    end
  end

  defp strip_locale_prefix(_), do: "/"

  defp build_destination(locale, path, query) when is_binary(locale) and is_binary(path) do
    base_path =
      if locale == @default_locale do
        path
      else
        "/" <> locale <> path
      end

    base_path =
      case base_path do
        "" -> "/"
        other -> other
      end

    if is_binary(query) and query != "" do
      base_path <> "?" <> query
    else
      base_path
    end
  end

  defp return_path(conn) do
    return_to = conn.params["return_to"]

    if is_binary(return_to) and String.starts_with?(return_to, "/") do
      return_to
    else
      conn
      |> get_req_header("referer")
      |> List.first()
      |> referer_to_path(conn.host)
    end
  end

  defp referer_to_path(nil, _host), do: nil

  defp referer_to_path(referer, host) do
    uri = URI.parse(referer)

    if uri.host == host and is_binary(uri.path) and String.starts_with?(uri.path, "/") do
      (uri.path || "/") <> if(uri.query, do: "?" <> uri.query, else: "")
    else
      nil
    end
  end
end
