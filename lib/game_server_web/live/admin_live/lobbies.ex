defmodule GameServerWeb.AdminLive.Lobbies do
  use GameServerWeb, :live_view

  alias GameServer.Lobbies

  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to lobby pubsub so admin UI updates live when lobbies are
    # created/updated/deleted by API/quick_join flows.
    Lobbies.subscribe_lobbies()
    # Admin sees ALL lobbies including hidden ones (paginated)
    lobbies_page = 1
    lobbies_page_size = 25

    lobbies =
      Lobbies.list_all_lobbies(page: lobbies_page, page_size: lobbies_page_size)
      |> GameServer.Repo.preload(:users)

    total_count = GameServer.Repo.aggregate(GameServer.Lobbies.Lobby, :count, :id)

    total_pages =
      if lobbies_page_size > 0,
        do: div(total_count + lobbies_page_size - 1, lobbies_page_size),
        else: 0

    {:ok,
     socket
     |> assign(:lobbies, lobbies)
     |> assign(:count, total_count)
     |> assign(:lobbies_total_pages, total_pages)
     |> assign(:lobbies_page, lobbies_page)
     |> assign(:lobbies_page_size, lobbies_page_size)
     |> assign(:selected_lobby, nil)
     |> assign(:form, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <.link navigate={~p"/admin"} class="btn btn-outline mb-4">← Back to Admin</.link>

        <.header>
          Lobbies
          <:subtitle>Manage game lobbies</:subtitle>
        </.header>

        <div class="card bg-base-200">
          <div class="card-body">
            <h2 class="card-title">Lobbies ({@count})</h2>

            <div class="overflow-x-auto mt-4">
              <table class="table table-zebra w-full">
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Title</th>
                    <th>Host ID</th>
                    <th>Users</th>
                    <th>Hidden</th>
                    <th>Locked</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={l <- @lobbies} id={"admin-lobby-" <> to_string(l.id)}>
                    <td class="font-mono text-sm">{l.id}</td>
                    <td class="text-sm">{l.title || "-"}</td>
                    <td class="font-mono text-sm">{l.host_id}</td>
                    <td class="text-sm">{length(l.users || [])}</td>
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
                      <button
                        phx-click="edit_lobby"
                        phx-value-id={l.id}
                        class="btn btn-xs btn-outline btn-info mr-2"
                      >
                        Edit
                      </button>
                      <button
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
  def handle_event("edit_lobby", %{"id" => id}, socket) do
    lobby = Lobbies.get_lobby!(id)
    changeset = Lobbies.change_lobby(lobby)
    form = to_form(changeset, as: "lobby")

    {:noreply, socket |> assign(:selected_lobby, lobby) |> assign(:form, form)}
  end

  def handle_event("cancel_edit", _, socket) do
    {:noreply, socket |> assign(:selected_lobby, nil) |> assign(:form, nil)}
  end

  def handle_event("admin_lobbies_prev", _params, socket) do
    page = max(1, (socket.assigns[:lobbies_page] || 1) - 1)

    lobbies =
      Lobbies.list_all_lobbies(page: page, page_size: socket.assigns[:lobbies_page_size] || 25)
      |> GameServer.Repo.preload(:users)

    total_count = GameServer.Repo.aggregate(GameServer.Lobbies.Lobby, :count, :id)

    total_pages =
      if (socket.assigns[:lobbies_page_size] || 25) > 0,
        do:
          div(
            total_count + (socket.assigns[:lobbies_page_size] || 25) - 1,
            socket.assigns[:lobbies_page_size] || 25
          ),
        else: 0

    {:noreply,
     socket
     |> assign(:lobbies_page, page)
     |> assign(:lobbies, lobbies)
     |> assign(:count, total_count)
     |> assign(:lobbies_total_pages, total_pages)}
  end

  def handle_event("admin_lobbies_next", _params, socket) do
    page = (socket.assigns[:lobbies_page] || 1) + 1

    lobbies =
      Lobbies.list_all_lobbies(page: page, page_size: socket.assigns[:lobbies_page_size] || 25)
      |> GameServer.Repo.preload(:users)

    total_count = GameServer.Repo.aggregate(GameServer.Lobbies.Lobby, :count, :id)

    total_pages =
      if (socket.assigns[:lobbies_page_size] || 25) > 0,
        do:
          div(
            total_count + (socket.assigns[:lobbies_page_size] || 25) - 1,
            socket.assigns[:lobbies_page_size] || 25
          ),
        else: 0

    {:noreply,
     socket
     |> assign(:lobbies_page, page)
     |> assign(:lobbies, lobbies)
     |> assign(:count, total_count)
     |> assign(:lobbies_total_pages, total_pages)}
  end

  @impl true
  def handle_info({event, _payload}, socket)
      when event in [:lobby_created, :lobby_updated, :lobby_deleted] do
    page = socket.assigns[:lobbies_page] || 1
    page_size = socket.assigns[:lobbies_page_size] || 25

    lobbies =
      Lobbies.list_all_lobbies(page: page, page_size: page_size)
      |> GameServer.Repo.preload(:users)

    total_count = GameServer.Repo.aggregate(GameServer.Lobbies.Lobby, :count, :id)

    total_pages =
      if page_size > 0, do: div(total_count + page_size - 1, page_size), else: 0

    {:noreply,
     socket
     |> assign(:lobbies_page, page)
     |> assign(:lobbies, lobbies)
     |> assign(:count, total_count)
     |> assign(:lobbies_total_pages, total_pages)}
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
        lobbies =
          Lobbies.list_all_lobbies(
            page: socket.assigns.lobbies_page || 1,
            page_size: socket.assigns.lobbies_page_size || 25
          )
          |> GameServer.Repo.preload(:users)

        total_count = GameServer.Repo.aggregate(GameServer.Lobbies.Lobby, :count, :id)

        {:noreply,
         socket
         |> put_flash(:info, "Lobby updated")
         |> assign(:lobbies, lobbies)
         |> assign(:count, total_count)
         |> assign(:selected_lobby, nil)
         |> assign(:form, nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "lobby"))}
    end
  end

  def handle_event("delete_lobby", %{"id" => id}, socket) do
    lobby = Lobbies.get_lobby!(id)

    case Lobbies.delete_lobby(lobby) do
      {:ok, _} ->
        lobbies =
          Lobbies.list_all_lobbies(
            page: socket.assigns.lobbies_page || 1,
            page_size: socket.assigns.lobbies_page_size || 25
          )
          |> GameServer.Repo.preload(:users)

        total_count = GameServer.Repo.aggregate(GameServer.Lobbies.Lobby, :count, :id)

        {:noreply,
         socket
         |> put_flash(:info, "Lobby deleted")
         |> assign(:lobbies, lobbies)
         |> assign(:count, total_count)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete lobby")}
    end
  end
end
