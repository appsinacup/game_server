defmodule GameServerWeb.OnMount.Locale do
  @moduledoc """
  LiveView on_mount hook that sets the Gettext locale from the session.

  When the `LocalePath` plug stores a `:preferred_locale` in the session,
  this hook reads it so that LiveView renders use the correct locale.
  """

  @session_key "preferred_locale"

  def on_mount(:default, _params, session, socket) do
    locale = normalize_locale(session[@session_key]) || "en"
    Gettext.put_locale(GameServerWeb.Gettext, locale)
    {:cont, Phoenix.Component.assign(socket, :locale, locale)}
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
