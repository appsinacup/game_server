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
          <img src={~p"/images/logo-red.png"} width="36" alt="Game Server" />
          <span class="text-sm font-semibold">URO: Game Server</span>
        </a>
      </div>
      <div class="flex-none">
        <ul class="flex flex-column px-1 space-x-4 items-center">
          <%= if @current_scope do %>
            <li>
              <!-- profile icon that links to settings (shows discord avatar or initials) -->
              <.link href={~p"/users/settings"} class="inline-flex items-center">
                <div class="w-8 h-8 rounded-full bg-base-300 flex items-center justify-center text-sm font-semibold mr-2 overflow-hidden">
                  <%= if @current_scope.user.discord_avatar && @current_scope.user.discord_avatar != "" do %>
                    <% avatar = @current_scope.user.discord_avatar %>
                    <% avatar_src =
                      if String.starts_with?(avatar, "http") do
                        avatar
                      else
                        ext = if String.starts_with?(avatar, "a_"), do: ".gif", else: ".png"

                        "https://cdn.discordapp.com/avatars/#{@current_scope.user.discord_id}/#{avatar}#{ext}"
                      end %>

                    <img src={avatar_src} alt="avatar" class="w-8 h-8 rounded-full" />
                  <% else %>
                    {profile_initials(@current_scope.user)}
                  <% end %>
                </div>
              </.link>
            </li>
            <li>
              {@current_scope.user.email}
            </li>
            <li>
              <.link href={~p"/users/settings"} class="btn btn-primary">Settings</.link>
            </li>
            <%= if @current_scope && @current_scope.user.is_admin do %>
              <li>
                <.link href={~p"/admin"} class="btn btn-primary">Admin</.link>
              </li>
            <% end %>
            <li>
              <.link href={~p"/users/log-out"} method="delete" class="btn btn-outline">
                Log out
              </.link>
            </li>
          <% else %>
          <% end %>
          <li>
            <.link href={~p"/api/docs"} target="_blank">API Docs</.link>
          </li>
          <li>
            <.theme_toggle />
          </li>
        </ul>
      </div>
    </header>

    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  defp profile_initials(nil), do: "?"

  defp profile_initials(%{metadata: metadata, email: email}) do
    name =
      case metadata do
        %{"display_name" => dn} when is_binary(dn) and byte_size(dn) > 0 -> dn
        _ -> String.split(email || "", "@") |> hd() || "?"
      end

    name
    |> String.split(~r/\s+/)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.slice(0, 2)
    |> String.upcase()
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
