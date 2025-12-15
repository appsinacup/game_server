defmodule GameServerWeb.AdminLive.KV do
  use GameServerWeb, :live_view

  alias GameServer.KV

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <.link navigate={~p"/admin"} class="btn btn-outline mb-4">
          ← Back to Admin
        </.link>

        <div class="card bg-base-200">
          <div class="card-body">
            <div class="flex items-center justify-between gap-4">
              <h2 class="card-title">KV Entries ({@count})</h2>
              <div class="text-xs text-base-content/60">
                page {@page} / {@total_pages}
              </div>
            </div>

            <div class="overflow-x-auto mt-4">
              <table id="admin-kv-table" class="table table-zebra w-full">
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Key</th>
                    <th>User</th>
                    <th>Plugin</th>
                    <th>Updated</th>
                    <th>Value</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={e <- @entries} id={"admin-kv-" <> to_string(e.id)}>
                    <td class="font-mono text-sm">{e.id}</td>
                    <td class="font-mono text-sm break-all">{e.key}</td>
                    <td class="font-mono text-sm">
                      <%= if e.user_id do %>
                        {e.user_id}
                      <% else %>
                        <span class="badge badge-ghost badge-sm">global</span>
                      <% end %>
                    </td>
                    <td class="text-sm">
                      <span class="font-mono text-xs break-all">{plugin_from_metadata(e.metadata)}</span>
                    </td>
                    <td class="text-sm">
                      <span class="font-mono text-xs">
                        {if e.updated_at, do: DateTime.to_iso8601(e.updated_at), else: "-"}
                      </span>
                    </td>
                    <td class="text-sm">
                      <pre class="text-xs font-mono whitespace-pre-wrap max-h-24 overflow-auto bg-base-100/60 rounded p-2">{json_preview(e.value)}</pre>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>

            <div class="mt-4 flex gap-2 items-center">
              <button phx-click="kv_prev" class="btn btn-xs" disabled={@page <= 1}>
                Prev
              </button>
              <div class="text-xs text-base-content/70">
                page {@page} / {@total_pages} ({@count} total)
              </div>
              <button
                phx-click="kv_next"
                class="btn btn-xs"
                disabled={@page >= @total_pages || @total_pages == 0}
              >
                Next
              </button>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    page = 1
    page_size = 50

    {:ok,
     socket
     |> assign(:page, page)
     |> assign(:page_size, page_size)
     |> reload_entries()}
  end

  @impl true
  def handle_event("kv_prev", _params, socket) do
    {:noreply, socket |> assign(:page, max(1, socket.assigns.page - 1)) |> reload_entries()}
  end

  @impl true
  def handle_event("kv_next", _params, socket) do
    {:noreply, socket |> assign(:page, socket.assigns.page + 1) |> reload_entries()}
  end

  defp reload_entries(socket) do
    page = socket.assigns.page
    page_size = socket.assigns.page_size

    entries = KV.list_entries(page: page, page_size: page_size)
    count = KV.count_entries()
    total_pages = if page_size > 0, do: div(count + page_size - 1, page_size), else: 0

    socket
    |> assign(:entries, entries)
    |> assign(:count, count)
    |> assign(:total_pages, total_pages)
    |> clamp_page()
  end

  defp clamp_page(socket) do
    page = socket.assigns.page
    total_pages = socket.assigns.total_pages

    page =
      cond do
        total_pages == 0 -> 1
        page < 1 -> 1
        page > total_pages -> total_pages
        true -> page
      end

    assign(socket, :page, page)
  end

  defp plugin_from_metadata(nil), do: "-"

  defp plugin_from_metadata(metadata) when is_map(metadata) do
    Map.get(metadata, "plugin") || Map.get(metadata, :plugin) || "-"
  end

  defp json_preview(map) when is_map(map) do
    Jason.encode!(map)
    |> String.slice(0, 2048)
  end

  defp json_preview(_), do: "{}"
end
