defmodule GameServerWeb.LocaleController do
  use GameServerWeb, :controller

  @session_key :preferred_locale

  def set(conn, %{"locale" => locale}) do
    locale = normalize_locale(locale)

    conn
    |> put_session(@session_key, locale)
    |> redirect(to: return_path(conn) || ~p"/")
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
