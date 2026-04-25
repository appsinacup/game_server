defmodule GameServerWeb.OnMount.Locale do
  @moduledoc """
  LiveView on_mount hook that sets the Gettext locale from the session.

  When the `LocalePath` plug stores a `:preferred_locale` in the session,
  this hook reads it so that LiveView renders use the correct locale.
  """

  @session_key "preferred_locale"

  def on_mount(:default, _params, session, socket) do
    locale = GameServerWeb.GettextSync.normalize_locale(session[@session_key]) || "en"
    GameServerWeb.GettextSync.put_locale(locale)
    {:cont, Phoenix.Component.assign(socket, :locale, locale)}
  end
end
