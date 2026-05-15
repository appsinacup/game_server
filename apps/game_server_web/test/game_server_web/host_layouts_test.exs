defmodule GameServerWeb.HostLayoutsTest do
  use ExUnit.Case, async: true

  alias GameServerWeb.HostLayouts

  test "theme image settings override host defaults" do
    theme =
      HostLayouts.resolve_theme("en", %{
        "title" => "Custom",
        "logo" => "/images/custom-logo.webp",
        "banner" => "/images/custom-banner.webp",
        "favicon" => "/images/custom.ico"
      })

    assert theme["logo"] == "/images/custom-logo.webp"
    assert theme["banner"] == "/images/custom-banner.webp"
    assert theme["favicon"] == "/images/custom.ico"
  end
end
