defmodule GameServerWeb.OnMount.Theme do
  @moduledoc """
  on_mount helper for LiveView that ensures `:theme` is assigned on the
  socket. LiveViews can rely on `@theme` being present whether rendering
  via an HTTP request or a websocket socket lifecycle.

  The theme provider owns caching and locale fallback. Resolve it on each
  LiveView mount so the current process locale is honored.
  """

  def on_mount(:mount_theme, _params, _session, socket) do
    {:cont, Phoenix.Component.assign_new(socket, :theme, fn -> compute_theme() end)}
  end

  defp compute_theme do
    locale = Gettext.get_locale(GameServerWeb.Gettext)
    GameServerWeb.Layouts.resolve_theme(locale)
  end
end
