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

  test "loads theme from locale-specific JSON path" do
    # Only locale-suffixed files are loaded — create the .en.json variant
    base = Path.join(System.tmp_dir!(), "theme_test_#{System.unique_integer([:positive])}.json")
    en_path = String.trim_trailing(base, ".json") <> ".en.json"

    json = Jason.encode!(%{"title" => "My Test", "logo" => "/theme/logo.png"})
    File.write!(en_path, json)

    on_exit(fn -> File.rm(en_path) end)

    System.put_env("THEME_CONFIG", base)

    theme = JSONConfig.get_theme()
    assert theme == %{"title" => "My Test", "logo" => "/theme/logo.png"}
  end

  test "prefers locale-specific config when present" do
    base =
      Path.join(System.tmp_dir!(), "theme_test_base_#{System.unique_integer([:positive])}.json")

    en_path = String.trim_trailing(base, ".json") <> ".en.json"
    es_path = String.trim_trailing(base, ".json") <> ".es.json"

    File.write!(en_path, Jason.encode!(%{"title" => "English Title", "logo" => "/en.png"}))
    File.write!(es_path, Jason.encode!(%{"title" => "Titulo ES", "logo" => "/es.png"}))

    on_exit(fn ->
      File.rm(en_path)
      File.rm(es_path)
    end)

    System.put_env("THEME_CONFIG", base)

    assert %{"title" => "Titulo ES", "logo" => "/es.png"} = JSONConfig.get_theme("es")
    # nil locale falls back to .en variant
    assert %{"title" => "English Title", "logo" => "/en.png"} = JSONConfig.get_theme()
  end

  test "returns empty map when THEME_CONFIG points to missing file" do
    System.put_env("THEME_CONFIG", "nonexistent.json")

    theme = JSONConfig.get_theme()
    assert theme == %{}
  end

  test "falls back to the host default theme when THEME_CONFIG is unset" do
    System.delete_env("THEME_CONFIG")

    theme = JSONConfig.get_theme()
    assert theme["title"] == "Gamend"
    assert is_list(theme["footer_links"])
    assert is_map(theme["navigation"])
  end

  test "treats blank THEME_CONFIG as unset and uses the host default theme" do
    System.put_env("THEME_CONFIG", "")

    theme = JSONConfig.get_theme()
    assert theme["title"] == "Gamend"
    assert is_list(theme["footer_links"])
  end

  test "runtime_path reports only the env override while active_path includes host default" do
    System.delete_env("THEME_CONFIG")

    assert JSONConfig.runtime_path() == nil
    assert String.ends_with?(JSONConfig.active_path(), "/theme/config.json")
  end

  test "normalizes relative asset paths from runtime JSON" do
    base =
      Path.join(System.tmp_dir!(), "theme_test_paths_#{System.unique_integer([:positive])}.json")

    en_path = String.trim_trailing(base, ".json") <> ".en.json"

    json =
      Jason.encode!(%{
        "description" => "Path Test",
        "title" => "Path Test",
        "css" => "custom/example_theme.css",
        "logo" => "custom/example_logo.png",
        "banner" => "custom/example_banner.png",
        "banner_link" => "/docs/setup",
        "favicon" => "custom/favicon.ico",
        "changelog" => "/CHANGELOG.md",
        "roadmap" => "/ROADMAP.md",
        "blog" => "/blog"
      })

    File.write!(en_path, json)

    on_exit(fn -> File.rm(en_path) end)

    System.put_env("THEME_CONFIG", base)

    theme = JSONConfig.get_theme()

    assert Map.get(theme, "description") == "Path Test"
    assert Map.get(theme, "title") == "Path Test"
    assert Map.get(theme, "css") == "/custom/example_theme.css"
    assert Map.get(theme, "logo") == "/custom/example_logo.png"
    assert Map.get(theme, "banner") == "/custom/example_banner.png"
    assert Map.get(theme, "banner_link") == "/docs/setup"
    assert Map.get(theme, "favicon") == "/custom/favicon.ico"
    assert Map.get(theme, "changelog") == "/CHANGELOG.md"
    assert Map.get(theme, "roadmap") == "/ROADMAP.md"
    assert Map.get(theme, "blog") == "/blog"
  end
end
