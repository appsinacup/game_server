defmodule GameServerWeb.PresentationPageTest do
  use ExUnit.Case, async: true
  import Phoenix.LiveViewTest

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

  describe "page/1" do
    test "supports page-level section height defaults" do
      html =
        render_component(&PresentationPage.page/1,
          page: %{
            "hero" => %{"title" => "Demo"},
            "sections_height" => "half",
            "sections" => [
              %{"title" => "One", "text" => "First", "icon" => "hero-home-solid"}
            ]
          },
          background_icons: [],
          full_bleed_hero: false
        )

      assert html =~ "min-h-[calc(50dvh-2.5rem)]"
      assert html =~ ~s|class="flex items-start min-h-[calc(50dvh-2.5rem)] py-8 md:col-span-1"|
      assert html =~ "md:grid-rows-[5.5rem_6.5rem_auto]"
    end

    test "renders animated scroll cue when sections follow hero" do
      html =
        render_component(&PresentationPage.page/1,
          page: %{
            "hero" => %{"title" => "Demo"},
            "sections" => [
              %{"title" => "One", "text" => "First", "icon" => "hero-home-solid"}
            ]
          },
          background_icons: [],
          full_bleed_hero: false
        )

      assert html =~ ~s(href="#more-content")
      assert html =~ ~s(aria-label="Scroll to content")
      assert html =~ "motion-safe:animate-bounce"
    end

    test "does not render scroll cue when no sections follow hero" do
      html =
        render_component(&PresentationPage.page/1,
          page: %{"hero" => %{"title" => "Demo"}},
          background_icons: [],
          full_bleed_hero: false
        )

      refute html =~ ~s(aria-label="Scroll to content")
    end

    test "media supports configurable links" do
      html =
        render_component(&PresentationPage.page/1,
          page: %{
            "hero" => %{
              "title" => "Demo",
              "image" => "/images/banner.png",
              "media_href" => "/play",
              "media_label" => "Open play"
            },
            "sections" => [
              %{
                "title" => "One",
                "text" => "First",
                "icon" => "hero-home-solid",
                "media_href" => "/groups",
                "media_label" => "Open groups"
              }
            ]
          },
          background_icons: [],
          full_bleed_hero: false
        )

      assert html =~ ~s(href="/play")
      assert html =~ ~s(aria-label="Open play")
      assert html =~ ~s(href="/groups")
      assert html =~ ~s(aria-label="Open groups")
      assert html =~ "motion-safe:hover:scale-[1.04]"
    end

    test "media ignores unsafe link targets" do
      html =
        render_component(&PresentationPage.page/1,
          page: %{
            "hero" => %{
              "title" => "Demo",
              "image" => "/images/banner.png",
              "media_href" => "javascript:alert(1)"
            }
          },
          background_icons: [],
          full_bleed_hero: false
        )

      refute html =~ "javascript:alert"
      assert html =~ "motion-safe:hover:scale-[1.02]"
    end

    test "compact section height uses content size" do
      html =
        render_component(&PresentationPage.page/1,
          page: %{
            "hero" => %{"title" => "Demo"},
            "sections" => [
              %{
                "title" => "One",
                "text" => "First",
                "icon" => "hero-home-solid",
                "height" => "compact"
              }
            ]
          },
          background_icons: [],
          full_bleed_hero: false
        )

      assert html =~ ~s(class="flex items-start py-8 md:col-span-1")

      assert html =~
               ~s|class="grid w-full gap-6 md:gap-8 items-start md:grid-cols-[minmax(0,0.8fr)_minmax(0,1.2fr)]"|

      assert html =~ "md:grid-rows-[5rem_6rem_auto]"

      refute html =~ "min-h-[18rem]"
    end
  end
end
