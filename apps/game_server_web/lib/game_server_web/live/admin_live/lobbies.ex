defmodule GameServerWeb.AdminLive.Lobbies do
  use GameServerWeb, :live_view

  alias GameServer.Lobbies

  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to lobby pubsub so admin UI updates live when lobbies are
    # created/updated/deleted by API/quick_join flows.
    Lobbies.subscribe_lobbies()

    socket =
      socket
      |> assign(:lobbies_page, 1)
      |> assign(:lobbies_page_size, 25)
      |> assign(:filters, %{})
      |> assign(:selected_lobby, nil)
      |> assign(:form, nil)
      |> assign(:selected_ids, MapSet.new())
      |> reload_lobbies()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <.link navigate={~p"/admin"} class="btn btn-outline mb-4">← Back to Admin</.link>

        <div class="card bg-base-200">
          <div class="card-body">
            <div class="flex items-center justify-between gap-3">
              <h2 class="card-title">Lobbies ({@count})</h2>
              <button
                type="button"
                phx-click="bulk_delete"
                data-confirm={"Delete #{MapSet.size(@selected_ids)} selected lobbies?"}
                class="btn btn-sm btn-outline btn-error"
                disabled={MapSet.size(@selected_ids) == 0}
              >
                Delete selected ({MapSet.size(@selected_ids)})
              </button>
            </div>

            <form phx-change="filter">
              <div class="overflow-x-auto mt-4">
                <table class="table table-zebra w-full">
                  <thead>
                    <tr>
                      <th class="w-10">
                        <input
                          type="checkbox"
                          class="checkbox checkbox-sm"
                          phx-click="toggle_select_all"
                          checked={@lobbies != [] && MapSet.size(@selected_ids) == length(@lobbies)}
                        />
                      </th>
                      <th>ID</th>
                      <th>Title</th>
                      <th>Host ID</th>
                      <th>Users (Cap)</th>
                      <th>Hidden</th>
                      <th>Locked</th>
                      <th>Password</th>
                      <th>Created</th>
                      <th>Updated</th>
                      <th>Actions</th>
                    </tr>
                    <tr>
                      <th></th>
                      <th></th>
                      <th>
                        <input
                          type="text"
                          name="title"
                          value={@filters["title"]}
                          class="input input-bordered input-xs w-full"
                          placeholder="Filter..."
                          phx-debounce="300"
                        />
                      </th>
                      <th></th>
                      <th class="flex gap-1">
                        <input
                          type="number"
                          name="min_users"
                          value={@filters["min_users"]}
                          class="input input-bordered input-xs w-16"
                          placeholder="Min"
                          phx-debounce="300"
                        />
                        <input
                          type="number"
                          name="max_users"
                          value={@filters["max_users"]}
                          class="input input-bordered input-xs w-16"
                          placeholder="Max"
                          phx-debounce="300"
                        />
                      </th>
                      <th>
                        <select name="is_hidden" class="select select-bordered select-xs w-full">
                          <option value="" selected={@filters["is_hidden"] == ""}>All</option>
                          <option value="true" selected={@filters["is_hidden"] == "true"}>
                            Hidden
                          </option>
                          <option value="false" selected={@filters["is_hidden"] == "false"}>
                            Public
                          </option>
                        </select>
                      </th>
                      <th>
                        <select name="is_locked" class="select select-bordered select-xs w-full">
                          <option value="" selected={@filters["is_locked"] == ""}>All</option>
                          <option value="true" selected={@filters["is_locked"] == "true"}>
                            Locked
                          </option>
                          <option value="false" selected={@filters["is_locked"] == "false"}>
                            Open
                          </option>
                        </select>
                      </th>
                      <th>
                        <select name="has_password" class="select select-bordered select-xs w-full">
                          <option value="" selected={@filters["has_password"] == ""}>All</option>
                          <option value="true" selected={@filters["has_password"] == "true"}>
                            Yes
                          </option>
                          <option value="false" selected={@filters["has_password"] == "false"}>
                            No
                          </option>
                        </select>
                      </th>
                      <th></th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr :for={l <- @lobbies} id={"admin-lobby-" <> to_string(l.id)}>
                      <td class="w-10">
                        <input
                          type="checkbox"
                          class="checkbox checkbox-sm"
                          phx-click="toggle_select"
                          phx-value-id={l.id}
                          checked={MapSet.member?(@selected_ids, l.id)}
                        />
                      </td>
                      <td class="font-mono text-sm">{l.id}</td>
                      <td class="text-sm">{l.title || "-"}</td>
                      <td class="font-mono text-sm">{l.host_id}</td>
                      <td class="text-sm">{length(l.users || [])} / {l.max_users}</td>
                      <td class="text-sm">
                        <%= if l.is_hidden do %>
                          <span class="badge badge-info badge-sm">Hidden</span>
                        <% else %>
                          <span class="badge badge-ghost badge-sm">Public</span>
                        <% end %>
                      </td>
                      <td class="text-sm">
                        <%= if l.is_locked do %>
                          <span class="badge badge-warning badge-sm">Locked</span>
                        <% else %>
                          <span class="badge badge-ghost badge-sm">Open</span>
                        <% end %>
                      </td>
                      <td class="text-sm">
                        <%= if l.password_hash do %>
                          <span class="badge badge-success badge-sm">Yes</span>
                        <% else %>
                          <span class="badge badge-ghost badge-sm">No</span>
                        <% end %>
                      </td>
                      <td class="text-sm">
                        {Calendar.strftime(l.inserted_at, "%Y-%m-%d %H:%M")}
                      </td>
                      <td class="text-sm">
                        {Calendar.strftime(l.updated_at, "%Y-%m-%d %H:%M")}
                      </td>
                      <td class="text-sm">
                        <button
                          type="button"
                          phx-click="edit_lobby"
                          phx-value-id={l.id}
                          class="btn btn-xs btn-outline btn-info mr-2"
                        >
                          Edit
                        </button>
                        <button
                          type="button"
                          phx-click="delete_lobby"
                          phx-value-id={l.id}
                          data-confirm="Are you sure?"
                          class="btn btn-xs btn-outline btn-error"
                        >
                          Delete
                        </button>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </form>

            <div class="mt-4 flex gap-2 items-center">
              <button phx-click="admin_lobbies_prev" class="btn btn-xs" disabled={@lobbies_page <= 1}>
                Prev
              </button>
              <div class="text-xs text-base-content/70">
                page {@lobbies_page} / {@lobbies_total_pages} ({@count} total)
              </div>
              <button
                phx-click="admin_lobbies_next"
                class="btn btn-xs"
                disabled={@lobbies_page >= @lobbies_total_pages || @lobbies_total_pages == 0}
              >
                Next
              </button>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>

    <%= if @selected_lobby do %>
      <div class="modal modal-open">
        <div class="modal-box">
          <h3 class="font-bold text-lg">Edit Lobby</h3>

          <.form for={@form} id="lobby-form" phx-submit="save_lobby">
            <.input field={@form[:title]} type="text" label="Title" />
            <.input field={@form[:max_users]} type="number" label="Max users" />
            <.input field={@form[:is_hidden]} type="checkbox" label="Hidden" />
            <.input field={@form[:is_locked]} type="checkbox" label="Locked" />

            <div class="form-control">
              <label class="label">Password (leave blank to clear)</label>
              <input name="lobby[password]" type="text" class="input input-bordered" />
            </div>

            <div class="form-control">
              <label class="label">Metadata (JSON)</label>
              <textarea name="lobby[metadata]" class="textarea textarea-bordered" rows="4"><%= Jason.encode!(@selected_lobby.metadata || %{}) %></textarea>
            </div>

            <div class="mt-4 text-sm text-base-content/70 space-y-1">
              <div>
                Created:
                <span class="font-mono">
                  {Calendar.strftime(@selected_lobby.inserted_at, "%Y-%m-%d %H:%M:%S")}
                </span>
              </div>
              <div>
                Updated:
                <span class="font-mono">
                  {Calendar.strftime(@selected_lobby.updated_at, "%Y-%m-%d %H:%M:%S")}
                </span>
              </div>
            </div>

            <div class="modal-action">
              <button type="button" phx-click="cancel_edit" class="btn">Cancel</button>
              <button type="submit" class="btn btn-primary">Save</button>
            </div>
          </.form>
        </div>
      </div>
    <% end %>
    """
  end

  @impl true
  def handle_event("filter", params, socket) do
    {:noreply,
     socket
     |> assign(:filters, params)
     |> assign(:lobbies_page, 1)
     |> reload_lobbies()}
  end

  @impl true
  def handle_event("toggle_select", %{"id" => id}, socket) do
    {id, ""} = Integer.parse(to_string(id))
    selected = socket.assigns[:selected_ids] || MapSet.new()

    selected =
      if MapSet.member?(selected, id) do
        MapSet.delete(selected, id)
      else
        MapSet.put(selected, id)
      end

    {:noreply,
     socket
     |> assign(:selected_ids, selected)
     |> sync_selected_ids(lobby_ids(socket.assigns.lobbies))}
  end

  @impl true
  def handle_event("toggle_select_all", _params, socket) do
    lobbies = socket.assigns.lobbies || []
    ids = lobby_ids(lobbies)
    selected = socket.assigns[:selected_ids] || MapSet.new()

    selected =
      if ids != [] and MapSet.size(selected) == length(ids) do
        MapSet.new()
      else
        MapSet.new(ids)
      end

    {:noreply, assign(socket, :selected_ids, selected)}
  end

  @impl true
  def handle_event("bulk_delete", _params, socket) do
    ids = socket.assigns[:selected_ids] || MapSet.new()
    ids = MapSet.to_list(ids)

    {deleted, failed} =
      Enum.reduce(ids, {0, 0}, fn id, {d, f} ->
        lobby = Lobbies.get_lobby!(id)

        case Lobbies.delete_lobby(lobby) do
          {:ok, _} -> {d + 1, f}
          {:error, _} -> {d, f + 1}
        end
      end)

    socket = assign(socket, :selected_ids, MapSet.new())

    socket =
      cond do
        failed == 0 ->
          put_flash(socket, :info, "Deleted #{deleted} lobbies")

        deleted == 0 ->
          put_flash(socket, :error, "Failed to delete selected lobbies")

        true ->
          put_flash(
            socket,
            :error,
            "Deleted #{deleted} lobbies; failed #{failed}"
          )
      end

    {:noreply, socket |> reload_lobbies()}
  end

  def handle_event("edit_lobby", %{"id" => id}, socket) do
    {lobby_id, ""} = Integer.parse(to_string(id))
    lobby = Lobbies.get_lobby!(lobby_id)
    changeset = Lobbies.change_lobby(lobby)
    form = to_form(changeset, as: "lobby")

    {:noreply, socket |> assign(:selected_lobby, lobby) |> assign(:form, form)}
  end

  def handle_event("cancel_edit", _, socket) do
    {:noreply, socket |> assign(:selected_lobby, nil) |> assign(:form, nil)}
  end

  def handle_event("admin_lobbies_prev", _params, socket) do
    page = max(1, (socket.assigns[:lobbies_page] || 1) - 1)
    {:noreply, socket |> assign(:lobbies_page, page) |> reload_lobbies()}
  end

  def handle_event("admin_lobbies_next", _params, socket) do
    page = (socket.assigns[:lobbies_page] || 1) + 1
    {:noreply, socket |> assign(:lobbies_page, page) |> reload_lobbies()}
  end

  def handle_event("save_lobby", %{"lobby" => params}, socket) do
    lobby = socket.assigns.selected_lobby

    # HTML checkboxes only send value when checked, so we must default missing keys to false
    params = Map.put_new(params, "is_hidden", "false")
    params = Map.put_new(params, "is_locked", "false")

    # Convert checkbox string values to booleans for Ecto
    params =
      params
      |> Map.update("is_hidden", false, fn v -> v in ["true", "on", true] end)
      |> Map.update("is_locked", false, fn v -> v in ["true", "on", true] end)

    # normalize metadata if provided as JSON string in the textarea
    params =
      case Map.get(params, "metadata") do
        nil ->
          params

        "" ->
          Map.put(params, "metadata", %{})

        s when is_binary(s) ->
          case Jason.decode(s) do
            {:ok, map} when is_map(map) -> Map.put(params, "metadata", map)
            _ -> Map.put(params, "metadata", %{})
          end

        other ->
          Map.put(params, "metadata", other)
      end

    res = Lobbies.update_lobby(lobby, params)

    case res do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Lobby updated")
         |> assign(:selected_lobby, nil)
         |> assign(:form, nil)
         |> reload_lobbies()}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "lobby"))}
    end
  end

  def handle_event("delete_lobby", %{"id" => id}, socket) do
    {lobby_id, ""} = Integer.parse(to_string(id))
    lobby = Lobbies.get_lobby!(lobby_id)

    case Lobbies.delete_lobby(lobby) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Lobby deleted")
         |> reload_lobbies()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete lobby")}
    end
  end

  @impl true
  def handle_info({event, _payload}, socket)
      when event in [:lobby_created, :lobby_updated, :lobby_deleted] do
    {:noreply, reload_lobbies(socket)}
  end

  defp reload_lobbies(socket) do
    page = socket.assigns[:lobbies_page] || 1
    page_size = socket.assigns[:lobbies_page_size] || 25
    filters = socket.assigns[:filters] || %{}

    lobbies =
      Lobbies.list_all_lobbies(filters, page: page, page_size: page_size)
      |> GameServer.Repo.preload(:users)

    total_count = Lobbies.count_list_all_lobbies(filters)

    total_pages =
      if page_size > 0,
        do: div(total_count + page_size - 1, page_size),
        else: 0

    socket
    |> assign(:lobbies, lobbies)
    |> assign(:count, total_count)
    |> assign(:lobbies_total_pages, total_pages)
    |> assign(:lobbies_page, page)
    |> sync_selected_ids(lobby_ids(lobbies))
  end

  defp lobby_ids(lobbies) when is_list(lobbies), do: Enum.map(lobbies, & &1.id)

  defp sync_selected_ids(socket, ids) when is_list(ids) do
    selected = socket.assigns[:selected_ids] || MapSet.new()
    allowed = MapSet.new(ids)
    assign(socket, :selected_ids, MapSet.intersection(selected, allowed))
  end
end
