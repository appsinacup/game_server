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

  test "assigns fallback theme keys into conn when no local theme is configured", %{conn: conn} do
    System.delete_env("THEME_CONFIG")
    JSONConfig.reload()

    conn = LoadTheme.call(conn, [])

    assert conn.assigns[:theme]
    assert is_map(conn.assigns[:theme])
    assert conn.assigns[:theme]["title"] == "MISSING_THEME"
    assert conn.assigns[:theme]["tagline"] == "Add host theme config or set THEME_CONFIG"
    assert conn.assigns[:theme]["logo"] == "/images/logo.png"
    assert conn.assigns[:theme]["footer_links"] in [nil, []]
    assert conn.assigns[:theme]["navigation"] in [nil, %{}]
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
    assert conn.assigns[:theme]["logo"] == "/images/logo.png"
    assert conn.assigns[:theme]["banner"] == "/images/banner.png"
    assert conn.assigns[:theme]["favicon"] == "/favicon.ico"
    assert is_nil(conn.assigns[:theme]["css"])
  end

  test "uses generic missing-theme fallback when provider returns empty map", %{conn: conn} do
    orig_mod = Application.get_env(:game_server_web, :theme_module)
    Application.put_env(:game_server_web, :theme_module, __MODULE__.EmptyThemeMock)

    on_exit(fn ->
      if orig_mod,
        do: Application.put_env(:game_server_web, :theme_module, orig_mod),
        else: Application.delete_env(:game_server_web, :theme_module)
    end)

    defmodule __MODULE__.EmptyThemeMock do
      def get_theme, do: %{}
    end

    conn = LoadTheme.call(conn, [])

    assert conn.assigns[:theme]["title"] == "MISSING_THEME"
    assert conn.assigns[:theme]["tagline"] == "Add host theme config or set THEME_CONFIG"
    assert conn.assigns[:theme]["logo"] == "/images/logo.png"
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
