defmodule GameServer.Theme.JSONConfigTest do
  use ExUnit.Case, async: false

  alias GameServer.Content
  alias GameServer.Theme.JSONConfig

  setup do
    # ensure any global env change is reset after
    orig = System.get_env("THEME_CONFIG")

    # Clear theme cache before each test so env var changes take effect
    JSONConfig.reload()
    Content.reload()

    on_exit(fn ->
      if orig, do: System.put_env("THEME_CONFIG", orig), else: System.delete_env("THEME_CONFIG")
      JSONConfig.reload()
      Content.reload()
    end)

    :ok
  end

  test "loads theme from given JSON path" do
    tmp = Path.join(System.tmp_dir!(), "theme_test_#{System.unique_integer([:positive])}.json")
    json = Jason.encode!(%{"title" => "My Test", "logo" => "/theme/logo.png"})
    File.write!(tmp, json)

    System.put_env("THEME_CONFIG", tmp)

    theme = JSONConfig.get_theme()
    assert %{"title" => "My Test", "logo" => "/theme/logo.png"} = theme
    # default css path should be merged in when not provided by the file
    assert Map.has_key?(theme, "css")
  end

  test "prefers locale-specific config when present" do
    base =
      Path.join(System.tmp_dir!(), "theme_test_base_#{System.unique_integer([:positive])}.json")

    localized = String.trim_trailing(base, ".json") <> ".es.json"

    File.write!(base, Jason.encode!(%{"title" => "Base Title", "logo" => "/base.png"}))
    File.write!(localized, Jason.encode!(%{"title" => "Titulo ES", "logo" => "/es.png"}))

    orig = System.get_env("THEME_CONFIG")
    System.put_env("THEME_CONFIG", base)

    on_exit(fn ->
      if orig, do: System.put_env("THEME_CONFIG", orig), else: System.delete_env("THEME_CONFIG")
      File.rm(base)
      File.rm(localized)
    end)

    assert %{"title" => "Titulo ES", "logo" => "/es.png"} = JSONConfig.get_theme("es")
    assert %{"title" => "Base Title", "logo" => "/base.png"} = JSONConfig.get_theme()
  end

  test "falls back to default when file missing" do
    System.put_env("THEME_CONFIG", "nonexistent.json")

    theme = JSONConfig.get_theme()
    assert is_map(theme)
    assert Map.has_key?(theme, "title")
    # ensure css default is present when falling back
    default_path = Path.join(:code.priv_dir(:game_server_web), "static/theme/default_config.json")
    {:ok, file} = File.read(default_path)
    expected = Jason.decode!(file)

    assert Map.get(theme, "css") == expected["css"]
  end

  test "falls back to default when THEME_CONFIG is unset (nil)" do
    # ensure THEME_CONFIG is unset for this test
    orig = System.get_env("THEME_CONFIG")
    System.delete_env("THEME_CONFIG")

    on_exit(fn ->
      if orig, do: System.put_env("THEME_CONFIG", orig), else: System.delete_env("THEME_CONFIG")
    end)

    theme = JSONConfig.get_theme()
    assert is_map(theme)
    assert Map.has_key?(theme, "title")
    default_path = Path.join(:code.priv_dir(:game_server_web), "static/theme/default_config.json")
    {:ok, file} = File.read(default_path)
    expected = Jason.decode!(file)

    assert Map.get(theme, "css") == expected["css"]
  end

  test "treats blank THEME_CONFIG as unset (empty string)" do
    orig = System.get_env("THEME_CONFIG")
    System.put_env("THEME_CONFIG", "")

    on_exit(fn ->
      if orig, do: System.put_env("THEME_CONFIG", orig), else: System.delete_env("THEME_CONFIG")
    end)

    theme = JSONConfig.get_theme()
    assert is_map(theme)
    assert Map.get(theme, "title") == "Gamend"
  end

  test "runtime JSON with empty keys does not override packaged defaults" do
    # create temporary theme file that has empty values which should NOT
    # override the packaged defaults when merged
    tmp =
      Path.join(System.tmp_dir!(), "theme_test_empty_#{System.unique_integer([:positive])}.json")

    json = Jason.encode!(%{"title" => "", "tagline" => "", "logo" => ""})
    File.write!(tmp, json)

    orig = System.get_env("THEME_CONFIG")
    System.put_env("THEME_CONFIG", tmp)

    on_exit(fn ->
      if orig, do: System.put_env("THEME_CONFIG", orig), else: System.delete_env("THEME_CONFIG")
      File.rm(tmp)
    end)

    theme = JSONConfig.get_theme()

    # packaged default should still be present for top-level keys
    default_path = Path.join(:code.priv_dir(:game_server_web), "static/theme/default_config.json")
    {:ok, file} = File.read(default_path)
    expected = Jason.decode!(file)

    assert Map.get(theme, "title") == expected["title"]
    assert Map.get(theme, "tagline") == expected["tagline"]
    assert Map.get(theme, "logo") == expected["logo"]
  end

  test "normalizes relative asset paths from runtime JSON" do
    tmp =
      Path.join(System.tmp_dir!(), "theme_test_paths_#{System.unique_integer([:positive])}.json")

    json =
      Jason.encode!(%{
        "title" => "Path Test",
        "css" => "custom/example_theme.css",
        "logo" => "custom/example_logo.png",
        "banner" => "custom/example_banner.png",
        "favicon" => "custom/favicon.ico"
      })

    File.write!(tmp, json)

    orig = System.get_env("THEME_CONFIG")
    System.put_env("THEME_CONFIG", tmp)

    on_exit(fn ->
      if orig, do: System.put_env("THEME_CONFIG", orig), else: System.delete_env("THEME_CONFIG")
      File.rm(tmp)
    end)

    theme = JSONConfig.get_theme()

    assert Map.get(theme, "css") == "/custom/example_theme.css"
    assert Map.get(theme, "logo") == "/custom/example_logo.png"
    assert Map.get(theme, "banner") == "/custom/example_banner.png"
    assert Map.get(theme, "favicon") == "/custom/favicon.ico"
  end
end
