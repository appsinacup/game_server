defmodule GameServerWeb.Plugs.LoadTheme do
  @moduledoc """
  Plug that assigns the resolved theme map into `conn.assigns.theme` so
  templates and LiveViews can render provider-driven copy alongside the
  host-owned branding assets.
  """

  @log_theme Mix.env() in [:dev, :test]

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    require Logger

    locale = Map.get(conn.assigns, :locale) || Gettext.get_locale(GameServerWeb.Gettext)
    theme = GameServerWeb.Layouts.resolve_theme(locale)

    # In development & test environments log the resolved theme_map to make
    # runtime debugging easier when things appear blank in the UI.
    if @log_theme do
      Logger.debug(
        "LoadTheme: assigned theme=#{inspect(theme)} (THEME_CONFIG=#{inspect(System.get_env("THEME_CONFIG"))})"
      )
    end

    assign(conn, :theme, theme)
  end
end
