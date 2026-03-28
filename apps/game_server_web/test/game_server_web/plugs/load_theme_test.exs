defmodule GameServerWeb.Plugs.LoadThemeTest do
  use GameServerWeb.ConnCase, async: false

  alias GameServer.Content
  alias GameServer.Theme.JSONConfig
  alias GameServerWeb.Plugs.LoadTheme

  setup do
    orig = System.get_env("THEME_CONFIG")
    JSONConfig.reload()
    Content.reload()

    on_exit(fn ->
      if orig, do: System.put_env("THEME_CONFIG", orig), else: System.delete_env("THEME_CONFIG")
      JSONConfig.reload()
      Content.reload()
    end)

    :ok
  end

  test "assigns theme map with expected keys into conn", %{conn: conn} do
    # Explicitly unset to verify the shape of the theme map
    System.delete_env("THEME_CONFIG")
    JSONConfig.reload()

    conn = LoadTheme.call(conn, [])

    assert conn.assigns[:theme]
    assert is_map(conn.assigns[:theme])

    # Only the allowed keys should be exposed to templates
    keys = Map.keys(conn.assigns[:theme]) |> Enum.sort()
    assert keys == ["banner", "css", "favicon", "logo", "tagline", "title"]
  end

  test "populates theme values from THEME_CONFIG", %{conn: conn} do
    base =
      Path.join(System.tmp_dir!(), "theme_plug_vals_#{System.unique_integer([:positive])}.json")

    en_path = String.trim_trailing(base, ".json") <> ".en.json"

    File.write!(
      en_path,
      Jason.encode!(%{"title" => "Test Title", "tagline" => "Test Tag", "logo" => "/logo.png"})
    )

    System.put_env("THEME_CONFIG", base)
    JSONConfig.reload()

    on_exit(fn -> File.rm(en_path) end)

    conn = LoadTheme.call(conn, [])

    assert conn.assigns[:theme]["title"] == "Test Title"
    assert conn.assigns[:theme]["tagline"] == "Test Tag"
    assert conn.assigns[:theme]["logo"] == "/logo.png"
  end

  test "returns nil values when provider returns empty map", %{conn: conn} do
    orig_mod = Application.get_env(:game_server_web, :theme_module)
    Application.put_env(:game_server_web, :theme_module, __MODULE__.EmptyThemeMock)

    defmodule __MODULE__.EmptyThemeMock do
      def get_theme, do: %{}
    end

    conn = LoadTheme.call(conn, [])

    # No merging with defaults — empty provider means nil values
    assert conn.assigns[:theme]["title"] == nil
    assert conn.assigns[:theme]["tagline"] == nil

    # restore app env
    if orig_mod,
      do: Application.put_env(:game_server_web, :theme_module, orig_mod),
      else: Application.delete_env(:game_server_web, :theme_module)
  end

  test "prefers locale-specific THEME_CONFIG when locale is assigned", %{conn: conn} do
    base =
      Path.join(System.tmp_dir!(), "theme_test_plug_#{System.unique_integer([:positive])}.json")

    en_path = String.trim_trailing(base, ".json") <> ".en.json"
    es_path = String.trim_trailing(base, ".json") <> ".es.json"

    File.write!(en_path, Jason.encode!(%{"title" => "English Title", "tagline" => "EN"}))
    File.write!(es_path, Jason.encode!(%{"title" => "Titulo ES", "tagline" => "ES"}))

    System.put_env("THEME_CONFIG", base)
    JSONConfig.reload()

    on_exit(fn ->
      File.rm(en_path)
      File.rm(es_path)
    end)

    conn = conn |> Plug.Conn.assign(:locale, "es") |> LoadTheme.call([])

    assert conn.assigns[:theme]["title"] == "Titulo ES"
    assert conn.assigns[:theme]["tagline"] == "ES"
  end
end
