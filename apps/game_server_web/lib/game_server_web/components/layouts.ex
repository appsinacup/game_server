defmodule GameServerWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use GameServerWeb, :html

  alias GameServer.Theme.JSONConfig

  # Available locales — computed once at compile time from Gettext .po files.
  # The language dropdown is only rendered when there are 2+ locales.
  @known_locales Gettext.known_locales(GameServerWeb.Gettext)

  @locale_labels %{
    "ar" => "العربية",
    "bg" => "български език",
    "cs" => "čeština",
    "da" => "Dansk",
    "de" => "Deutsch",
    "el" => "Ελληνικά",
    "en" => "English",
    "es" => "Español",
    "es_ES" => "Español (España)",
    "fi" => "suomi",
    "fr" => "Français",
    "hu" => "magyar",
    "id" => "Bahasa Indonesia",
    "it" => "Italiano",
    "ja" => "日本語",
    "ko" => "한국어",
    "nl" => "Nederlands",
    "no" => "Norsk",
    "pl" => "Polski",
    "pt" => "Português",
    "pt_BR" => "Português do Brasil",
    "ro" => "Română",
    "ru" => "Русский",
    "sv" => "Svenska",
    "th" => "ไทย",
    "tr" => "Türkçe",
    "uk" => "Українська",
    "vi" => "Tiếng Việt",
    "zh_CN" => "简体中文",
    "zh_TW" => "繁體中文"
  }

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  # Pre-computed icon placement slots — positions, sizes, animation params.
  # Icons are placed along edges (left/right) to avoid overlapping center content.
  @icon_slots [
    %{top: 13, left: 4, size: "size-9 sm:size-13", dur: 8, delay: 0},
    %{top: 12, right: 6, size: "size-8 sm:size-12", dur: 10, delay: 1},
    %{top: 21, left: 13, size: "size-7 sm:size-9", dur: 9, delay: 3.5},
    %{top: 28, right: 14, size: "size-7 sm:size-10", dur: 8, delay: 2.2},
    %{top: 36, left: 3, size: "size-9 sm:size-12", dur: 9, delay: 2},
    %{top: 42, right: 4, size: "size-10 sm:size-14", dur: 11, delay: 0.5},
    %{top: 51, left: 16, size: "size-7 sm:size-9", dur: 10, delay: 1.8},
    %{top: 57, right: 12, size: "size-8 sm:size-11", dur: 11, delay: 0.8},
    %{top: 66, left: 7, size: "size-8 sm:size-10", dur: 7, delay: 3},
    %{top: 72, right: 5, size: "size-10 sm:size-15", dur: 12, delay: 1.5},
    %{top: 81, left: 18, size: "size-8 sm:size-11", dur: 8, delay: 1.2},
    %{top: 88, right: 15, size: "size-7 sm:size-10", dur: 9, delay: 2.8}
  ]

  @doc false
  def icon_placements(icons) when is_list(icons) do
    unique_icons = Enum.uniq(icons)

    if unique_icons == [] do
      []
    else
      unique_icons
      |> Enum.with_index()
      |> Enum.map(fn {icon, index} ->
        slot = Enum.at(@icon_slots, rem(index, length(@icon_slots)))
        Map.put(slot, :name, icon)
      end)
    end
  end

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :current_path, :string, default: nil, doc: "current request path for nav active state"

  attr :flush, :boolean,
    default: false,
    doc: "when true, render content edge-to-edge with no main wrapper, padding, or footer"

  slot :inner_block, required: true

  def app(assigns) do
    # Extract current path for locale switcher
    # For LiveViews, current_path is set via attach_hook in mount_current_scope
    # For controller-rendered pages, we get it from conn
    conn = Map.get(assigns, :conn)

    current_path =
      Map.get(assigns, :current_path) ||
        if(conn, do: conn.request_path, else: "/")

    current_query = if conn, do: conn.query_string, else: ""
    # Locale comes from the LocalePath plug or the OnMount.Locale hook,
    # both of which call Gettext.put_locale before this renders.
    locale = Gettext.get_locale(GameServerWeb.Gettext) || "en"

    provider_theme =
      Map.get(assigns, :theme) || JSONConfig.get_theme(locale) || %{}

    # When THEME_CONFIG is not set, show placeholder text so the user
    # immediately sees what needs configuring.
    missing? = provider_theme == %{}

    theme = %{
      "title" => Map.get(provider_theme, "title") || if(missing?, do: "MISSING_CONFIG"),
      "tagline" => Map.get(provider_theme, "tagline") || if(missing?, do: "Set THEME_CONFIG env"),
      "logo" => Map.get(provider_theme, "logo"),
      "banner" => Map.get(provider_theme, "banner"),
      "css" => Map.get(provider_theme, "css")
    }

    # Extra nav links from theme config JSON ("nav_links" key)
    nav_links = Map.get(provider_theme, "nav_links") || []

    # Extra footer links from theme config JSON ("footer_links" key)
    footer_links = Map.get(provider_theme, "footer_links") || []

    # Background floating icons from theme config JSON
    background_icons = Map.get(provider_theme, "background_icons") || []

    # Site-wide dismissible banner message.
    # The display text comes from the locale-specific config, falling back to
    # the English source text when the locale version is empty/missing.
    # The dismiss fingerprint is ALWAYS based on the English source text so
    # dismissing in any language dismisses everywhere, and changing the English
    # text automatically re-shows the banner.
    en_theme = JSONConfig.get_theme("en") || %{}
    site_message_source = Map.get(en_theme, "site_message", "")

    site_message =
      case Map.get(provider_theme, "site_message", "") do
        "" -> site_message_source
        msg -> msg
      end

    # Simple hash of the English source text — changes when the source changes.
    site_message_hash =
      if site_message_source != "" do
        :erlang.phash2(site_message_source) |> Integer.to_string()
      else
        ""
      end

    notif_unread_count =
      if assigns[:current_scope] do
        GameServer.Notifications.count_unread_notifications(assigns.current_scope.user.id)
      else
        0
      end

    assigns =
      assign(assigns,
        current_path: current_path,
        current_query: current_query,
        locale: locale,
        known_locales: @known_locales,
        theme: theme,
        nav_links: nav_links,
        footer_links: footer_links,
        background_icons: background_icons,
        site_message: site_message,
        site_message_hash: site_message_hash,
        notif_unread_count: notif_unread_count
      )

    ~H"""
    <%!-- Icons float in background at z-[1]; page content is above via normal stacking --%>
    <%= if @background_icons != [] and @current_path not in ["/", "/play"] do %>
      <div class="fixed inset-0 overflow-hidden pointer-events-none z-[1]" aria-hidden="true">
        <%= for placement <- GameServerWeb.Layouts.icon_placements(@background_icons) do %>
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
          <!-- Desktop Navigation -->
          <ul class="hidden xl:flex flex-row px-1 space-x-4 items-center">
            <%= if @current_scope do %>
              <li>
                <.link
                  href={~p"/leaderboards"}
                  class={[
                    "btn",
                    if(String.starts_with?(@current_path, "/leaderboards"),
                      do: "btn-primary",
                      else: "btn-outline"
                    )
                  ]}
                >
                  <.icon name="hero-chart-bar-solid" class="w-4 h-4" />
                  {gettext("Leaderboards")}
                </.link>
              </li>
              <li>
                <.link
                  href={~p"/achievements"}
                  class={[
                    "btn",
                    if(String.starts_with?(@current_path, "/achievements"),
                      do: "btn-primary",
                      else: "btn-outline"
                    )
                  ]}
                >
                  <.icon name="hero-trophy-solid" class="w-4 h-4" />
                  {gettext("Achievements")}
                </.link>
              </li>
              <li>
                <.link
                  href={~p"/groups"}
                  class={[
                    "btn",
                    if(@current_path == "/groups", do: "btn-primary", else: "btn-outline")
                  ]}
                >
                  <.icon name="hero-user-group-solid" class="w-4 h-4" />
                  {gettext("Groups")}
                </.link>
              </li>
              <li class="flex items-center px-0">
                <div class="w-px h-6 bg-base-content/20"></div>
              </li>
              <%= for link <- filtered_nav_links(@nav_links, if(@current_scope && @current_scope.user.is_admin, do: :admin, else: :authenticated), true) do %>
                <li>
                  <a
                    href={link["href"]}
                    target={if(link["external"], do: "_blank", else: nil)}
                    rel={if(link["external"], do: "noopener noreferrer", else: nil)}
                    class={[
                      "btn",
                      if(String.starts_with?(@current_path, link["href"]),
                        do: "btn-primary",
                        else: "btn-outline"
                      )
                    ]}
                  >
                    <.icon :if={link["icon"]} name={link["icon"]} class="w-4 h-4" />
                    {link["label"]}
                  </a>
                </li>
              <% end %>
            <% else %>
              <li>
                <.link
                  href={~p"/leaderboards"}
                  class={[
                    "btn",
                    if(String.starts_with?(@current_path, "/leaderboards"),
                      do: "btn-primary",
                      else: "btn-outline"
                    )
                  ]}
                >
                  <.icon name="hero-chart-bar-solid" class="w-4 h-4" />
                  {gettext("Leaderboards")}
                </.link>
              </li>
              <li>
                <.link
                  href={~p"/achievements"}
                  class={[
                    "btn",
                    if(String.starts_with?(@current_path, "/achievements"),
                      do: "btn-primary",
                      else: "btn-outline"
                    )
                  ]}
                >
                  <.icon name="hero-trophy-solid" class="w-4 h-4" />
                  {gettext("Achievements")}
                </.link>
              </li>
              <li>
                <.link
                  href={~p"/groups"}
                  class={[
                    "btn",
                    if(@current_path == "/groups", do: "btn-primary", else: "btn-outline")
                  ]}
                >
                  <.icon name="hero-user-group-solid" class="w-4 h-4" />
                  {gettext("Groups")}
                </.link>
              </li>
              <li class="flex items-center px-0">
                <div class="w-px h-6 bg-base-content/20"></div>
              </li>
              <%= for link <- filtered_nav_links(@nav_links, :unauthenticated) do %>
                <li>
                  <a
                    href={link["href"]}
                    target={if(link["external"], do: "_blank", else: nil)}
                    rel={if(link["external"], do: "noopener noreferrer", else: nil)}
                    class={[
                      "btn",
                      if(String.starts_with?(@current_path, link["href"]),
                        do: "btn-primary",
                        else: "btn-outline"
                      )
                    ]}
                  >
                    <.icon :if={link["icon"]} name={link["icon"]} class="w-4 h-4" />
                    {link["label"]}
                  </a>
                </li>
              <% end %>
              <li class="flex items-center px-0">
                <div class="w-px h-6 bg-base-content/20"></div>
              </li>
              <li>
                <.link
                  href={~p"/users/log-in"}
                  class={[
                    "btn",
                    if(String.starts_with?(@current_path, "/users/log-in"),
                      do: "btn-primary",
                      else: "btn-outline"
                    )
                  ]}
                >
                  <.icon name="hero-arrow-right-on-rectangle-solid" class="w-4 h-4" />
                  {gettext("Log in")}
                </.link>
              </li>
              <li>
                <.link
                  href={~p"/users/register"}
                  class={[
                    "btn",
                    if(String.starts_with?(@current_path, "/users/register"),
                      do: "btn-primary",
                      else: "btn-outline"
                    )
                  ]}
                >
                  <.icon name="hero-user-plus-solid" class="w-4 h-4" />
                  {gettext("Register")}
                </.link>
              </li>
            <% end %>
            <%= if @current_scope do %>
              <%= for link <- filtered_nav_links(@nav_links, :authenticated) do %>
                <li>
                  <a
                    href={link["href"]}
                    target={if(link["external"], do: "_blank", else: nil)}
                    rel={if(link["external"], do: "noopener noreferrer", else: nil)}
                    class={[
                      "btn",
                      if(String.starts_with?(@current_path, link["href"]),
                        do: "btn-primary",
                        else: "btn-outline"
                      )
                    ]}
                  >
                    <.icon :if={link["icon"]} name={link["icon"]} class="w-4 h-4" />
                    {link["label"]}
                  </a>
                </li>
              <% end %>
            <% end %>
            <li class="flex items-center px-0">
              <div class="w-px h-6 bg-base-content/20"></div>
            </li>
            <%= if @current_scope do %>
              <li>
                <div class="dropdown dropdown-end">
                  <button
                    tabindex="0"
                    class={[
                      "btn gap-1",
                      if(
                        String.starts_with?(@current_path, "/users/settings") or
                          String.starts_with?(@current_path, "/notifications") or
                          String.starts_with?(@current_path, "/chat") or
                          String.starts_with?(@current_path, "/admin"),
                        do: "btn-primary",
                        else: "btn-outline"
                      )
                    ]}
                  >
                    <.icon name="hero-user-circle-solid" class="w-5 h-5" />
                    <span class="max-w-[8rem] truncate">
                      {display_name(@current_scope.user)}
                    </span>
                    <span
                      :if={@notif_unread_count > 0}
                      class="inline-flex items-center justify-center min-w-[1.25rem] h-5 px-1 text-xs font-bold rounded-full bg-error text-error-content"
                    >
                      {@notif_unread_count}
                    </span>
                    <.icon name="hero-chevron-down-solid" class="w-3 h-3" />
                  </button>
                  <ul
                    tabindex="0"
                    class="menu menu-sm dropdown-content mt-2 z-[1] p-2 shadow-lg bg-base-100 rounded-box w-56"
                  >
                    <li>
                      <.link
                        href={~p"/users/settings"}
                        class={[
                          if(String.starts_with?(@current_path, "/users/settings"),
                            do: "active",
                            else: ""
                          )
                        ]}
                      >
                        <.icon name="hero-user-circle-solid" class="w-4 h-4" />
                        {gettext("Account")}
                      </.link>
                    </li>
                    <li>
                      <.link
                        href={~p"/notifications"}
                        class={[
                          if(String.starts_with?(@current_path, "/notifications"),
                            do: "active",
                            else: ""
                          )
                        ]}
                      >
                        <.icon name="hero-bell-solid" class="w-4 h-4" />
                        {gettext("Notifications")}
                        <span
                          :if={@notif_unread_count > 0}
                          class="inline-flex items-center justify-center min-w-[1.25rem] h-5 px-1 text-xs font-bold rounded-full bg-error text-error-content"
                        >
                          {@notif_unread_count}
                        </span>
                      </.link>
                    </li>
                    <li>
                      <.link
                        href={~p"/chat"}
                        class={[
                          if(String.starts_with?(@current_path, "/chat"),
                            do: "active",
                            else: ""
                          )
                        ]}
                      >
                        <.icon name="hero-chat-bubble-left-right-solid" class="w-4 h-4" />
                        {gettext("Chat")}
                      </.link>
                    </li>
                    <%= if @current_scope && @current_scope.user.is_admin do %>
                      <li>
                        <.link
                          href={~p"/admin"}
                          class={[
                            if(String.starts_with?(@current_path, "/admin"),
                              do: "active",
                              else: ""
                            )
                          ]}
                        >
                          <.icon name="hero-cog-6-tooth-solid" class="w-4 h-4" />
                          {gettext("Admin")}
                        </.link>
                      </li>
                    <% end %>
                    <li class="border-t border-base-300 mt-1 pt-1">
                      <.link href={~p"/users/log-out"} method="delete">
                        <.icon name="hero-arrow-left-on-rectangle-solid" class="w-4 h-4" />
                        {gettext("Log out")}
                      </.link>
                    </li>
                  </ul>
                </div>
              </li>
            <% end %>
            <%= if length(@known_locales) > 1 do %>
              <li class="flex items-center px-0">
                <div class="w-px h-6 bg-base-content/20"></div>
              </li>
              <li>
                <.language_dropdown
                  locale={@locale}
                  current_path={@current_path}
                  current_query={@current_query}
                  known_locales={@known_locales}
                  mobile={false}
                />
              </li>
            <% end %>
            <li>
              <.theme_toggle />
            </li>
          </ul>

    <!-- Mobile Navigation -->
          <div class="xl:hidden">
            <div class="dropdown dropdown-end">
              <button tabindex="0" class="btn btn-ghost btn-circle">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M4 6h16M4 12h16M4 18h16"
                  >
                  </path>
                </svg>
              </button>
              <ul
                tabindex="0"
                class="menu menu-sm dropdown-content mt-3 z-[1] p-2 shadow bg-base-100 rounded-box w-80 text-lg"
              >
                <%= if @current_scope do %>
                  <li>
                    <a
                      href={~p"/users/settings"}
                      class={[
                        "btn",
                        if(String.starts_with?(@current_path, "/users/settings"),
                          do: "btn-primary",
                          else: "btn-ghost"
                        )
                      ]}
                    >
                      <.icon name="hero-user-circle-solid" class="w-4 h-4" />
                      {gettext("Account")}
                    </a>
                  </li>
                  <li>
                    <a
                      href={~p"/notifications"}
                      class={[
                        "btn",
                        if(String.starts_with?(@current_path, "/notifications"),
                          do: "btn-primary",
                          else: "btn-ghost"
                        )
                      ]}
                    >
                      <.icon name="hero-bell-solid" class="w-4 h-4" />
                      {gettext("Notifications")}
                      <span
                        :if={@notif_unread_count > 0}
                        class="ml-0.5 inline-flex items-center justify-center min-w-[1.25rem] h-5 px-1 text-xs font-bold rounded-full bg-error text-error-content"
                      >
                        {@notif_unread_count}
                      </span>
                    </a>
                  </li>
                  <li>
                    <a
                      href={~p"/chat"}
                      class={[
                        "btn",
                        if(String.starts_with?(@current_path, "/chat"),
                          do: "btn-primary",
                          else: "btn-ghost"
                        )
                      ]}
                    >
                      <.icon name="hero-chat-bubble-left-right-solid" class="w-4 h-4" />
                      {gettext("Chat")}
                    </a>
                  </li>
                  <%= if @current_scope && @current_scope.user.is_admin do %>
                    <li>
                      <a
                        href={~p"/admin"}
                        class={[
                          "btn",
                          if(String.starts_with?(@current_path, "/admin"),
                            do: "btn-primary",
                            else: "btn-ghost"
                          )
                        ]}
                      >
                        <.icon name="hero-cog-6-tooth-solid" class="w-4 h-4" />
                        {gettext("Admin")}
                      </a>
                    </li>
                  <% end %>
                  <li class="mt-3">
                    <a
                      href={~p"/leaderboards"}
                      class={[
                        "btn",
                        if(String.starts_with?(@current_path, "/leaderboards"),
                          do: "btn-primary",
                          else: "btn-ghost"
                        )
                      ]}
                    >
                      <.icon name="hero-chart-bar-solid" class="w-4 h-4" />
                      {gettext("Leaderboards")}
                    </a>
                  </li>
                  <li>
                    <a
                      href={~p"/achievements"}
                      class={[
                        "btn",
                        if(String.starts_with?(@current_path, "/achievements"),
                          do: "btn-primary",
                          else: "btn-ghost"
                        )
                      ]}
                    >
                      <.icon name="hero-trophy-solid" class="w-4 h-4" />
                      {gettext("Achievements")}
                    </a>
                  </li>
                  <li>
                    <a
                      href={~p"/groups"}
                      class={[
                        "btn",
                        if(@current_path == "/groups", do: "btn-primary", else: "btn-ghost")
                      ]}
                    >
                      <.icon name="hero-user-group-solid" class="w-4 h-4" />
                      {gettext("Groups")}
                    </a>
                  </li>
                  <%= for link <- filtered_nav_links(@nav_links, if(@current_scope && @current_scope.user.is_admin, do: :admin, else: :authenticated), true) do %>
                    <li>
                      <a
                        href={link["href"]}
                        target={if(link["external"], do: "_blank", else: nil)}
                        rel={if(link["external"], do: "noopener noreferrer", else: nil)}
                        class={[
                          "btn",
                          if(String.starts_with?(@current_path, link["href"]),
                            do: "btn-primary",
                            else: "btn-ghost"
                          )
                        ]}
                      >
                        <.icon :if={link["icon"]} name={link["icon"]} class="w-4 h-4" />
                        {link["label"]}
                      </a>
                    </li>
                  <% end %>
                <% else %>
                  <li>
                    <a
                      href={~p"/users/log-in"}
                      class={[
                        "btn",
                        if(String.starts_with?(@current_path, "/users/log-in"),
                          do: "btn-primary",
                          else: "btn-ghost"
                        )
                      ]}
                    >
                      <.icon name="hero-arrow-right-on-rectangle-solid" class="w-4 h-4" />
                      {gettext("Log in")}
                    </a>
                  </li>
                  <li>
                    <a
                      href={~p"/users/register"}
                      class={[
                        "btn",
                        if(String.starts_with?(@current_path, "/users/register"),
                          do: "btn-primary",
                          else: "btn-ghost"
                        )
                      ]}
                    >
                      <.icon name="hero-user-plus-solid" class="w-4 h-4" />
                      {gettext("Register")}
                    </a>
                  </li>
                  <li>
                    <a
                      href={~p"/leaderboards"}
                      class={[
                        "btn",
                        if(String.starts_with?(@current_path, "/leaderboards"),
                          do: "btn-primary",
                          else: "btn-ghost"
                        )
                      ]}
                    >
                      <.icon name="hero-chart-bar-solid" class="w-4 h-4" />
                      {gettext("Leaderboards")}
                    </a>
                  </li>
                  <li>
                    <a
                      href={~p"/achievements"}
                      class={[
                        "btn",
                        if(String.starts_with?(@current_path, "/achievements"),
                          do: "btn-primary",
                          else: "btn-ghost"
                        )
                      ]}
                    >
                      <.icon name="hero-trophy-solid" class="w-4 h-4" />
                      {gettext("Achievements")}
                    </a>
                  </li>
                  <li>
                    <a
                      href={~p"/groups"}
                      class={[
                        "btn",
                        if(@current_path == "/groups", do: "btn-primary", else: "btn-ghost")
                      ]}
                    >
                      <.icon name="hero-user-group-solid" class="w-4 h-4" />
                      {gettext("Groups")}
                    </a>
                  </li>
                <% end %>
                <%= for link <- filtered_nav_links(@nav_links, if(@current_scope, do: :authenticated, else: :unauthenticated)) do %>
                  <li>
                    <a
                      href={link["href"]}
                      target={if(link["external"], do: "_blank", else: nil)}
                      rel={if(link["external"], do: "noopener noreferrer", else: nil)}
                      class={[
                        "btn",
                        if(String.starts_with?(@current_path, link["href"]),
                          do: "btn-primary",
                          else: "btn-ghost"
                        )
                      ]}
                    >
                      <.icon :if={link["icon"]} name={link["icon"]} class="w-4 h-4" />
                      {link["label"]}
                    </a>
                  </li>
                <% end %>
                <%= if @current_scope do %>
                  <div class="mt-3"></div>
                <% end %>
                <%= if length(@known_locales) > 1 do %>
                  <li class="[&>*]:!p-0 [&>*]:!bg-transparent mt-3">
                    <.language_dropdown
                      locale={@locale}
                      current_path={@current_path}
                      current_query={@current_query}
                      known_locales={@known_locales}
                      mobile={true}
                    />
                  </li>
                <% end %>
                <%= if @current_scope do %>
                  <li class="mt-3">
                    <.link href={~p"/users/log-out"} method="delete" class="btn btn-ghost">
                      <.icon name="hero-arrow-left-on-rectangle-solid" class="w-4 h-4" />
                      {gettext("Log out")}
                    </.link>
                  </li>
                <% end %>
                <li class="mt-2">
                  <div class="flex justify-center">
                    <.theme_toggle />
                  </div>
                </li>
              </ul>
            </div>
          </div>
        </div>
      </header>

      <%!-- Language modal rendered outside drawer for proper viewport positioning --%>
      <%= if length(@known_locales) > 1 do %>
        <.language_modal
          locale={@locale}
          current_path={@current_path}
          current_query={@current_query}
          known_locales={@known_locales}
        />
      <% end %>

      <%!-- Site-wide dismissible banner --%>
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
            aria-label={gettext("Dismiss")}
          >
            <.icon name="hero-x-mark" class="w-3.5 h-3.5" />
          </button>
        </div>
      <% end %>

      <%= if @flush do %>
        <div class="flex-1 min-h-0 relative">
          {render_slot(@inner_block)}
        </div>
        <.flash_group flash={@flash} />
      <% else %>
        <main class="relative z-[2] px-4 py-4 sm:px-6 lg:px-8 flex-1">
          <div class="mx-auto max-w-2xl md:max-w-3xl lg:max-w-4xl xl:max-w-6xl space-y-4">
            {render_slot(@inner_block)}
          </div>
        </main>

        <.flash_group flash={@flash} />
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
            <span class="text-xs opacity-60">v{app_version()}</span>
          </div>
        </footer>
      <% end %>
    </div>
    """
  end

  defp language_dropdown(assigns) do
    locale = assigns.locale
    current_path = assigns.current_path || "/"
    current_query = assigns.current_query || ""
    known_locales = assigns.known_locales

    base_path = strip_locale_prefix(current_path, known_locales)

    query_suffix =
      if is_binary(current_query) and current_query != "", do: "?" <> current_query, else: ""

    locale_links =
      Enum.map(known_locales, fn loc ->
        # All locale links use /<locale>/path format — the LocalePath plug
        # stores the choice in session and redirects to the clean URL.
        href =
          if(base_path == "/", do: "/" <> loc, else: "/" <> loc <> base_path) <> query_suffix

        %{locale: loc, label: Map.get(@locale_labels, loc, loc), href: href}
      end)

    assigns =
      assign(assigns,
        locale: locale,
        locale_links: locale_links,
        label: Map.get(@locale_labels, locale, locale),
        mobile: Map.get(assigns, :mobile, false)
      )

    ~H"""
    <%= if @mobile do %>
      <%!-- Mobile: label triggers the lang-modal rendered outside the drawer --%>
      <label for="lang-modal" class="btn btn-ghost btn-sm w-full relative cursor-pointer">
        <.icon name="hero-globe-alt-solid" class="w-4 h-4" />
        {@label}
        <.icon name="hero-chevron-down-solid" class="w-3 h-3 absolute right-3" />
      </label>
    <% else %>
      <%!-- Desktop: dropdown --%>
      <details class="dropdown dropdown-end">
        <summary class="btn btn-outline list-none">
          <.icon name="hero-globe-alt-solid" class="w-4 h-4" />
          {@label}
          <.icon name="hero-chevron-down-solid" class="w-3 h-3" />
        </summary>
        <ul class="dropdown-content mt-2 p-2 shadow bg-base-100 rounded-box overflow-y-auto grid grid-cols-3 gap-0.5 w-[28rem] z-[1] max-h-[60vh]">
          <%= for link <- @locale_links do %>
            <li class="list-none">
              <a
                href={link.href}
                class={[
                  "block px-2 py-1.5 rounded text-sm whitespace-nowrap hover:bg-base-200 transition-colors text-center",
                  link.locale == @locale && "bg-primary/10 font-semibold text-primary"
                ]}
              >
                {link.label}
              </a>
            </li>
          <% end %>
        </ul>
      </details>
    <% end %>
    """
  end

  def locale_labels, do: @locale_labels

  defp language_modal(assigns) do
    locale = assigns.locale
    current_path = assigns.current_path || "/"
    current_query = assigns.current_query || ""
    known_locales = assigns.known_locales

    base_path = strip_locale_prefix(current_path, known_locales)

    query_suffix =
      if is_binary(current_query) and current_query != "", do: "?" <> current_query, else: ""

    locale_links =
      Enum.map(known_locales, fn loc ->
        href =
          if(base_path == "/", do: "/" <> loc, else: "/" <> loc <> base_path) <> query_suffix

        %{locale: loc, label: Map.get(@locale_labels, loc, loc), href: href}
      end)

    label = Map.get(@locale_labels, locale, locale)

    assigns = assign(assigns, locale: locale, locale_links: locale_links, label: label)

    ~H"""
    <input type="checkbox" id="lang-modal" class="modal-toggle" />
    <div class="modal modal-bottom sm:modal-middle z-[100]" role="dialog">
      <div class="modal-box max-w-2xl">
        <label for="lang-modal" class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2">
          ✕
        </label>
        <h3 class="font-bold text-lg mb-4 flex items-center gap-2">
          <.icon name="hero-globe-alt-solid" class="w-5 h-5" />
          {@label}
        </h3>
        <div class="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-5 gap-1">
          <%= for link <- @locale_links do %>
            <a
              href={link.href}
              class={[
                "block px-2 py-2 rounded text-sm whitespace-nowrap hover:bg-base-200 transition-colors text-center",
                link.locale == @locale && "bg-primary/10 font-semibold text-primary"
              ]}
            >
              {link.label}
            </a>
          <% end %>
        </div>
      </div>
      <label class="modal-backdrop" for="lang-modal">Close</label>
    </div>
    """
  end

  def strip_locale_prefix(path, known_locales) when is_binary(path) do
    segments = String.split(path, "/", trim: true)

    case segments do
      [first | rest] when is_list(rest) ->
        if first in known_locales do
          case rest do
            [] -> "/"
            _ -> "/" <> Enum.join(rest, "/")
          end
        else
          if String.starts_with?(path, "/"), do: path, else: "/"
        end

      _ ->
        if String.starts_with?(path, "/"), do: path, else: "/"
    end
  end

  def strip_locale_prefix(_, _known_locales), do: "/"

  @app_version_fallback Mix.Project.config()[:version] || "1.0.0"

  defp app_version do
    # Prefer CI-injected APP_VERSION when present, otherwise fall back to the
    # compiled application vsn or the Mix project version.
    case System.get_env("APP_VERSION") || Application.spec(:game_server, :vsn) do
      nil -> @app_version_fallback
      vsn -> to_string(vsn)
    end
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("Loading...")}
        phx-disconnected={JS.dispatch("gs:lv-disconnected")}
        phx-connected={JS.dispatch("gs:lv-connected")}
        phx-hook="ReconnectNotice"
        data-delay-ms="5000"
        hidden
      >
        {gettext("Loading...")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Loading...")}
        phx-disconnected={JS.dispatch("gs:lv-disconnected")}
        phx-connected={JS.dispatch("gs:lv-connected")}
        phx-hook="ReconnectNotice"
        data-delay-ms="5000"
        hidden
      >
        {gettext("Loading...")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/2 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=dark]_&]:left-1/2 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/2"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/2"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Extra nav links from theme config JSON
  # ---------------------------------------------------------------------------

  # Filters nav_links from the theme config by auth level.
  #
  # Each nav link in the JSON is an object with:
  # - `"label"` (required) — display text
  # - `"href"` (required) — URL (internal like "/my-page" or external like "https://...")
  # - `"auth"` (optional) — `"any"` (default), `"authenticated"`, or `"admin"`
  # - `"external"` (optional) — boolean, opens in new tab when true
  #
  # The `exact?` parameter controls whether `"any"` links are included:
  # - `false` (default): includes `"any"` links — use in the shared section
  #   that renders after the if/else auth block
  # - `true`: excludes `"any"` links — use inside the authenticated-only
  #   block to avoid rendering `"any"` links twice
  defp display_name(user) do
    cond do
      is_binary(user.display_name) and user.display_name != "" -> user.display_name
      is_binary(user.email) and user.email != "" -> user.email
      true -> "User"
    end
  end

  defp filtered_nav_links(nav_links, auth_level, exact? \\ false) do
    Enum.filter(nav_links, fn link ->
      required = Map.get(link, "auth", "any")

      case {required, auth_level, exact?} do
        # "any" links only render in the shared (non-exact) section
        {"any", _, false} -> true
        {"any", _, true} -> false
        {"authenticated", :authenticated, _} -> true
        {"authenticated", :admin, _} -> true
        {"admin", :admin, _} -> true
        _ -> false
      end
    end)
  end

end
