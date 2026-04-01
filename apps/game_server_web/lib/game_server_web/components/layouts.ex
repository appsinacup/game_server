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
    "en" => "English",
    "es" => "Español"
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
      @icon_slots
      |> Enum.with_index()
      |> Enum.map(fn {slot, idx} ->
        icon_name = Enum.at(unique_icons, rem(idx, length(unique_icons)))
        Map.put(slot, :name, icon_name)
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
    <div class={["flex flex-col", if(@flush, do: "h-dvh overflow-hidden", else: "")]}>
      <header class={[
        "navbar px-4 sm:px-6 lg:px-8 z-50 shrink-0",
        if(!@flush, do: "sticky top-0", else: ""),
        "bg-transparent backdrop-blur-md border-base-200/20"
      ]}>
        <% title = Map.get(@theme, "title") %>
        <% tagline = Map.get(@theme, "tagline") %>
        <div class="flex-1">
          <a href={~p"/"} class="flex-1 flex w-fit items-center gap-2">
            <img src={Map.get(@theme, "logo")} width="36" alt={title} />
            <span class="text-lg font-bold">{title}</span>
            <%= if tagline && tagline != "" do %>
              <span class="text-sm opacity-80 ml-1 hidden lg:inline">: {tagline}</span>
            <% end %>
          </a>
        </div>
        <div class="flex-none">
          <!-- Desktop Navigation -->
          <ul class="hidden lg:flex flex-row px-1 space-x-4 items-center">
            <%= if @current_scope do %>
              <li>
                <.link
                  href={~p"/users/settings"}
                  class={[
                    "btn",
                    if(String.starts_with?(@current_path, "/users/settings"),
                      do: "btn-primary",
                      else: "btn-outline"
                    )
                  ]}
                >
                  {gettext("Account")}
                </.link>
              </li>
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
                  {gettext("Groups")}
                </.link>
              </li>
              <li>
                <.link
                  href={~p"/notifications"}
                  class={[
                    "btn",
                    if(String.starts_with?(@current_path, "/notifications"),
                      do: "btn-primary",
                      else: "btn-outline"
                    )
                  ]}
                >
                  {gettext("Notifications")}
                  <span
                    :if={@notif_unread_count > 0}
                    class="ml-0.5 inline-flex items-center justify-center min-w-[1.25rem] h-5 px-1 text-xs font-bold rounded-full bg-error text-error-content"
                  >
                    {@notif_unread_count}
                  </span>
                </.link>
              </li>
              <li>
                <.link
                  href={~p"/chat"}
                  class={[
                    "btn",
                    if(String.starts_with?(@current_path, "/chat"),
                      do: "btn-primary",
                      else: "btn-outline"
                    )
                  ]}
                >
                  {gettext("Chat")}
                </.link>
              </li>
              <%= if @current_scope && @current_scope.user.is_admin do %>
                <li>
                  <.link
                    href={~p"/admin"}
                    class={[
                      "btn",
                      if(String.starts_with?(@current_path, "/admin"),
                        do: "btn-primary",
                        else: "btn-outline"
                      )
                    ]}
                  >
                    {gettext("Admin")}
                  </.link>
                </li>
                <li>
                  <.link
                    href={~p"/lobbies"}
                    class={[
                      "btn",
                      if(String.starts_with?(@current_path, "/lobbies"),
                        do: "btn-primary",
                        else: "btn-outline"
                      )
                    ]}
                  >
                    {gettext("Lobbies")}
                  </.link>
                </li>
              <% end %>
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
                    {link["label"]}
                  </a>
                </li>
              <% end %>
              <li>
                <.link href={~p"/users/log-out"} method="delete" class="btn btn-outline">
                  {gettext("Log out")}
                </.link>
              </li>
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
                  {gettext("Groups")}
                </.link>
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
                  {gettext("Register")}
                </.link>
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
                      else: "btn-outline"
                    )
                  ]}
                >
                  {link["label"]}
                </a>
              </li>
            <% end %>
            <%= if length(@known_locales) > 1 do %>
              <li>
                <.language_dropdown
                  locale={@locale}
                  current_path={@current_path}
                  current_query={@current_query}
                  known_locales={@known_locales}
                />
              </li>
            <% end %>
            <li>
              <.theme_toggle />
            </li>
          </ul>

    <!-- Mobile Navigation -->
          <div class="lg:hidden">
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
                          else: "btn-outline"
                        )
                      ]}
                    >
                      {gettext("Account")}
                    </a>
                  </li>
                  <li>
                    <a
                      href={~p"/leaderboards"}
                      class={[
                        "btn",
                        if(String.starts_with?(@current_path, "/leaderboards"),
                          do: "btn-primary",
                          else: "btn-outline"
                        )
                      ]}
                    >
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
                          else: "btn-outline"
                        )
                      ]}
                    >
                      {gettext("Achievements")}
                    </a>
                  </li>
                  <li>
                    <a
                      href={~p"/groups"}
                      class={[
                        "btn",
                        if(@current_path == "/groups", do: "btn-primary", else: "btn-outline")
                      ]}
                    >
                      {gettext("Groups")}
                    </a>
                  </li>
                  <li>
                    <a
                      href={~p"/notifications"}
                      class={[
                        "btn",
                        if(String.starts_with?(@current_path, "/notifications"),
                          do: "btn-primary",
                          else: "btn-outline"
                        )
                      ]}
                    >
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
                          else: "btn-outline"
                        )
                      ]}
                    >
                      {gettext("Chat")}
                    </a>
                  </li>
                  <%= if @current_scope && @current_scope.user.is_admin do %>
                    <li>
                      <a
                        href={~p"/lobbies"}
                        class={[
                          "btn",
                          if(String.starts_with?(@current_path, "/lobbies"),
                            do: "btn-primary",
                            else: "btn-outline"
                          )
                        ]}
                      >
                        {gettext("Lobbies")}
                      </a>
                    </li>
                    <li>
                      <a
                        href={~p"/admin"}
                        class={[
                          "btn",
                          if(String.starts_with?(@current_path, "/admin"),
                            do: "btn-primary",
                            else: "btn-outline"
                          )
                        ]}
                      >
                        {gettext("Admin")}
                      </a>
                    </li>
                  <% end %>
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
                        {link["label"]}
                      </a>
                    </li>
                  <% end %>
                  <li>
                    <.link href={~p"/users/log-out"} method="delete" class="btn btn-outline">
                      {gettext("Log out")}
                    </.link>
                  </li>
                <% else %>
                  <li>
                    <a
                      href={~p"/users/log-in"}
                      class={[
                        "btn",
                        if(String.starts_with?(@current_path, "/users/log-in"),
                          do: "btn-primary",
                          else: "btn-outline"
                        )
                      ]}
                    >
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
                          else: "btn-outline"
                        )
                      ]}
                    >
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
                          else: "btn-outline"
                        )
                      ]}
                    >
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
                          else: "btn-outline"
                        )
                      ]}
                    >
                      {gettext("Achievements")}
                    </a>
                  </li>
                  <li>
                    <a
                      href={~p"/groups"}
                      class={[
                        "btn",
                        if(@current_path == "/groups", do: "btn-primary", else: "btn-outline")
                      ]}
                    >
                      {gettext("Groups")}
                    </a>
                  </li>
                  <li class="menu-title">
                    <div class="flex justify-end items-center w-full pr-2">
                      <span class="text-xs opacity-60">v{app_version()}</span>
                    </div>
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
                          else: "btn-outline"
                        )
                      ]}
                    >
                      {link["label"]}
                    </a>
                  </li>
                <% end %>
                <%= if length(@known_locales) > 1 do %>
                  <li class="mt-2">
                    <div class="flex justify-center">
                      <.language_dropdown
                        locale={@locale}
                        current_path={@current_path}
                        current_query={@current_query}
                        known_locales={@known_locales}
                      />
                    </div>
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

      <%= if @flush do %>
        <div class="flex-1 min-h-0 relative">
          {render_slot(@inner_block)}
        </div>
        <.flash_group flash={@flash} />
      <% else %>
        <main class="relative z-[2] px-4 py-4 sm:px-6 lg:px-8">
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
        label: Map.get(@locale_labels, locale, locale)
      )

    ~H"""
    <div class="dropdown dropdown-end">
      <a href="#" tabindex="0" class="btn btn-outline">
        {@label}
      </a>
      <ul
        tabindex="0"
        class="menu menu-sm dropdown-content mt-2 z-[1] p-2 shadow bg-base-100 rounded-box"
      >
        <%= for link <- @locale_links do %>
          <li>
            <a
              href={link.href}
              class={["whitespace-nowrap", link.locale == @locale && "active"]}
            >
              {link.label}
            </a>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end

  defp strip_locale_prefix(path, known_locales) when is_binary(path) do
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

  defp strip_locale_prefix(_, _known_locales), do: "/"

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
        title={gettext("Reconnecting…")}
        phx-disconnected={JS.dispatch("gs:lv-disconnected")}
        phx-connected={JS.dispatch("gs:lv-connected")}
        phx-hook="ReconnectNotice"
        data-delay-ms="5000"
        hidden
      >
        {gettext("Trying to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Reconnecting…")}
        phx-disconnected={JS.dispatch("gs:lv-disconnected")}
        phx-connected={JS.dispatch("gs:lv-connected")}
        phx-hook="ReconnectNotice"
        data-delay-ms="5000"
        hidden
      >
        {gettext("Trying to reconnect")}
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
