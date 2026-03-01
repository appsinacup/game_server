defmodule GameServerWeb.OnMount.Locale do
  @moduledoc false

  # Locale feature temporarily disabled — uncomment when re-enabling
  # @session_key_atom :preferred_locale
  # @session_key_string "preferred_locale"

  def on_mount(:default, _params, _session, socket) do
    # Locale feature temporarily disabled — always use English
    Gettext.put_locale(GameServerWeb.Gettext, "en")
    {:cont, socket}
  end

  # defp normalize_locale(locale) when is_binary(locale) do
  #   locale = String.downcase(locale)
  #
  #   if locale in Gettext.known_locales(GameServerWeb.Gettext) do
  #     locale
  #   else
  #     nil
  #   end
  # end

  # defp normalize_locale(_), do: nil
end
