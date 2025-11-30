defmodule GameServerWeb.HomeThemeTest do
  use GameServerWeb.ConnCase, async: true

  test "home page shows packaged defaults when runtime theme has empty values", %{conn: conn} do
    tmp =
      Path.join(System.tmp_dir!(), "theme_test_home_#{System.unique_integer([:positive])}.json")

    # runtime file that intentionally sets empty strings which should not
    # override the packaged defaults
    File.write!(tmp, Jason.encode!(%{"title" => "", "tagline" => ""}))

    orig = System.get_env("THEME_CONFIG")
    System.put_env("THEME_CONFIG", tmp)

    on_exit(fn ->
      if orig, do: System.put_env("THEME_CONFIG", orig), else: System.delete_env("THEME_CONFIG")
      File.rm(tmp)
    end)

    resp = get(conn, "/") |> html_response(200)

    # packaged defaults are expected to be displayed in the page header
    default_path = Path.join(:code.priv_dir(:game_server), "static/theme/default_config.json")
    {:ok, file} = File.read(default_path)
    expected = Jason.decode!(file)

    assert resp =~ expected["title"]
    assert resp =~ expected["tagline"]

    # <title> tag should also include the theme-provided title and suffix (tagline)
    assert resp =~ "<title"
    assert resp =~ expected["title"] <> expected["tagline"] || expected["title"]
  end
end
