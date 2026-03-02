defmodule GameServerWeb.ChangelogLive do
  @moduledoc """
  LiveView that renders the project changelog from a Markdown file
  configured via the `"changelog"` key in the theme config JSON.
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
     |> assign(:blog_available?, Content.blog_dir() != nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_path={assigns[:current_path]}>
      <div class="py-8 px-4 sm:px-6 max-w-4xl mx-auto">
        <div class="flex items-center justify-between mb-8">
          <h1 class="text-3xl font-bold">Changelog</h1>
          <.link
            :if={@blog_available?}
            navigate={~p"/blog"}
            class="inline-flex items-center gap-1.5 text-sm text-base-content/60 hover:text-primary transition-colors"
          >
            <.icon name="hero-newspaper" class="w-4 h-4" /> Blog
          </.link>
        </div>
        <%= if @changelog_available? do %>
          <article class="markdown-content">
            {Phoenix.HTML.raw(@changelog_html)}
          </article>
        <% else %>
          <div class="text-center py-20">
            <.icon name="hero-document-text" class="w-16 h-16 mx-auto text-base-content/30 mb-4" />
            <h2 class="text-xl font-semibold text-base-content/60 mb-2">No changelog available</h2>
            <p class="text-base-content/40">
              Configure a changelog file in your theme config JSON to display it here.
            </p>
          </div>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
