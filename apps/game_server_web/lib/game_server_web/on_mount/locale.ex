defmodule GameServerWeb.OnMount.Locale do
  @moduledoc false

  # Phoenix cookie sessions serialize keys as strings, so we need to check both
  @session_key_atom :preferred_locale
  @session_key_string "preferred_locale"

  def on_mount(:default, _params, session, socket) do
    locale = normalize_locale(session[@session_key_string] || session[@session_key_atom])

    require Logger

    Logger.debug(
      "[OnMount.Locale] session_keys=#{inspect(Map.keys(session))} string_key=#{inspect(session[@session_key_string])} atom_key=#{inspect(session[@session_key_atom])} locale=#{inspect(locale)}"
    )

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
