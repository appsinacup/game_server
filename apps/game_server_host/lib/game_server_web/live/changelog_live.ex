defmodule GameServerWeb.HostChangelogLive do
  @moduledoc """
  Host-owned LiveView that renders the project changelog from Markdown content.
  """

  use GameServerWeb, :live_view

  alias GameServer.Content

  @impl true
  def mount(_params, _session, socket) do
    html = Content.changelog_html()

    {:ok,
     socket
     |> assign(:page_title, "Changelog")
     |> assign(:changelog_html, html)
     |> assign(:changelog_available?, html != nil)
     |> assign(:roadmap_available?, Content.path(:roadmap) != nil)
     |> assign(:blog_available?, Content.path(:blog) != nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_path={assigns[:current_path]}>
      <div class="py-8 px-4 sm:px-6 max-w-4xl mx-auto">
        <div class="flex items-center justify-between mb-8">
          <h1 class="text-3xl font-bold">{gettext("Changelog")}</h1>
          <div class="flex items-center gap-3">
            <.link
              :if={@roadmap_available?}
              navigate={~p"/roadmap"}
              class="inline-flex items-center gap-1.5 text-sm text-base-content/60 hover:text-primary transition-colors"
            >
              <.icon name="hero-map" class="w-4 h-4" /> {gettext("Roadmap")}
            </.link>
            <.link
              :if={@blog_available?}
              navigate={~p"/blog"}
              class="inline-flex items-center gap-1.5 text-sm text-base-content/60 hover:text-primary transition-colors"
            >
              <.icon name="hero-newspaper" class="w-4 h-4" /> {gettext("Blog")}
            </.link>
          </div>
        </div>
        <%= if @changelog_available? do %>
          <article class="markdown-content">
            {Phoenix.HTML.raw(@changelog_html)}
          </article>
        <% else %>
          <div class="text-center py-20">
            <.icon name="hero-document-text" class="w-16 h-16 mx-auto text-base-content/30 mb-4" />
            <h2 class="text-xl font-semibold text-base-content/60 mb-2">
              {gettext("No results.")}
            </h2>
            <p class="text-base-content/40">
              Add a changelog file under apps/game_server_host/content/CHANGELOG.md to display it here.
            </p>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
