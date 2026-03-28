defmodule GameServerWeb.HomeThemeTest do
  use GameServerWeb.ConnCase, async: true

  alias GameServer.Content
  alias GameServer.Theme.JSONConfig

  test "home page renders without errors when runtime theme has empty values", %{conn: conn} do
    # Create an .en.json file with empty values — no merging with packaged defaults
    base =
      Path.join(System.tmp_dir!(), "theme_test_home_#{System.unique_integer([:positive])}.json")

    en_path = String.trim_trailing(base, ".json") <> ".en.json"

    File.write!(en_path, Jason.encode!(%{"title" => "", "tagline" => ""}))

    orig = System.get_env("THEME_CONFIG")
    System.put_env("THEME_CONFIG", base)
    JSONConfig.reload()
    Content.reload()

    on_exit(fn ->
      if orig, do: System.put_env("THEME_CONFIG", orig), else: System.delete_env("THEME_CONFIG")
      JSONConfig.reload()
      Content.reload()
      File.rm(en_path)
    end)

    resp = get(conn, "/") |> html_response(200)

    # Page should render without crashing
    assert resp =~ "<html"
    assert resp =~ "<title"
  end
end
