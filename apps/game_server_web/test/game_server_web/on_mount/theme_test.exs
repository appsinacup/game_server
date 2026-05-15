defmodule GameServerWeb.OnMount.ThemeTest do
  use ExUnit.Case, async: false

  alias GameServer.Theme.JSONConfig
  alias GameServerWeb.GettextSync
  alias GameServerWeb.OnMount.Theme
  alias Phoenix.LiveView

  setup do
    orig_theme_config = System.get_env("THEME_CONFIG")
    orig_locale = Gettext.get_locale(GameServerWeb.Gettext)

    JSONConfig.reload()

    on_exit(fn ->
      if orig_theme_config do
        System.put_env("THEME_CONFIG", orig_theme_config)
      else
        System.delete_env("THEME_CONFIG")
      end

      GettextSync.put_locale(orig_locale)
      JSONConfig.reload()
    end)

    :ok
  end

  test "assigns theme for current locale on each mount" do
    base =
      Path.join(System.tmp_dir!(), "theme_on_mount_#{System.unique_integer([:positive])}.json")

    en_path = String.trim_trailing(base, ".json") <> ".en.json"
    id_path = String.trim_trailing(base, ".json") <> ".id.json"

    File.write!(en_path, Jason.encode!(%{"title" => "English Title"}))
    File.write!(id_path, Jason.encode!(%{"title" => "Indonesian Title"}))

    System.put_env("THEME_CONFIG", base)
    JSONConfig.reload()

    on_exit(fn ->
      File.rm(en_path)
      File.rm(id_path)
    end)

    GettextSync.put_locale("id")
    {:cont, id_socket} = Theme.on_mount(:mount_theme, %{}, %{}, %LiveView.Socket{})

    GettextSync.put_locale("en")
    {:cont, en_socket} = Theme.on_mount(:mount_theme, %{}, %{}, %LiveView.Socket{})

    assert id_socket.assigns.theme["title"] == "Indonesian Title"
    assert en_socket.assigns.theme["title"] == "English Title"
  end
end
