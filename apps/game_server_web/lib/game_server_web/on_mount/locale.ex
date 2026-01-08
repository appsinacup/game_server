defmodule GameServerWeb.OnMount.Locale do
  @moduledoc false

  @session_key "preferred_locale"

  def on_mount(:default, _params, session, socket) do
    locale = normalize_locale(session[@session_key])

    if locale do
      Gettext.put_locale(GameServerWeb.Gettext, locale)
    end

    {:cont, socket}
  end

  defp normalize_locale(locale) when is_binary(locale) do
    locale = String.downcase(locale)

    if locale in Gettext.known_locales(GameServerWeb.Gettext) do
      locale
    else
      nil
    end
  end

  defp normalize_locale(_), do: nil
end
