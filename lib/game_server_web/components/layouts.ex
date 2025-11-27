defmodule GameServerWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use GameServerWeb, :html

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

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="navbar px-4 sm:px-6 lg:px-8">
      <div class="flex-1">
        <a href="/" class="flex-1 flex w-fit items-center gap-2">
          <img src={~p"/images/logo.png"} width="36" alt="Game Server" />
          <span class="text-sm font-semibold">Gamend: Game Server</span>
          <span class="text-xs opacity-60 ml-2">v{app_version()}</span>
        </a>
      </div>
      <div class="flex-none">
        <!-- Desktop Navigation -->
        <ul class="hidden md:flex flex-row px-1 space-x-4 items-center">
          <%= if @current_scope do %>
            <li>
              <!-- profile icon that links to settings (shows discord avatar or initials) -->
              <.link href={~p"/users/settings"} class="inline-flex items-center">
                <div class="w-8 h-8 rounded-full bg-base-300 flex items-center justify-center text-sm font-semibold mr-2 overflow-hidden">
                  <%= if @current_scope.user.profile_url && @current_scope.user.profile_url != "" do %>
                    <img
                      src={@current_scope.user.profile_url}
                      alt="avatar"
                      class="w-8 h-8 rounded-full"
                    />
                  <% else %>
                    {profile_initials(@current_scope.user)}
                  <% end %>
                </div>
              </.link>
            </li>
            <li>
              {profile_display_name(@current_scope.user)}
            </li>
            <li>
              <.link href={~p"/users/settings"} class="btn btn-outline">Settings</.link>
            </li>
            <%= if @current_scope && @current_scope.user.is_admin do %>
              <li>
                <.link href={~p"/admin"} class="btn btn-outline">Admin</.link>
              </li>
            <% end %>
            <li>
              <.link href={~p"/lobbies"} class="btn btn-outline">Lobbies</.link>
            </li>
            <li>
              <.link href={~p"/users/log-out"} method="delete" class="btn btn-outline">
                Log out
              </.link>
            </li>
          <% else %>
            <li>
              <.link href={~p"/users/log-in"} class="btn btn-primary">Log in</.link>
            </li>
            <li>
              <.link href={~p"/lobbies"} class="btn btn-outline">Lobbies</.link>
            </li>
            <li>
              <.link href={~p"/users/register"} class="btn btn-outline">Register</.link>
            </li>
          <% end %>
          <li>
            <.theme_toggle />
          </li>
        </ul>
        
    <!-- Mobile Navigation -->
        <div class="md:hidden">
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
                <li class="menu-title">
                  <div class="flex justify-between items-center w-full pr-2">
                    <span>
                      {profile_initials(@current_scope.user)} {profile_display_name(
                        @current_scope.user
                      )}
                    </span>
                    <span class="text-xs opacity-60">v{app_version()}</span>
                  </div>
                </li>
                <li><a href={~p"/users/settings"} class="btn btn-outline">Settings</a></li>
                <li><a href={~p"/lobbies"} class="btn btn-outline">Lobbies</a></li>
                <%= if @current_scope && @current_scope.user.is_admin do %>
                  <li><a href={~p"/admin"} class="btn btn-outline">Admin</a></li>
                <% end %>
                <li>
                  <a href={~p"/users/log-out"} method="delete" class="btn btn-outline">Log out</a>
                </li>
              <% else %>
                <li><a href={~p"/users/log-in"} class="btn btn-outline">Log in</a></li>
                <li><a href={~p"/users/register"} class="btn btn-outline">Register</a></li>
                <li><a href={~p"/lobbies"} class="btn btn-outline">Lobbies</a></li>
                <li class="menu-title">
                  <div class="flex justify-end items-center w-full pr-2">
                    <span class="text-xs opacity-60">v{app_version()}</span>
                  </div>
                </li>
              <% end %>
              <li><a href={~p"/docs/setup"}>Guides</a></li>
              <li><a href={~p"/api/docs"} target="_blank">API Docs</a></li>
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

    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl lg:max-w-4xl xl:max-w-6xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    <footer class="px-4 py-6 sm:px-6 lg:px-8 text-center text-sm text-base-content/70">
      <div class="mx-auto max-w-2xl lg:max-w-4xl xl:max-w-6xl">
        <a href={~p"/privacy"} class="hover:underline mr-4">Privacy Policy</a>
        <a href={~p"/terms"} class="hover:underline mr-4">Terms and Conditions</a>
        <a href={~p"/docs/setup"} class="hover:underline mr-4">Guides</a>
        <a
          href="https://appsinacup.github.io/game_server/"
          target="_blank"
          rel="noopener noreferrer"
          class="hover:underline mr-4"
        >
          Elixir Docs
        </a>
        <span class="text-xs opacity-60">v{app_version()}</span>
      </div>
    </footer>
    """
  end

  defp app_version do
    # Prefer CI-injected APP_VERSION when present, otherwise fall back to the
    # compiled application vsn or the Mix project version.
    case System.get_env("APP_VERSION") || Application.spec(:game_server, :vsn) do
      nil -> Mix.Project.config()[:version] || "1.0.0"
      vsn -> to_string(vsn)
    end
  end

  defp profile_initials(nil), do: "?"

  defp profile_initials(%{display_name: display_name, metadata: metadata, email: email}) do
    name =
      cond do
        is_binary(display_name) && byte_size(display_name) > 0 ->
          display_name

        is_map(metadata) and is_binary(Map.get(metadata, "display_name")) and
            byte_size(Map.get(metadata, "display_name")) > 0 ->
          Map.get(metadata, "display_name")

        true ->
          String.split(email || "", "@") |> hd() || "?"
      end

    name
    |> String.split(~r/\s+/)
    |> Enum.map_join(&String.first/1)
    |> String.slice(0, 2)
    |> String.upcase()
  end

  defp profile_display_name(nil), do: "?"

  defp profile_display_name(%{display_name: display_name, metadata: metadata, email: email}) do
    cond do
      is_binary(display_name) && byte_size(display_name) > 0 ->
        display_name

      is_map(metadata) && is_binary(Map.get(metadata, "display_name")) &&
          byte_size(Map.get(metadata, "display_name")) > 0 ->
        Map.get(metadata, "display_name")

      true ->
        email || ""
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
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
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
