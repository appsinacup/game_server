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
    theme_mod = Application.get_env(:game_server_web, :theme_module, GameServer.Theme.JSONConfig)
    _ = Code.ensure_loaded?(theme_mod)
    locale = Gettext.get_locale(GameServerWeb.Gettext)

    theme_map =
      try do
        if is_binary(locale) and function_exported?(theme_mod, :get_theme, 1) do
          theme_mod.get_theme(locale) || %{}
        else
          theme_mod.get_theme() || %{}
        end
      rescue
        _ -> %{}
      end

    %{
      "title" => Map.get(theme_map, "title"),
      "tagline" => Map.get(theme_map, "tagline"),
      "logo" => Map.get(theme_map, "logo"),
      "banner" => Map.get(theme_map, "banner"),
      "favicon" => Map.get(theme_map, "favicon"),
      "css" => Map.get(theme_map, "css")
    }
  end
end
