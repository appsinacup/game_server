defmodule GameServerWeb.PresentationPageTest do
  use ExUnit.Case, async: true

  alias GameServerWeb.PresentationPage

  describe "page_for_path/2" do
    test "returns configured page by path" do
      theme = %{
        "pages" => %{
          "home" => %{"path" => "/", "hero" => %{"title" => "Home"}},
          "brand" => %{"path" => "/brand", "hero" => %{"title" => "Brand"}}
        }
      }

      assert %{"key" => "brand", "hero" => %{"title" => "Brand"}} =
               PresentationPage.page_for_path(theme, "/brand")
    end

    test "returns nil for missing page path" do
      assert is_nil(PresentationPage.page_for_path(%{"pages" => %{}}, "/missing"))
    end
  end

  describe "rich_text/1" do
    test "returns safe HTML for plain text" do
      result = PresentationPage.rich_text("Hello world")
      assert {:safe, _} = result
      assert Phoenix.HTML.safe_to_string(result) == "Hello world"
    end

    test "converts single **bold** to <strong>" do
      result = PresentationPage.rich_text("Hello **world**")
      html = Phoenix.HTML.safe_to_string(result)
      assert html == "Hello <strong>world</strong>"
    end

    test "converts multiple **bold** groups" do
      result =
        PresentationPage.rich_text(
          "**Open source** Elixir game server for **real-time** multiplayer games."
        )

      html = Phoenix.HTML.safe_to_string(result)

      assert html ==
               "<strong>Open source</strong> Elixir game server for <strong>real-time</strong> multiplayer games."
    end

    test "converts italic and safe links" do
      result = PresentationPage.rich_text("Read *more* in the [docs](/docs/setup).")
      html = Phoenix.HTML.safe_to_string(result)

      assert html =~ "<em>more</em>"
      assert html =~ ~s(<a href="/docs/setup" class="link link-primary">docs</a>)
    end

    test "escapes HTML entities before applying bold" do
      result = PresentationPage.rich_text("**<script>**alert**</script>**")
      html = Phoenix.HTML.safe_to_string(result)
      refute html =~ "<script>"
      assert html =~ "&lt;script&gt;"
      assert html =~ "<strong>"
    end

    test "returns empty safe HTML for nil" do
      result = PresentationPage.rich_text(nil)
      assert {:safe, _} = result
      assert Phoenix.HTML.safe_to_string(result) == ""
    end

    test "returns empty safe HTML for empty string" do
      result = PresentationPage.rich_text("")
      assert {:safe, _} = result
      assert Phoenix.HTML.safe_to_string(result) == ""
    end

    test "handles text with no bold markers" do
      result = PresentationPage.rich_text("No bold here at all.")
      html = Phoenix.HTML.safe_to_string(result)
      assert html == "No bold here at all."
    end
  end
end
