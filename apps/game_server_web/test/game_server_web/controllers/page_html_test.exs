defmodule GameServerWeb.PageHTMLTest do
  use ExUnit.Case, async: true

  alias GameServerWeb.PageHTML

  describe "format_description/1" do
    test "returns safe HTML for plain text" do
      result = PageHTML.format_description("Hello world")
      assert {:safe, _} = result
      assert Phoenix.HTML.safe_to_string(result) == "Hello world"
    end

    test "converts single **bold** to <strong>" do
      result = PageHTML.format_description("Hello **world**")
      html = Phoenix.HTML.safe_to_string(result)
      assert html == "Hello <strong>world</strong>"
    end

    test "converts multiple **bold** groups" do
      result =
        PageHTML.format_description(
          "**Open source** Elixir game server for **real-time** multiplayer games."
        )

      html = Phoenix.HTML.safe_to_string(result)

      assert html ==
               "<strong>Open source</strong> Elixir game server for <strong>real-time</strong> multiplayer games."
    end

    test "escapes HTML entities before applying bold" do
      result = PageHTML.format_description("**<script>**alert**</script>**")
      html = Phoenix.HTML.safe_to_string(result)
      refute html =~ "<script>"
      assert html =~ "&lt;script&gt;"
      assert html =~ "<strong>"
    end

    test "returns empty safe HTML for nil" do
      result = PageHTML.format_description(nil)
      assert {:safe, _} = result
      assert Phoenix.HTML.safe_to_string(result) == ""
    end

    test "returns empty safe HTML for empty string" do
      result = PageHTML.format_description("")
      assert {:safe, _} = result
      assert Phoenix.HTML.safe_to_string(result) == ""
    end

    test "handles text with no bold markers" do
      result = PageHTML.format_description("No bold here at all.")
      html = Phoenix.HTML.safe_to_string(result)
      assert html == "No bold here at all."
    end
  end
end
