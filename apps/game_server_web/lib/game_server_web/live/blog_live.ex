defmodule GameServerWeb.BlogLive do
  @moduledoc """
  LiveView for the blog section.

  - `:index` — lists all blog posts grouped by year and month
  - `:show`  — renders an individual post with next/prev navigation
  """

  use GameServerWeb, :live_view

  alias GameServer.Content

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Blog")
     |> assign(:blog_available?, Content.blog_dir() != nil)}
  end

  # ---------------------------------------------------------------------------
  # Params
  # ---------------------------------------------------------------------------

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    grouped = Content.blog_posts_grouped()

    socket
    |> assign(:page_title, "Blog")
    |> assign(:grouped_posts, grouped)
    |> assign(:post, nil)
    |> assign(:post_html, nil)
    |> assign(:prev_post, nil)
    |> assign(:next_post, nil)
  end

  defp apply_action(socket, :show, %{"slug" => slug}) do
    post = Content.get_blog_post(slug)

    if post do
      html = Content.blog_post_html(slug)
      {prev, next} = Content.blog_neighbours(slug)

      socket
      |> assign(:page_title, post.title)
      |> assign(:post, post)
      |> assign(:post_html, html)
      |> assign(:prev_post, prev)
      |> assign(:next_post, next)
      |> assign(:grouped_posts, [])
    else
      socket
      |> put_flash(:error, "Blog post not found")
      |> push_navigate(to: ~p"/blog")
    end
  end

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_path={assigns[:current_path]}>
      <div class="py-8 px-4 sm:px-6 max-w-4xl mx-auto">
        <%= if !@blog_available? do %>
          <div class="text-center py-20">
            <.icon name="hero-newspaper" class="w-16 h-16 mx-auto text-base-content/30 mb-4" />
            <h2 class="text-xl font-semibold text-base-content/60 mb-2">No blog available</h2>
            <p class="text-base-content/40">
              Configure a blog directory in your theme config JSON to display posts here.
            </p>
          </div>
        <% else %>
          <%= if @live_action == :show && @post do %>
            <.blog_post post={@post} html={@post_html} prev={@prev_post} next={@next_post} />
          <% else %>
            <.blog_index grouped_posts={@grouped_posts} />
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  # ---------------------------------------------------------------------------
  # Blog Index
  # ---------------------------------------------------------------------------

  defp blog_index(assigns) do
    ~H"""
    <h1 class="text-3xl font-bold mb-8">Blog</h1>

    <%= if @grouped_posts == [] do %>
      <div class="text-center py-16">
        <.icon name="hero-pencil-square" class="w-12 h-12 mx-auto text-base-content/30 mb-3" />
        <p class="text-base-content/50">No blog posts yet.</p>
      </div>
    <% else %>
      <div class="space-y-10">
        <%= for {year, months} <- @grouped_posts do %>
          <section>
            <h2 class="text-2xl font-bold text-base-content/90 mb-6 border-b border-base-300 pb-2">
              {year}
            </h2>
            <%= for {month, posts} <- months do %>
              <div class="mb-6">
                <h3 class="text-lg font-semibold text-base-content/70 mb-3 flex items-center gap-2">
                  <.icon name="hero-calendar" class="w-5 h-5" />
                  {month_name(month)}
                </h3>
                <div class="space-y-3 ml-2">
                  <%= for post <- posts do %>
                    <.link
                      navigate={~p"/blog/#{post.slug}"}
                      class="group block p-4 rounded-xl border border-base-300 hover:border-primary/40
                             hover:bg-base-200/50 transition-all duration-200"
                    >
                      <div class="flex items-start justify-between gap-4">
                        <div class="flex-1 min-w-0">
                          <h4 class="font-semibold text-base-content group-hover:text-primary transition-colors truncate">
                            {post.title}
                          </h4>
                          <p
                            :if={post.excerpt != ""}
                            class="text-sm text-base-content/60 mt-1 line-clamp-2"
                          >
                            {post.excerpt}
                          </p>
                        </div>
                        <time class="text-xs text-base-content/40 whitespace-nowrap pt-1">
                          {Calendar.strftime(post.date, "%b %d")}
                        </time>
                      </div>
                    </.link>
                  <% end %>
                </div>
              </div>
            <% end %>
          </section>
        <% end %>
      </div>
    <% end %>
    """
  end

  # ---------------------------------------------------------------------------
  # Blog Post
  # ---------------------------------------------------------------------------

  defp blog_post(assigns) do
    ~H"""
    <%!-- Back link --%>
    <.link
      navigate={~p"/blog"}
      class="inline-flex items-center gap-1 text-sm text-base-content/60 hover:text-primary mb-6 transition-colors"
    >
      <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to Blog
    </.link>

    <%!-- Post header --%>
    <header class="mb-8">
      <h1 class="text-3xl font-bold mb-2">{@post.title}</h1>
      <time class="text-sm text-base-content/50">
        {Calendar.strftime(@post.date, "%B %d, %Y")}
      </time>
    </header>

    <%!-- Post content --%>
    <article class="markdown-content">
      {Phoenix.HTML.raw(@html)}
    </article>

    <%!-- Next / Prev navigation --%>
    <nav class="flex items-center justify-between mt-12 pt-6 border-t border-base-300">
      <div class="flex-1">
        <.link
          :if={@next}
          navigate={~p"/blog/#{@next.slug}"}
          class="inline-flex items-center gap-2 text-sm text-base-content/60 hover:text-primary transition-colors"
        >
          <.icon name="hero-arrow-left" class="w-4 h-4" />
          <div>
            <div class="text-xs text-base-content/40">Older</div>
            <div class="font-medium">{@next.title}</div>
          </div>
        </.link>
      </div>
      <div class="flex-1 text-right">
        <.link
          :if={@prev}
          navigate={~p"/blog/#{@prev.slug}"}
          class="inline-flex items-center gap-2 text-sm text-base-content/60 hover:text-primary transition-colors ml-auto"
        >
          <div>
            <div class="text-xs text-base-content/40">Newer</div>
            <div class="font-medium">{@prev.title}</div>
          </div>
          <.icon name="hero-arrow-right" class="w-4 h-4" />
        </.link>
      </div>
    </nav>
    """
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp month_name(1), do: "January"
  defp month_name(2), do: "February"
  defp month_name(3), do: "March"
  defp month_name(4), do: "April"
  defp month_name(5), do: "May"
  defp month_name(6), do: "June"
  defp month_name(7), do: "July"
  defp month_name(8), do: "August"
  defp month_name(9), do: "September"
  defp month_name(10), do: "October"
  defp month_name(11), do: "November"
  defp month_name(12), do: "December"
end
