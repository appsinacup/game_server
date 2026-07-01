defmodule GameServer.ContentTest do
  use ExUnit.Case, async: false

  alias GameServer.Content

  test "asset_path rejects sibling directory traversal with shared prefix" do
    root =
      Path.join(System.tmp_dir!(), "game_server_content_#{System.unique_integer([:positive])}")

    base = Path.join(root, "blog")
    sibling = Path.join(root, "blog_secret")
    name = "content_test_#{System.unique_integer([:positive])}"

    File.mkdir_p!(base)
    File.mkdir_p!(sibling)
    File.write!(Path.join(base, "image.png"), "ok")
    File.write!(Path.join(sibling, "secret.txt"), "secret")

    on_exit(fn -> File.rm_rf(root) end)

    Content.register_path(name, kind: :dir, path: base, asset_root: :self)

    assert Content.asset_path(name, "image.png") == Path.join(base, "image.png")
    assert Content.asset_path(name, "../blog_secret/secret.txt") == nil
  end

  test "markdown rendering strips unsafe HTML and link attributes" do
    root =
      Path.join(System.tmp_dir!(), "game_server_content_#{System.unique_integer([:positive])}")

    path = Path.join(root, "CHANGELOG.md")
    original_changelog_path = Content.path(:changelog) || "CHANGELOG.md"

    File.mkdir_p!(root)

    File.write!(path, """
    # Changelog

    [click](http://example.com/?a=x " onerror="alert(1))

    <script>alert(2)</script>
    """)

    on_exit(fn ->
      Content.register_path(:changelog, kind: :file, path: original_changelog_path)
      File.rm_rf(root)
    end)

    Content.register_path(:changelog, kind: :file, path: path)

    html = Content.changelog_html()

    assert html =~ "Click"
    refute html =~ ~r/<[^>]+onerror/i
    refute html =~ "<script"
    refute html =~ ~r/<[^>]+alert/i
  end
end
