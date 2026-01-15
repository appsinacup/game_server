defmodule GameServerWeb.Plugs.LoadTheme do
  @moduledoc """
  Plug that assigns the currently configured Theme provider's theme map as
  `conn.assigns.theme` so templates and LiveViews can render config-driven
  values like title, logo, banner and a `css` path (external stylesheet).

  The active theme provider module is configured through:
    Application.get_env(:game_server_web, :theme_module) || GameServer.Theme.JSONConfig
  """

  import Plug.Conn

  alias GameServer.Theme.JSONConfig

  def init(opts), do: opts

  def call(conn, _opts) do
    require Logger
    theme_mod = Application.get_env(:game_server_web, :theme_module, GameServer.Theme.JSONConfig)

    locale = Map.get(conn.assigns, :locale) || Gettext.get_locale(GameServerWeb.Gettext)

    provider_map = fetch_theme(theme_mod, locale)

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

  defp fetch_theme(mod, locale) do
    # Prefer locale-aware API when available, but fall back to the 0-arity
    # provider when the locale-specific call returns an empty map or nil.
    if is_binary(locale) and function_exported?(mod, :get_theme, 1) do
      res = safe_get_theme_1(mod, locale)

      if is_map(res) and map_size(res) > 0 do
        res
      else
        try_primary_or_fallback(mod, locale)
      end
    else
      safe_get_theme_0(mod)
    end
  rescue
    _ -> %{}
  end

  defp try_primary_or_fallback(mod, locale) do
    primary =
      locale
      |> String.trim()
      |> String.downcase()
      |> String.split(~r/[-_]/, parts: 2)
      |> List.first()

    if is_binary(primary) and primary != locale and function_exported?(mod, :get_theme, 1) do
      case safe_get_theme_1(mod, primary) do
        m when is_map(m) and map_size(m) > 0 -> m
        _ -> safe_get_theme_0(mod)
      end
    else
      safe_get_theme_0(mod)
    end
  end

  defp safe_get_theme_1(mod, arg) do
    mod.get_theme(arg) || %{}
  rescue
    _ -> %{}
  end

  defp safe_get_theme_0(mod) do
    if function_exported?(mod, :get_theme, 0), do: mod.get_theme() || %{}, else: %{}
  rescue
    _ -> %{}
  end

  defp get_default_theme(_mod) do
    # Defer to the JSON provider's packaged default helper so we have a single
    # implementation that understands where the default JSON lives.
    JSONConfig.packaged_default()
  end
end
