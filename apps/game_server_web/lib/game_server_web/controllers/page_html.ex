defmodule GameServerWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use GameServerWeb, :html

  embed_templates "page_html/*"

  @bold_pattern ~r/\*\*(.+?)\*\*/
  @italic_pattern ~r/(?<!\*)\*([^*\n]+)\*(?!\*)/
  @link_pattern ~r/\[([^\]]+)\]\(([^)\s]+)\)/

  @doc """
  Converts a plain-text description to safe HTML.

  Supports a small markdown subset: links, bold, and italic.
  """
  @spec format_description(String.t()) :: Phoenix.HTML.safe()
  def format_description(text), do: format_rich_text(text)

  @spec format_rich_text(String.t()) :: Phoenix.HTML.safe()
  def format_rich_text(text) when is_binary(text) do
    text
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
    |> then(fn escaped ->
      Regex.replace(@link_pattern, escaped, fn _match, label, href ->
        if safe_markdown_href?(href) do
          ~s(<a href="#{href}" class="link link-primary">#{label}</a>)
        else
          "#{label} (#{href})"
        end
      end)
    end)
    |> then(&Regex.replace(@bold_pattern, &1, "<strong>\\1</strong>"))
    |> then(&Regex.replace(@italic_pattern, &1, "<em>\\1</em>"))
    |> Phoenix.HTML.raw()
  end

  def format_rich_text(_), do: Phoenix.HTML.raw("")

  def home_config(theme) when is_map(theme) do
    home = Map.get(theme, "home", %{})
    home = if is_map(home), do: home, else: %{}

    hero =
      theme
      |> default_home_hero()
      |> Map.merge(map_value(home, "hero"))

    sections =
      case Map.get(home, "sections") do
        sections when is_list(sections) and sections != [] -> sections
        _ -> default_home_sections(theme)
      end

    %{
      "hero" => hero,
      "sections" => sections,
      "sections_columns" => Map.get(home, "sections_columns", 2)
    }
  end

  def home_config(_theme), do: home_config(%{})

  attr :buttons, :list, default: []

  def home_buttons(assigns) do
    buttons = if is_list(assigns.buttons), do: assigns.buttons, else: []
    assigns = assign(assigns, buttons: Enum.filter(buttons, &valid_button?/1))

    ~H"""
    <div
      :if={@buttons != []}
      class="flex w-full flex-col gap-3 sm:flex-row sm:flex-wrap sm:justify-center"
    >
      <a
        :for={button <- @buttons}
        href={button_href(button)}
        target={if button["external"], do: "_blank"}
        rel={if button["external"], do: "noopener noreferrer"}
        class={home_button_class(button)}
      >
        <.dynamic_icon
          :if={button["icon"]}
          name={button["icon"]}
          class="size-5 shrink-0 text-current"
        />
        <span class="truncate">{button_label(button)}</span>
      </a>
    </div>
    """
  end

  attr :item, :map, required: true
  attr :variant, :string, default: "section"

  def home_media(assigns) do
    assigns =
      assign(assigns,
        src: media_src(assigns.item),
        alt: media_alt(assigns.item),
        icon: Map.get(assigns.item, "icon")
      )

    ~H"""
    <div class="flex w-full items-center justify-center">
      <img
        :if={@src}
        src={@src}
        alt={@alt}
        loading={if(@variant == "hero", do: "eager", else: "lazy")}
        fetchpriority={if(@variant == "hero", do: "high", else: nil)}
        class={home_media_class(@variant)}
      />
      <div
        :if={!@src && @icon}
        class="grid aspect-square w-full max-w-48 place-items-center rounded-lg border border-base-300/70 bg-base-100/70 text-base-content/70 shadow-sm"
      >
        <.dynamic_icon name={@icon} class="size-16" />
      </div>
    </div>
    """
  end

  attr :section, :map, required: true

  def home_section(assigns) do
    ~H"""
    <section class={[
      "flex min-h-[calc(100dvh-5rem)] items-center py-12",
      home_section_span_class(@section)
    ]}>
      <div class={[
        "grid w-full items-center gap-6 md:gap-8",
        home_grid_class(@section, "section")
      ]}>
        <div class={home_media_order_class(@section)}>
          <.home_media item={@section} variant="section" />
        </div>
        <div class={[
          "flex flex-col gap-4",
          home_text_order_class(@section),
          home_text_align_class(@section)
        ]}>
          <h2 class="text-2xl font-bold tracking-normal sm:text-3xl">
            {Map.get(@section, "title", "")}
          </h2>
          <div class="text-base leading-relaxed text-base-content/75">
            {format_rich_text(Map.get(@section, "text") || Map.get(@section, "description", ""))}
          </div>
          <.home_buttons buttons={Map.get(@section, "buttons", [])} />
        </div>
      </div>
    </section>
    """
  end

  def home_grid_class(item, variant) do
    width = media_width(item, variant)
    desktop_position = desktop_image_position(item)

    case {width, desktop_position} do
      {"third", "right"} -> "md:grid-cols-[minmax(0,1.2fr)_minmax(0,0.8fr)]"
      {"third", _} -> "md:grid-cols-[minmax(0,0.8fr)_minmax(0,1.2fr)]"
      {"wide", "right"} -> "md:grid-cols-[minmax(0,0.85fr)_minmax(0,1.15fr)]"
      {"wide", _} -> "md:grid-cols-[minmax(0,1.15fr)_minmax(0,0.85fr)]"
      _ -> "md:grid-cols-2"
    end
  end

  def home_sections_grid_class(columns) when columns in [1, "1", "1x"], do: "md:grid-cols-1"
  def home_sections_grid_class(_columns), do: "md:grid-cols-2"

  def home_section_span_class(section) do
    case Map.get(section, "width", "1x") do
      value when value in [2, "2", "2x", "full"] -> "md:col-span-2"
      _ -> "md:col-span-1"
    end
  end

  def home_media_order_class(item) do
    [
      if(mobile_image_position(item) == "bottom", do: "order-2", else: "order-1"),
      if(desktop_image_position(item) == "right", do: "md:order-2", else: "md:order-1")
    ]
  end

  def home_text_order_class(item) do
    [
      if(mobile_image_position(item) == "bottom", do: "order-1", else: "order-2"),
      if(desktop_image_position(item) == "right", do: "md:order-1", else: "md:order-2")
    ]
  end

  def home_text_align_class(item) do
    case Map.get(item, "text_align", "center") do
      "left" -> "text-left items-start"
      "right" -> "text-right items-end"
      _ -> "text-center items-center"
    end
  end

  defp default_home_hero(theme) do
    %{
      "title" => Map.get(theme, "title", ""),
      "text" => Map.get(theme, "description", ""),
      "image" => Map.get(theme, "banner", "/images/banner.png"),
      "image_alt" => Map.get(theme, "title", ""),
      "image_position_desktop" => "left",
      "image_position_mobile" => "top",
      "media_width" => "half",
      "text_align" => "center",
      "buttons" => Map.get(theme, "useful_links", [])
    }
  end

  defp default_home_sections(theme) do
    theme
    |> Map.get("features", [])
    |> Enum.with_index()
    |> Enum.map(fn {feature, index} ->
      %{
        "title" => Map.get(feature, "title", ""),
        "text" => Map.get(feature, "description", ""),
        "icon" => Map.get(feature, "icon"),
        "width" => "1x",
        "media_width" => "third",
        "image_position_desktop" => if(rem(index, 2) == 0, do: "left", else: "right"),
        "image_position_mobile" => "top",
        "text_align" => "left"
      }
    end)
  end

  defp map_value(map, key) do
    case Map.get(map, key) do
      value when is_map(value) -> value
      _ -> %{}
    end
  end

  defp media_src(item) do
    Enum.find_value(["image", "media", "src"], &Map.get(item, &1))
  end

  defp media_alt(item), do: Map.get(item, "image_alt") || Map.get(item, "alt") || ""

  defp media_width(item, "hero"), do: Map.get(item, "media_width", "half")
  defp media_width(item, _variant), do: Map.get(item, "media_width", "third")

  defp desktop_image_position(item) do
    Map.get(item, "image_position_desktop") || Map.get(item, "image_position") || "left"
  end

  defp mobile_image_position(item), do: Map.get(item, "image_position_mobile", "top")

  defp home_media_class("hero") do
    "block max-h-[58dvh] w-full rounded-lg object-contain"
  end

  defp home_media_class(_variant) do
    "block aspect-square max-h-[42dvh] w-full rounded-lg object-contain"
  end

  defp home_button_class(button) do
    base =
      "group flex min-h-11 w-full items-center justify-center gap-2.5 rounded-lg px-5 py-2.5 text-base font-semibold transition hover:scale-[1.02] active:scale-[0.98] sm:w-auto sm:flex-1 lg:flex-none"

    style =
      case Map.get(button, "style", "default") do
        "primary" ->
          "bg-primary text-primary-content shadow-lg hover:bg-primary/90"

        "secondary" ->
          "bg-secondary text-secondary-content shadow-lg hover:bg-secondary/90"

        "accent" ->
          "bg-accent text-accent-content shadow-lg hover:bg-accent/90"

        _ ->
          "border border-base-300/85 bg-base-100/88 text-base-content shadow-lg shadow-black/6 backdrop-blur-md hover:bg-base-100"
      end

    [base, style]
  end

  defp valid_button?(button) when is_map(button) do
    is_binary(button_href(button)) and button_href(button) != ""
  end

  defp valid_button?(_button), do: false

  defp button_href(button), do: Map.get(button, "url") || Map.get(button, "href")
  defp button_label(button), do: Map.get(button, "title") || Map.get(button, "label") || ""

  defp safe_markdown_href?(href) when is_binary(href) do
    String.starts_with?(href, "/") or String.starts_with?(href, "http://") or
      String.starts_with?(href, "https://") or String.starts_with?(href, "mailto:")
  end

  defp safe_markdown_href?(_href), do: false
end
