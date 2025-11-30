defmodule GameServerWeb.Plugs.LoadThemeTest do
  use GameServerWeb.ConnCase, async: true

  test "assigns theme into conn.assigns.theme", %{conn: conn} do
    # Ensure default provider reads the default config — we don't set THEME_CONFIG
    conn = GameServerWeb.Plugs.LoadTheme.call(conn, [])

    assert conn.assigns[:theme]
    assert is_map(conn.assigns[:theme])

    # Only the allowed keys should be exposed to templates
    keys = Map.keys(conn.assigns[:theme]) |> Enum.sort()
    # favicon is included in the provider defaults
    assert keys == ["banner", "css", "favicon", "logo", "tagline", "title"]

    # The plug should populate the shipped default values when THEME_CONFIG is unset
    default_path = Path.join(:code.priv_dir(:game_server), "static/theme/default_config.json")
    {:ok, file} = File.read(default_path)
    expected = Jason.decode!(file)

    assert conn.assigns[:theme]["title"] == expected["title"]
    assert conn.assigns[:theme]["tagline"] == expected["tagline"]
    assert conn.assigns[:theme]["logo"] == expected["logo"]
  end

  test "falls back to packaged defaults when provider returns empty map", %{conn: conn} do
    # Simulate a provider module that returns an empty map
    orig_mod = Application.get_env(:game_server, :theme_module)
    Application.put_env(:game_server, :theme_module, __MODULE__.EmptyThemeMock)

    defmodule __MODULE__.EmptyThemeMock do
      def get_theme, do: %{}
    end

    conn = GameServerWeb.Plugs.LoadTheme.call(conn, [])

    default_path = Path.join(:code.priv_dir(:game_server), "static/theme/default_config.json")
    {:ok, file} = File.read(default_path)
    expected = Jason.decode!(file)

    assert conn.assigns[:theme]["title"] == expected["title"]
    assert conn.assigns[:theme]["tagline"] == expected["tagline"]

    # restore app env
    if orig_mod,
      do: Application.put_env(:game_server, :theme_module, orig_mod),
      else: Application.delete_env(:game_server, :theme_module)
  end
end
