defmodule GameServerWeb.HostLayoutShell do
  @moduledoc false

  use GameServerWeb, :html

  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :current_path, :string, default: nil
  attr :current_query, :string, default: ""
  attr :flush, :boolean, default: false
  attr :theme, :map, required: true
  attr :navigation, :map, default: %{}
  attr :footer_links, :list, default: []
  attr :background_icons, :list, default: []
  attr :site_message, :string, default: ""
  attr :site_message_hash, :string, default: ""
  attr :notif_unread_count, :integer, default: 0
  attr :locale, :string, required: true
  attr :known_locales, :list, default: []
  attr :app_version, :string, required: true

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <.background_icons background_icons={@background_icons} current_path={@current_path} />
    <div class={["flex flex-col", if(@flush, do: "h-dvh overflow-hidden relative", else: "min-h-dvh")]}>
      <div
        :if={@flush}
        id="navbar-autohide"
        phx-hook="NavbarAutohide"
        data-autohide-delay="5000"
        data-target="main-navbar"
        class="hidden"
      />
      <header
        id="main-navbar"
        class={[
          "navbar px-4 sm:px-6 lg:px-8 z-50",
          if(@flush,
            do: "absolute top-0 left-0 right-0",
            else: "sticky top-0 shrink-0"
          ),
          if(@flush,
            do: "bg-base-100/90 backdrop-blur-md",
            else: "bg-transparent backdrop-blur-md border-base-200/20"
          )
        ]}
      >
        <% title = Map.get(@theme, "title") %>
        <% tagline = Map.get(@theme, "tagline") %>
        <div class="flex-1">
          <a href={~p"/"} class="flex-1 flex w-fit items-center gap-2">
            <img src={Map.get(@theme, "logo")} width="36" height="36" alt={title} />
            <span class="text-lg font-bold">{title}</span>
            <%= if tagline && tagline != "" do %>
              <span class="text-sm opacity-80 ml-1 hidden xl:inline">{tagline}</span>
            <% end %>
          </a>
        </div>
        <div class="flex-none">
          <GameServerWeb.HostLayoutNavigation.desktop_nav
            current_scope={@current_scope}
            current_path={@current_path}
            current_query={@current_query}
            navigation={@navigation}
            notif_unread_count={@notif_unread_count}
            locale={@locale}
            known_locales={@known_locales}
          />

          <GameServerWeb.HostLayoutNavigation.mobile_nav
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

      <GameServerWeb.HostLayoutNavigation.language_modal
        :if={length(@known_locales) > 1}
        locale={@locale}
        current_path={@current_path}
        current_query={@current_query}
        known_locales={@known_locales}
      />

      <.site_banner site_message={@site_message} site_message_hash={@site_message_hash} />

      <%= if @flush do %>
        <div class="flex-1 min-h-0 relative">
          {render_slot(@inner_block)}
        </div>
        <GameServerWeb.HostLayouts.flash_group flash={@flash} />
      <% else %>
        <main class="relative z-[2] px-4 py-4 sm:px-6 lg:px-8 flex-1">
          <div class="mx-auto max-w-2xl md:max-w-3xl lg:max-w-4xl xl:max-w-6xl space-y-4">
            {render_slot(@inner_block)}
          </div>
        </main>

        <GameServerWeb.HostLayouts.flash_group flash={@flash} />
        <footer class="px-4 py-6 sm:px-6 lg:px-8 text-center text-sm text-base-content/70">
          <div class="mx-auto max-w-2xl md:max-w-3xl lg:max-w-4xl xl:max-w-6xl flex flex-wrap justify-center gap-x-4 gap-y-1">
            <%= for link <- @footer_links do %>
              <a
                href={link["href"]}
                target={if(link["external"], do: "_blank", else: nil)}
                rel={if(link["external"], do: "noopener noreferrer", else: nil)}
                class="hover:underline"
              >
                {link["label"]}
              </a>
            <% end %>
            <span class="text-xs opacity-60">v{@app_version}</span>
          </div>
        </footer>
      <% end %>
    </div>
    """
  end

  attr :background_icons, :list, default: []
  attr :current_path, :string, default: nil

  def background_icons(assigns) do
    ~H"""
    <%= if @background_icons != [] and @current_path not in ["/", "/play"] do %>
      <div class="fixed inset-0 overflow-hidden pointer-events-none z-[1]" aria-hidden="true">
        <%= for placement <- GameServerWeb.HostLayouts.icon_placements(@background_icons) do %>
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

  attr :site_message, :string, default: ""
  attr :site_message_hash, :string, default: ""

  def site_banner(assigns) do
    ~H"""
    <%= if @site_message != "" do %>
      <div
        id="site-banner"
        phx-hook="SiteBanner"
        data-message-hash={@site_message_hash}
        class="hidden relative z-40 bg-base-200/60 backdrop-blur-sm text-base-content/70 px-4 py-1.5 text-center text-xs transition-all duration-300 border-b border-base-300/40"
      >
        <span>{@site_message}</span>
        <button
          type="button"
          data-dismiss-banner
          class="absolute right-3 top-1/2 -translate-y-1/2 opacity-40 hover:opacity-80 transition-opacity cursor-pointer"
          aria-label={GameServerWeb.HostLayouts.translate("Dismiss")}
        >
          <.icon name="hero-x-mark" class="w-3.5 h-3.5" />
        </button>
      </div>
    <% end %>
    """
  end
end
