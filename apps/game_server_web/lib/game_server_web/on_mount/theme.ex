defmodule GameServerWeb.OnMount.Theme do
  @moduledoc """
  on_mount helper for LiveView that ensures `:theme` is assigned on the
  socket. LiveViews can rely on `@theme` being present whether rendering
  via an HTTP request or a websocket socket lifecycle.

  The theme map is cached in persistent_term after the first computation
  so subsequent LiveView mounts are essentially free.
  """

  @theme_pt_key {__MODULE__, :cached_theme}

  def on_mount(:mount_theme, _params, _session, socket) do
    {:cont, Phoenix.Component.assign_new(socket, :theme, fn -> cached_theme() end)}
  end

  defp cached_theme do
    case :persistent_term.get(@theme_pt_key, nil) do
      nil ->
        theme = compute_theme()
        :persistent_term.put(@theme_pt_key, theme)
        theme

      cached ->
        cached
    end
  end

  defp compute_theme do
    locale = Gettext.get_locale(GameServerWeb.Gettext)
    GameServerWeb.Layouts.resolve_theme(locale)
  end
end
