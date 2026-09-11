defmodule GamendWeb.AdminLive.Friends do
  @moduledoc """
  Admin view over friendships: every non-block row in the system — pending,
  accepted and rejected — filterable by the user on either side and by status,
  with force-remove (unfriend an accepted pair or cancel a request).
  """
  use GamendWeb, :live_view

  alias Gamend.Friends

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Admin · Friends")
      |> assign(:page, 1)
      |> assign(:page_size, 25)
      |> assign(:status_filter, "all")
      |> assign(:user_filter, "")
      |> reload()

    {:ok, socket}
  end

  @impl true
  def handle_event("filter", params, socket) do
    {:noreply,
     socket
     |> assign(:status_filter, Map.get(params, "status", "all"))
     |> assign(:user_filter, String.trim(Map.get(params, "user_id", "")))
     |> assign(:page, 1)
     |> reload()}
  end

  def handle_event("prev_page", _params, socket) do
    {:noreply, socket |> assign(:page, max(socket.assigns.page - 1, 1)) |> reload()}
  end

  def handle_event("next_page", _params, socket) do
    page = min(socket.assigns.page + 1, max(socket.assigns.total_pages, 1))
    {:noreply, socket |> assign(:page, page) |> reload()}
  end

  def handle_event("page_size", %{"size" => size}, socket) do
    {:noreply,
     socket
     |> assign(:page_size, String.to_integer(size))
     |> assign(:page, 1)
     |> reload()}
  end

  def handle_event("remove", %{"id" => id}, socket) do
    socket =
      case Friends.delete_friendship(id) do
        {:ok, :removed} -> put_flash(socket, :info, "Friendship removed")
        {:error, :not_found} -> put_flash(socket, :error, "Friendship not found")
      end

    {:noreply, reload(socket)}
  end

  def handle_event("refresh", _params, socket) do
    {:noreply, reload(socket)}
  end

  # ── data ──────────────────────────────────────────────────────────────────

  defp reload(socket) do
    filters = [
      status: status_filter(socket.assigns.status_filter),
      user_id: presence(socket.assigns.user_filter),
      page: socket.assigns.page,
      page_size: socket.assigns.page_size
    ]

    friendships = Friends.list_all_friendships(filters)
    total = Friends.count_all_friendships(filters)

    socket
    |> assign(:friendships, friendships)
    |> assign(:count, total)
    |> assign(:total_pages, ceil_div(total, socket.assigns.page_size))
  end

  defp status_filter("all"), do: nil
  defp status_filter(status), do: status

  defp presence(""), do: nil
  defp presence(value), do: value

  defp ceil_div(_num, 0), do: 0
  defp ceil_div(num, den), do: div(num + den - 1, den)

  defp user_name(nil), do: "—"

  defp user_name(user) do
    cond do
      is_binary(user.display_name) and user.display_name != "" -> user.display_name
      is_binary(user.username) and user.username != "" -> user.username
      is_binary(user.email) and user.email != "" -> user.email
      true -> user.id
    end
  end

  defp status_class("pending"), do: "badge-info"
  defp status_class("accepted"), do: "badge-success"
  defp status_class("rejected"), do: "badge-ghost"
  defp status_class(_status), do: "badge-ghost"

  # ── render ────────────────────────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_path={assigns[:current_path]}>
      <.link navigate={~p"/admin"} class="btn btn-outline mb-4">← Back to Admin</.link>

      <div class="card bg-base-200">
        <div class="card-body">
          <div class="flex flex-wrap items-center justify-between gap-2">
            <h2 class="card-title">Friendships ({@count})</h2>
            <button phx-click="refresh" class="btn btn-ghost btn-sm">Refresh</button>
          </div>

          <p class="text-sm text-base-content/70">
            Every friend request and friendship, in any status. Blocks live on the
            <.link navigate={~p"/admin/blacklist"} class="link">Blacklist</.link>
            page.
          </p>

          <form
            phx-change="filter"
            phx-no-unused-field
            id="friends-filter-form"
            class="flex flex-wrap gap-2 my-2"
          >
            <select name="status" class="select select-sm w-40">
              <option value="all" selected={@status_filter == "all"}>All statuses</option>
              <option value="pending" selected={@status_filter == "pending"}>Pending</option>
              <option value="accepted" selected={@status_filter == "accepted"}>Accepted</option>
              <option value="rejected" selected={@status_filter == "rejected"}>Rejected</option>
            </select>
            <input
              type="text"
              name="user_id"
              value={@user_filter}
              placeholder="Filter by user id (either side)"
              phx-debounce="300"
              class="input input-sm w-80 font-mono"
            />
          </form>

          <div class="overflow-x-auto">
            <table class="table table-sm">
              <thead>
                <tr>
                  <th>Requester</th>
                  <th>Target</th>
                  <th>Status</th>
                  <th>Since</th>
                  <th>Updated</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <tr :for={friendship <- @friendships} id={"friendship-#{friendship.id}"}>
                  <td>
                    {user_name(friendship.requester)}
                    <div class="font-mono text-xs text-base-content/60">
                      {friendship.requester_id}
                    </div>
                  </td>
                  <td>
                    {user_name(friendship.target)}
                    <div class="font-mono text-xs text-base-content/60">{friendship.target_id}</div>
                  </td>
                  <td>
                    <span class={["badge badge-sm", status_class(friendship.status)]}>
                      {friendship.status}
                    </span>
                  </td>
                  <td class="text-xs">
                    <.timestamp at={friendship.inserted_at} format="full" />
                  </td>
                  <td class="text-xs">
                    <.timestamp at={friendship.updated_at} format="full" />
                  </td>
                  <td class="text-right">
                    <button
                      phx-click="remove"
                      phx-value-id={friendship.id}
                      class="btn btn-outline btn-error btn-xs"
                    >
                      Remove
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <div :if={@friendships == []} class="text-center py-8 text-base-content/60">
            No friendships.
          </div>

          <div class="mt-4 flex justify-center">
            <.pagination
              page={@page}
              total_pages={@total_pages}
              total_count={@count}
              page_size={@page_size}
              on_prev="prev_page"
              on_next="next_page"
              on_page_size="page_size"
            />
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
