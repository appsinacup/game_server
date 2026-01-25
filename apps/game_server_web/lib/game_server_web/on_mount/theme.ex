defmodule GameServerWeb.OnMount.Theme do
  @moduledoc """
  on_mount helper for LiveView that ensures `:theme` is assigned on the
  socket. LiveViews can rely on `@theme` being present whether rendering
  via an HTTP request or a websocket socket lifecycle.
  """

  def on_mount(:mount_theme, _params, _session, socket) do
    theme_mod = Application.get_env(:game_server_web, :theme_module, GameServer.Theme.JSONConfig)
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

    # Only expose the limited safe keys that templates expect
    theme = %{
      "title" => Map.get(theme_map, "title"),
      "tagline" => Map.get(theme_map, "tagline"),
      "logo" => Map.get(theme_map, "logo"),
      "banner" => Map.get(theme_map, "banner"),
      "favicon" => Map.get(theme_map, "favicon"),
      "css" => Map.get(theme_map, "css")
    }

    {:cont, Phoenix.Component.assign_new(socket, :theme, fn -> theme end)}
  end
end
