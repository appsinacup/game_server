defmodule GamendWeb.HostLayoutShell do
  @moduledoc false

  use GamendWeb, :html

  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :current_path, :string, default: nil
  attr :current_query, :string, default: ""
  attr :flush, :boolean, default: false
  attr :theme, :map, required: true
  attr :navigation, :map, default: %{}
  attr :footer, :map, default: %{}
  attr :background_icons, :list, default: []
  attr :notif_unread_count, :integer, default: 0
  attr :locale, :string, required: true
  attr :known_locales, :list, default: []
  attr :breadcrumbs, :list, default: []

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <%!-- First focusable element on every page: invisible until it receives
          keyboard focus, then lets the reader jump past the navbar straight
          to the main landmark. --%>
    <a
      href="#main-content"
      class="sr-only focus:not-sr-only focus:fixed focus:start-4 focus:top-4 focus:z-[200] focus:rounded-lg focus:bg-primary focus:px-4 focus:py-2 focus:font-semibold focus:text-primary-content focus:shadow-lg"
    >
      {GamendWeb.HostLayouts.translate("Skip to content")}
    </a>
    <.background_icons background_icons={@background_icons} />
    <div class={["flex flex-col", if(@flush, do: "h-dvh overflow-hidden relative", else: "min-h-dvh")]}>
      <div
        :if={@flush}
        id="navbar-autohide"
        phx-hook="NavbarAutohide"
        data-target="main-navbar"
        class="hidden"
      />
      <header
        id="main-navbar"
        phx-hook="NavbarDropdowns"
        class={[
          "navbar z-50",
          if(@flush,
            do: "absolute top-0 start-0 end-0 ps-4 sm:ps-6 lg:ps-8 pe-14",
            else: "sticky top-0 shrink-0 px-4 sm:px-6 lg:px-8"
          ),
          if(@flush,
            do: "bg-base-100/90 backdrop-blur-md",
            else: "bg-transparent backdrop-blur-md border-base-200/20"
          )
        ]}
      >
        <% title = Map.get(@theme, "title") %>
        <% tagline = Map.get(@theme, "tagline") %>
        <% logo = Map.get(@theme, "logo") %>
        <div class="flex-1">
          <a
            href={GamendWeb.HostLayouts.localized_href(~p"/", @locale)}
            class="flex-1 flex w-fit items-center gap-2"
          >
            <%!-- Same rule as `CoreComponents.flag/1`: this is on screen at
                  load on every page, so it is fetched with the HTML, decoded
                  with the first frame and prioritised over the ~45 flags the
                  locale dropdown queues behind it. Left async it painted a
                  beat after the title beside it on every refresh.

                  `alt=""` because it is decorative: the site name is the text
                  right beside it, so an alt repeating it makes a screen reader
                  say it twice — `image-redundant-alt`. The link is named by
                  that text. --%>
            <img
              src={GamendWeb.SRI.versioned_path(logo) || logo}
              width="36"
              height="36"
              alt=""
              loading="eager"
              decoding="sync"
              fetchpriority="high"
            />
            <span class="text-lg font-bold">{title}</span>
            <%= if tagline && tagline != "" do %>
              <span class="text-sm opacity-80 ms-1 hidden xl:inline">{tagline}</span>
            <% end %>
          </a>
        </div>
        <%!-- The language picker sits outside both navs: one button in the bar
              at every width, rather than a dropdown up here and a different
              control buried in the phone menu. --%>
        <div class="flex-none flex items-center gap-2">
          <GamendWeb.HostLayoutNavigation.desktop_nav
            current_scope={@current_scope}
            current_path={@current_path}
            current_query={@current_query}
            navigation={@navigation}
            notif_unread_count={@notif_unread_count}
            locale={@locale}
            known_locales={@known_locales}
          />

          <GamendWeb.HostLayoutNavigation.language_dropdown
            :if={length(@known_locales) > 1}
            locale={@locale}
            current_path={@current_path}
            current_query={@current_query}
            known_locales={@known_locales}
          />

          <GamendWeb.HostLayoutNavigation.mobile_nav
            current_scope={@current_scope}
            current_path={@current_path}
            current_query={@current_query}
            navigation={@navigation}
            notif_unread_count={@notif_unread_count}
            locale={@locale}
            known_locales={@known_locales}
          />
        </div>
      </header>

      <%!-- Outside `<header>` on purpose: the sheet is `position: fixed`, and
            the header's `backdrop-blur` makes it a containing block for fixed
            descendants — inside it, the sheet pins to the header's box and
            opens above the fold instead of along the bottom of the screen. --%>
      <GamendWeb.HostLayoutNavigation.language_modal
        :if={length(@known_locales) > 1}
        locale={@locale}
        current_path={@current_path}
        current_query={@current_query}
        known_locales={@known_locales}
      />

      <%= if @flush do %>
        <div id="main-content" class="flex-1 min-h-0 relative">
          {render_slot(@inner_block)}
        </div>
        <GamendWeb.HostLayouts.flash_group flash={@flash} />
      <% else %>
        <main id="main-content" class="relative z-[2] px-4 py-4 sm:px-6 lg:px-8 flex-1">
          <%!-- The trail sits above the content and pushes it down, which
                knocks a full-height hero off centre. `--breadcrumb-offset` is
                the trail's own height plus the stack gap; a hero subtracts it
                from `100dvh` so its first screen still ends at the fold. --%>
          <div
            class="mx-auto max-w-2xl md:max-w-3xl lg:max-w-4xl xl:max-w-6xl space-y-4"
            style={if length(@breadcrumbs) > 1, do: "--breadcrumb-offset: 2.25rem"}
          >
            <.breadcrumbs trail={@breadcrumbs} />
            <%!-- The page's own frame, applied here so no page has to know it:
                  one gap between blocks and one landing before the footer,
                  whichever repo wrote the page. A page that set its own `py-6`
                  used to sit lower than the page beside it in the nav, and
                  `pb-10` was on six pages and off the rest. `page-stack` is the
                  hook a host restyles; the utilities are the default. --%>
            <div class="page-stack space-y-6 pb-10">
              {render_slot(@inner_block)}
            </div>
          </div>
        </main>

        <GamendWeb.HostLayouts.flash_group flash={@flash} />
        <footer class="px-4 py-8 sm:px-6 lg:px-8 text-sm text-base-content/70">
          <div class="mx-auto grid max-w-2xl gap-6 md:max-w-3xl md:grid-cols-2 lg:max-w-4xl xl:max-w-6xl xl:grid-cols-4">
            <%!-- The column label is a `<p>`, not an `<h2>`: these name link
                  groups, not document sections, and as headings they were half
                  of every page's H2s — an outline where "Privacy & Terms" ranks
                  beside the page's actual subject. `aria-label` keeps the
                  grouping announced, which is what the heading was really
                  doing. --%>
            <div :for={section <- footer_sections(@footer)} class="space-y-2">
              <p class="text-sm font-semibold text-base-content">
                {section["title"]}
              </p>
              <nav aria-label={section["title"]} class="flex flex-col gap-1.5">
                <a
                  :for={link <- visible_footer_links(section, @current_scope)}
                  href={link["href"]}
                  target={if(link["external"], do: "_blank", else: nil)}
                  rel={if(link["external"], do: "noopener noreferrer", else: nil)}
                  class="w-fit hover:text-base-content hover:underline"
                >
                  {link["label"]}
                </a>
              </nav>
            </div>
          </div>
        </footer>
      <% end %>
    </div>
    """
  end

  attr :trail, :list, default: []

  @doc """
  The breadcrumb trail, as `{label, path}` pairs — the last one is the current
  page and carries a `nil` path.

  Renders nothing for a bare `[{"Home", nil}]`: a trail with no ancestors tells
  the reader nothing, and Google ignores a single-item `BreadcrumbList`.
  """
  def breadcrumbs(assigns) do
    ~H"""
    <nav :if={length(@trail) > 1} aria-label="Breadcrumb" class="text-sm text-base-content/60">
      <ol class="flex flex-wrap items-center gap-2">
        <li :for={{{label, path}, index} <- Enum.with_index(@trail)} class="flex items-center gap-2">
          <span :if={index > 0} aria-hidden="true">/</span>
          <.link :if={path} href={path} class="hover:text-primary transition-colors">
            {label}
          </.link>
          <span :if={is_nil(path)} aria-current="page" class="text-base-content/90">{label}</span>
        </li>
      </ol>
    </nav>
    """
  end

  defp footer_sections(%{"sections" => sections}) when is_list(sections), do: sections
  defp footer_sections(_footer), do: []

  # A footer link obeys the same `"auth"` rule as the nav: /store is behind
  # `require_authenticated_user`, so advertising it to a signed-out visitor
  # just sends them to an error.
  defp visible_footer_links(section, current_scope) do
    section
    |> Map.get("links", [])
    |> Enum.filter(&GamendWeb.HostLayoutNavigation.entry_visible?(&1, current_scope))
  end

  attr :background_icons, :list, default: []

  @doc """
  The shell's decorative icon layer.

  Which pages get one is decided in `GamendWeb.HostLayouts`: it hands over an
  empty list for pages that paint their own.
  """
  def background_icons(assigns) do
    ~H"""
    <%= if @background_icons != [] do %>
      <div class="fixed inset-0 overflow-hidden pointer-events-none z-[1]" aria-hidden="true">
        <%= for placement <- GamendWeb.HostLayouts.icon_placements(@background_icons) do %>
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
    <% end %>
    """
  end
end
