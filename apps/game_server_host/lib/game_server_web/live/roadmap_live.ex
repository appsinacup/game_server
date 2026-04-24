defmodule GameServerWeb.HostRoadmapLive do
  @moduledoc """
  Host-owned LiveView that renders the project roadmap from Markdown content.
  """

  use GameServerWeb, :live_view

  alias GameServer.Content

  @impl true
  def mount(_params, _session, socket) do
    html = Content.roadmap_html()

    {:ok,
     socket
     |> assign(:page_title, "Roadmap")
     |> assign(:roadmap_html, html)
     |> assign(:roadmap_available?, html != nil)
     |> assign(:changelog_available?, Content.changelog_path() != nil)
     |> assign(:blog_available?, Content.blog_dir() != nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_path={assigns[:current_path]}>
      <div class="py-8 px-4 sm:px-6 max-w-4xl mx-auto">
        <div class="flex items-center justify-between mb-8">
          <h1 class="text-3xl font-bold">{gettext("Roadmap")}</h1>
          <div class="flex items-center gap-3">
            <.link
              :if={@changelog_available?}
              navigate={~p"/changelog"}
              class="inline-flex items-center gap-1.5 text-sm text-base-content/60 hover:text-primary transition-colors"
            >
              <.icon name="hero-clipboard-document-list" class="w-4 h-4" /> {gettext("Changelog")}
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
        <%= if @roadmap_available? do %>
          <article class="markdown-content">
            {Phoenix.HTML.raw(@roadmap_html)}
          </article>
        <% else %>
          <div class="text-center py-20">
            <.icon name="hero-map" class="w-16 h-16 mx-auto text-base-content/30 mb-4" />
            <h2 class="text-xl font-semibold text-base-content/60 mb-2">
              {gettext("No results.")}
            </h2>
            <p class="text-base-content/40">
              Add a roadmap file under apps/game_server_host/content/ROADMAP.md to display it here.
            </p>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
