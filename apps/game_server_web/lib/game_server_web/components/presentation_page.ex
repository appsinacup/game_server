defmodule GameServerWeb.PresentationPage do
  @moduledoc """
  Shared hero-and-sections page renderer for host presentation pages.
  """

  use GameServerWeb, :html

  @bold_pattern ~r/\*\*(.+?)\*\*/
  @italic_pattern ~r/(?<!\*)\*([^*\n]+)\*(?!\*)/
  @link_pattern ~r/\[([^\]]+)\]\(([^)\s]+)\)/

  def page_for_path(theme, path) when is_map(theme) do
    normalized_path = normalize_path(path)

    theme
    |> Map.get("pages", %{})
    |> case do
      pages when is_map(pages) ->
        Enum.find_value(pages, fn {key, page} ->
          if presentation_page?(page) and normalize_path(Map.get(page, "path")) == normalized_path do
            Map.put(page, "key", key)
          end
        end)

      _ ->
        nil
    end
  end

  def page_for_path(_theme, _path), do: nil

  def page_title(page, fallback \\ "Page")

  def page_title(page, fallback) when is_map(page) do
    case get_in(page, ["hero", "title"]) do
      value when is_binary(value) and value != "" -> value
      _ -> fallback
    end
  end

  def page_title(_page, fallback), do: fallback

  attr :page, :map, required: true
  attr :background_icons, :list, default: []
  attr :full_bleed_hero, :boolean, default: true

  def page(assigns) do
    assigns =
      assign(assigns,
        hero: Map.get(assigns.page, "hero", %{}),
        sections: sections_with_page_defaults(assigns.page),
        sections_columns: Map.get(assigns.page, "sections_columns", 2)
      )

    ~H"""
    <div class={
      if(@full_bleed_hero, do: "relative w-screen left-1/2 -translate-x-1/2 -mt-20", else: "")
    }>
      <section class="relative min-h-screen overflow-hidden">
        <.background_icons icons={@background_icons} />
        <div class="relative z-10 flex min-h-screen items-center px-6 pb-12 pt-24 sm:px-8 lg:px-12">
          <div class={[
            "mx-auto grid w-full max-w-6xl items-center gap-8 lg:gap-12",
            grid_class(@hero, "hero")
          ]}>
            <div class={media_order_class(@hero)}>
              <.media item={@hero} variant="hero" />
            </div>
            <div class={[
              "flex flex-col gap-5",
              text_order_class(@hero),
              text_align_class(@hero)
            ]}>
              <h1 class="text-4xl font-extrabold tracking-normal sm:text-5xl lg:text-6xl">
                {Map.get(@hero, "title", "")}
              </h1>
              <div class="max-w-2xl text-base leading-relaxed text-base-content/75 sm:text-lg lg:text-xl">
                {rich_text(Map.get(@hero, "text", ""))}
              </div>
              <.buttons buttons={Map.get(@hero, "buttons", [])} />
            </div>
          </div>
        </div>
        <a
          :if={@sections != []}
          href="#more-content"
          aria-label="Scroll to content"
          class="absolute bottom-6 left-1/2 z-20 -translate-x-1/2 text-base-content/55 transition hover:text-base-content motion-safe:animate-bounce"
        >
          <.dynamic_icon name="hero-chevron-down-solid" class="size-9" />
        </a>
      </section>
    </div>

    <div id="more-content" class="scroll-mt-20"></div>

    <div
      :if={@sections != []}
      class={["grid gap-x-8 gap-y-4", sections_grid_class(@sections_columns)]}
    >
      <%= for section <- @sections do %>
        <.section section={section} />
      <% end %>
    </div>
    """
  end

  attr :icons, :list, default: []

  def background_icons(assigns) do
    ~H"""
    <div
      :if={@icons != []}
      class="absolute inset-0 overflow-hidden pointer-events-none z-[1]"
      aria-hidden="true"
    >
      <%= for placement <- GameServerWeb.Layouts.icon_placements(@icons) do %>
        <div
          class={[
            "absolute text-base-content [[data-theme=dark]_&]:text-white opacity-[0.08] [[data-theme=dark]_&]:opacity-[0.10]",
            placement.size
          ]}
          style={"top: #{placement.top}%; #{if Map.has_key?(placement, :left), do: "left: #{placement.left}%", else: "right: #{placement.right}%"}; animation: float #{placement.dur}s ease-in-out infinite #{placement.delay}s;"}
        >
          <.dynamic_icon name={placement.name} class={placement.size} />
        </div>
      <% end %>
    </div>
    """
  end

  attr :buttons, :list, default: []

  def buttons(assigns) do
    buttons = if is_list(assigns.buttons), do: assigns.buttons, else: []
    assigns = assign(assigns, buttons: Enum.filter(buttons, &valid_button?/1))

    ~H"""
    <div
      :if={@buttons != []}
      class="flex w-full flex-col gap-3 sm:flex-row sm:flex-wrap sm:justify-center"
    >
      <a
        :for={button <- @buttons}
        href={button["href"]}
        target={if button["external"], do: "_blank"}
        rel={if button["external"], do: "noopener noreferrer"}
        class={button_class(button)}
      >
        <.dynamic_icon
          :if={button["icon"]}
          name={button["icon"]}
          class="size-5 shrink-0 text-current"
        />
        <span class="truncate">{Map.get(button, "label", "")}</span>
      </a>
    </div>
    """
  end

  attr :item, :map, required: true
  attr :variant, :string, default: "section"

  def media(assigns) do
    assigns =
      assign(assigns,
        src: media_src(assigns.item),
        alt: Map.get(assigns.item, "image_alt", ""),
        icon: Map.get(assigns.item, "icon"),
        href: media_href(assigns.item),
        label: media_label(assigns.item),
        external: Map.get(assigns.item, "media_external") == true
      )

    ~H"""
    <div class="flex w-full items-center justify-center">
      <a
        :if={@href}
        href={@href}
        target={if @external, do: "_blank"}
        rel={if @external, do: "noopener noreferrer"}
        aria-label={@label}
        class={media_shell_class(true)}
      >
        <.media_visual src={@src} alt={@alt} icon={@icon} variant={@variant} />
      </a>
      <div
        :if={!@href}
        class={media_shell_class(false)}
      >
        <.media_visual src={@src} alt={@alt} icon={@icon} variant={@variant} />
      </div>
    </div>
    """
  end

  attr :src, :string, default: nil
  attr :alt, :string, default: ""
  attr :icon, :string, default: nil
  attr :variant, :string, default: "section"

  def media_visual(assigns) do
    ~H"""
    <img
      :if={@src}
      src={@src}
      alt={@alt}
      loading={if(@variant == "hero", do: "eager", else: "lazy")}
      fetchpriority={if(@variant == "hero", do: "high", else: nil)}
      class={media_class(@variant)}
    />
    <div
      :if={!@src && @icon}
      class="grid aspect-square w-full max-w-48 place-items-center rounded-lg border border-base-300/70 bg-base-100/70 text-base-content/70 shadow-sm"
    >
      <.dynamic_icon name={@icon} class="size-16" />
    </div>
    """
  end

  attr :section, :map, required: true

  def section(assigns) do
    ~H"""
    <section class={[
      "flex",
      "items-start",
      section_height_class(@section),
      section_span_class(@section)
    ]}>
      <div class={[
        "grid w-full gap-6 md:gap-8",
        "items-start",
        grid_class(@section, "section")
      ]}>
        <div class={media_order_class(@section)}>
          <.media item={@section} variant="section" />
        </div>
        <div class={[
          "grid gap-4",
          section_text_grid_class(@section),
          text_order_class(@section),
          text_align_class(@section)
        ]}>
          <h2 class="text-2xl font-bold tracking-normal sm:text-3xl">
            {Map.get(@section, "title", "")}
          </h2>
          <div class="text-base leading-relaxed text-base-content/75">
            {rich_text(Map.get(@section, "text", ""))}
          </div>
          <.buttons buttons={Map.get(@section, "buttons", [])} />
        </div>
      </div>
    </section>
    """
  end

  def rich_text(text) when is_binary(text) do
    text
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
    |> then(fn escaped ->
      Regex.replace(@link_pattern, escaped, fn _match, label, href ->
        if safe_href?(href) do
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

  def rich_text(_), do: Phoenix.HTML.raw("")

  defp grid_class(item, variant) do
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

  defp sections_grid_class(columns) when columns in [1, "1", "1x"], do: "md:grid-cols-1"
  defp sections_grid_class(_columns), do: "md:grid-cols-2"

  defp section_span_class(section) do
    case Map.get(section, "width", "1x") do
      value when value in [2, "2", "2x", "full"] -> "md:col-span-2"
      _ -> "md:col-span-1"
    end
  end

  defp section_height_class(section) do
    case section_height(section) do
      value when value in ["compact", "sm", "small"] -> "py-8"
      value when value in ["half", "50", "50%"] -> "min-h-[calc(50dvh-2.5rem)] py-8"
      _ -> "min-h-[calc(100dvh-5rem)] py-12"
    end
  end

  defp section_text_grid_class(section) do
    case section_height(section) do
      value when value in ["compact", "sm", "small"] -> "md:grid-rows-[5rem_6rem_auto]"
      _ -> "md:grid-rows-[5.5rem_6.5rem_auto]"
    end
  end

  defp section_height(section), do: Map.get(section, "height", "full")

  defp sections_with_page_defaults(page) do
    default_height = Map.get(page, "sections_height")

    page
    |> Map.get("sections", [])
    |> case do
      sections when is_list(sections) ->
        Enum.map(sections, fn
          section when is_map(section) ->
            Map.put_new(section, "height", default_height || "full")

          section ->
            section
        end)

      _ ->
        []
    end
  end

  defp media_order_class(item) do
    [
      if(Map.get(item, "image_position_mobile", "top") == "bottom",
        do: "order-2",
        else: "order-1"
      ),
      if(desktop_image_position(item) == "right", do: "md:order-2", else: "md:order-1")
    ]
  end

  defp text_order_class(item) do
    [
      if(Map.get(item, "image_position_mobile", "top") == "bottom",
        do: "order-1",
        else: "order-2"
      ),
      if(desktop_image_position(item) == "right", do: "md:order-1", else: "md:order-2")
    ]
  end

  defp text_align_class(item) do
    case Map.get(item, "text_align", "center") do
      "left" -> "text-left items-start"
      "right" -> "text-right items-end"
      _ -> "text-center items-center"
    end
  end

  defp media_src(item), do: Map.get(item, "image")

  defp media_href(item) do
    case Map.get(item, "media_href") do
      href when is_binary(href) and href != "" -> if safe_href?(href), do: href
      _ -> nil
    end
  end

  defp media_label(item) do
    Map.get(item, "media_label") ||
      Map.get(item, "image_alt") ||
      Map.get(item, "title") ||
      "Open media link"
  end

  defp media_width(item, "hero"), do: Map.get(item, "media_width", "half")
  defp media_width(item, _variant), do: Map.get(item, "media_width", "third")

  defp desktop_image_position(item), do: Map.get(item, "image_position_desktop", "left")

  defp media_class("hero"), do: "block max-h-[58dvh] w-full rounded-lg object-contain"

  defp media_class(_variant),
    do: "block aspect-square max-h-[42dvh] w-full rounded-lg object-contain"

  defp media_shell_class(true) do
    "group flex w-full items-center justify-center transition-transform duration-300 ease-out motion-safe:hover:scale-[1.04] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-primary"
  end

  defp media_shell_class(false) do
    "flex w-full items-center justify-center transition-transform duration-300 ease-out motion-safe:hover:scale-[1.02]"
  end

  defp button_class(button) do
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

  defp valid_button?(%{"href" => href, "label" => label}) do
    is_binary(href) and href != "" and is_binary(label) and label != ""
  end

  defp valid_button?(_button), do: false

  defp presentation_page?(%{"hero" => hero}) when is_map(hero), do: true
  defp presentation_page?(%{"sections" => sections}) when is_list(sections), do: true
  defp presentation_page?(_page), do: false

  defp normalize_path(path) when is_binary(path) do
    path
    |> String.trim()
    |> case do
      "" -> "/"
      value -> if(String.starts_with?(value, "/"), do: value, else: "/" <> value)
    end
    |> String.trim_trailing("/")
    |> case do
      "" -> "/"
      value -> value
    end
  end

  defp normalize_path(_path), do: "/"

  defp safe_href?(href) when is_binary(href) do
    String.starts_with?(href, "/") or String.starts_with?(href, "http://") or
      String.starts_with?(href, "https://") or String.starts_with?(href, "mailto:")
  end

  defp safe_href?(_href), do: false
end
