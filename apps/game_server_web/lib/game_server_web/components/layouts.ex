defmodule GameServerWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use GameServerWeb, :html

  alias GameServer.Theme.JSONConfig

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

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
    locale = Gettext.get_locale(GameServerWeb.Gettext)

    provider_theme =
      Map.get(assigns, :theme) || JSONConfig.get_theme(locale) || %{}

    theme = %{
      "title" => Map.get(provider_theme, "title"),
      "tagline" => Map.get(provider_theme, "tagline"),
      "logo" => Map.get(provider_theme, "logo"),
      "banner" => Map.get(provider_theme, "banner"),
      "css" => Map.get(provider_theme, "css")
    }

    assigns =
      assign(assigns,
        current_path: current_path,
        current_query: current_query,
        theme: theme
      )

    ~H"""
    <header class={[
      "navbar px-4 sm:px-6 lg:px-8 sticky top-0 z-50 border-b",
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
                {gettext("Settings")}
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
                href={~p"/groups"}
                class={["btn", if(@current_path == "/groups", do: "btn-primary", else: "btn-outline")]}
              >
                {gettext("Groups")}
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
                href={~p"/groups"}
                class={["btn", if(@current_path == "/groups", do: "btn-primary", else: "btn-outline")]}
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
          <li>
            <.language_dropdown />
          </li>
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
                    {gettext("Settings")}
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
                    href={~p"/groups"}
                    class={[
                      "btn",
                      if(@current_path == "/groups", do: "btn-primary", else: "btn-outline")
                    ]}
                  >
                    {gettext("Groups")}
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
              <li class="mt-2">
                <div class="flex justify-center">
                  <.language_dropdown />
                </div>
              </li>
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

    <main class="px-4 py-4 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl lg:max-w-4xl xl:max-w-6xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    <footer class="px-4 py-6 sm:px-6 lg:px-8 text-center text-sm text-base-content/70">
      <div class="mx-auto max-w-2xl lg:max-w-4xl xl:max-w-6xl flex flex-wrap justify-center gap-x-4 gap-y-1">
        <a href={~p"/privacy"} class="hover:underline">{gettext("Privacy Policy")}</a>
        <a href={~p"/terms"} class="hover:underline">{gettext("Terms and Conditions")}</a>
        <a href={~p"/docs/setup"} class="hover:underline">{gettext("Guides")}</a>
        <a
          href={~p"/api/docs"}
          rel="noopener noreferrer"
          class="hover:underline"
        >
          {gettext("API Docs")}
        </a>
        <a
          href="https://appsinacup.github.io/game_server/"
          target="_blank"
          rel="noopener noreferrer"
          class="hover:underline"
        >
          {gettext("Elixir Docs")}
        </a>
        <a href={~p"/changelog"} class="hover:underline">Changelog</a>
        <a href={~p"/blog"} class="hover:underline">Blog</a>
        <span class="text-xs opacity-60">v{app_version()}</span>
      </div>
    </footer>
    """
  end

  defp language_dropdown(assigns) do
    locale = Gettext.get_locale(GameServerWeb.Gettext) || "en"
    current_path = Map.get(assigns, :current_path, "/")
    current_query = Map.get(assigns, :current_query, "")

    base_path = strip_locale_prefix(current_path)

    query_suffix =
      if is_binary(current_query) and current_query != "", do: "?" <> current_query, else: ""

    english_href = base_path <> query_suffix

    spanish_href =
      if(base_path == "/", do: "/es", else: "/es" <> base_path) <> query_suffix

    assigns =
      assign(assigns,
        locale: locale,
        english_href: english_href,
        spanish_href: spanish_href,
        label:
          case locale do
            "es" -> "Español"
            _ -> "English"
          end
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
        <li>
          <a
            href={@english_href}
            class={["whitespace-nowrap", @locale == "en" && "active"]}
          >
            English
          </a>
        </li>
        <li>
          <a
            href={@spanish_href}
            class={["whitespace-nowrap", @locale == "es" && "active"]}
          >
            Español
          </a>
        </li>
      </ul>
    </div>
    """
  end

  defp strip_locale_prefix(path) when is_binary(path) do
    segments = String.split(path, "/", trim: true)

    case segments do
      [first | rest] when first in ["en", "es"] ->
        case rest do
          [] -> "/"
          _ -> "/" <> Enum.join(rest, "/")
        end

      _ ->
        if String.starts_with?(path, "/"), do: path, else: "/"
    end
  end

  defp strip_locale_prefix(_), do: "/"

  defp app_version do
    # Prefer CI-injected APP_VERSION when present, otherwise fall back to the
    # compiled application vsn or the Mix project version.
    case System.get_env("APP_VERSION") || Application.spec(:game_server, :vsn) do
      nil -> Mix.Project.config()[:version] || "1.0.0"
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
end
