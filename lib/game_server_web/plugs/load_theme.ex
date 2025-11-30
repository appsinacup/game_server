defmodule GameServerWeb.Plugs.LoadTheme do
  @moduledoc """
  Plug that assigns the currently configured Theme provider's theme map as
  `conn.assigns.theme` so templates and LiveViews can render config-driven
  values like title, logo, banner and a `css` path (external stylesheet).

  The active theme provider module is configured through:
    Application.get_env(:game_server, :theme_module) || GameServer.Theme.JSONConfig
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    require Logger
    theme_mod = Application.get_env(:game_server, :theme_module, GameServer.Theme.JSONConfig)

    provider_map = fetch_theme(theme_mod)

    theme_map =
      if provider_map == %{} do
        get_default_theme(theme_mod)
      else
        # merge the provider_map over the defaults to ensure missing keys are present
        default = get_default_theme(theme_mod) || %{}
        Map.merge(default, provider_map)
      end

    # Only expose the simple, safe keys that the application uses for UI
    theme = %{
      "title" => Map.get(theme_map, "title"),
      "tagline" => Map.get(theme_map, "tagline"),
      "logo" => Map.get(theme_map, "logo"),
      "banner" => Map.get(theme_map, "banner"),
      "favicon" => Map.get(theme_map, "favicon"),
      "css" => Map.get(theme_map, "css")
    }

    # In development & test environments log the resolved theme_map to make
    # runtime debugging easier when things appear blank in the UI.
    if Mix.env() in [:dev, :test] do
      Logger.debug(
        "LoadTheme: assigned theme=#{inspect(theme)} (THEME_CONFIG=#{inspect(System.get_env("THEME_CONFIG"))})"
      )
    end

    assign(conn, :theme, theme)
  end

  defp fetch_theme(mod) do
    try do
      mod.get_theme() || %{}
    rescue
      _ -> %{}
    end
  end

  defp get_default_theme(_mod) do
    # Defer to the JSON provider's packaged default helper so we have a single
    # implementation that understands where the default JSON lives.
    GameServer.Theme.JSONConfig.packaged_default()
  end
end
