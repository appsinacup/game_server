defmodule GameServerWeb.BlogLive do
  @moduledoc false

  use GameServerWeb, :live_view

  @impl true
  def mount(params, session, socket) do
    if host_live_available?(:mount, 3) do
      host_live().mount(params, session, socket)
    else
      {:ok, assign(socket, :page_title, "Blog")}
    end
  end

  @impl true
  def handle_params(params, uri, socket) do
    if host_live_available?(:handle_params, 3) do
      host_live().handle_params(params, uri, socket)
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    if host_live_available?(:render, 1) do
      host_live().render(assigns)
    else
      ~H"""
      <Layouts.app flash={@flash} current_scope={@current_scope}>
        <section id="standalone-blog" class="space-y-4">
          <h1 class="text-3xl font-semibold">Blog</h1>
          <p class="text-base-content/70">
            Host blog content is unavailable in standalone web mode.
          </p>
        </section>
      </Layouts.app>
      """
    end
  end

  defp host_live, do: Module.concat(GameServerWeb, HostBlogLive)

  defp host_live_available?(function_name, arity) do
    Code.ensure_loaded?(host_live()) and function_exported?(host_live(), function_name, arity)
  end
end
