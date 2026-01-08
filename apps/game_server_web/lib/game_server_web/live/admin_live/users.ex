defmodule GameServerWeb.AdminLive.Users do
  use GameServerWeb, :live_view

  alias GameServer.Accounts
  alias GameServer.Accounts.User
  alias GameServer.Repo

  import Ecto.Query

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
              <h2 class="card-title">Users ({@users_count})</h2>

              <div class="flex gap-2">
                <button
                  type="button"
                  phx-click="bulk_delete"
                  data-confirm={"Delete #{MapSet.size(@selected_ids)} selected users?"}
                  class="btn btn-sm btn-outline btn-error"
                  disabled={MapSet.size(@selected_ids) == 0}
                >
                  Delete selected ({MapSet.size(@selected_ids)})
                </button>
                <form
                  id="admin-user-search-form"
                  phx-change="search_users"
                  phx-submit="search_users"
                  class="flex items-center"
                >
                  <input
                    type="text"
                    name="q"
                    id="admin-user-search"
                    placeholder="Search by name, email, or any ID"
                    value={@search_query}
                    class="input input-sm w-64"
                  />
                </form>
                <button phx-click="clear_search" class="btn btn-sm">Clear</button>
              </div>
            </div>

            <div class="mt-2 flex items-center gap-4">
              <div class="text-sm">Filter by auth provider:</div>
              <div class="flex items-center gap-3">
                <label class="label cursor-pointer">
                  <input
                    type="checkbox"
                    phx-click="toggle_provider"
                    phx-value-provider="discord"
                    checked={"discord" in @filters}
                    class="checkbox"
                  />
                  <span class="label-text ml-2">Discord</span>
                </label>
                <label class="label cursor-pointer">
                  <input
                    type="checkbox"
                    phx-click="toggle_provider"
                    phx-value-provider="google"
                    checked={"google" in @filters}
                    class="checkbox"
                  />
                  <span class="label-text ml-2">Google</span>
                </label>
                <label class="label cursor-pointer">
                  <input
                    type="checkbox"
                    phx-click="toggle_provider"
                    phx-value-provider="apple"
                    checked={"apple" in @filters}
                    class="checkbox"
                  />
                  <span class="label-text ml-2">Apple</span>
                </label>
                <label class="label cursor-pointer">
                  <input
                    type="checkbox"
                    phx-click="toggle_provider"
                    phx-value-provider="facebook"
                    checked={"facebook" in @filters}
                    class="checkbox"
                  />
                  <span class="label-text ml-2">Facebook</span>
                </label>
                <label class="label cursor-pointer">
                  <input
                    type="checkbox"
                    phx-click="toggle_provider"
                    phx-value-provider="device"
                    checked={"device" in @filters}
                    class="checkbox"
                  />
                  <span class="label-text ml-2">Device</span>
                </label>
                <label class="label cursor-pointer">
                  <input
                    type="checkbox"
                    phx-click="toggle_provider"
                    phx-value-provider="steam"
                    checked={"steam" in @filters}
                    class="checkbox"
                  />
                  <span class="label-text ml-2">Steam</span>
                </label>
                <label class="label cursor-pointer">
                  <input
                    type="checkbox"
                    phx-click="toggle_provider"
                    phx-value-provider="email"
                    checked={"email" in @filters}
                    class="checkbox"
                  />
                  <span class="label-text ml-2">Email (password)</span>
                </label>
              </div>
            </div>
            <div class="overflow-x-auto">
              <table class="table table-zebra">
                <thead>
                  <tr>
                    <th class="w-10">
                      <input
                        type="checkbox"
                        class="checkbox checkbox-sm"
                        phx-click="toggle_select_all"
                        checked={
                          @recent_users != [] && MapSet.size(@selected_ids) == length(@recent_users)
                        }
                      />
                    </th>
                    <th>ID</th>
                    <th>Lobby ID</th>
                    <th>Email</th>
                    <th>Display Name</th>
                    <th>Discord ID</th>
                    <th>Steam ID</th>
                    <th>Device ID</th>
                    <th>Profile</th>
                    <th>Apple ID</th>
                    <th>Google ID</th>
                    <th>Facebook ID</th>
                    <th>Admin</th>
                    <th>Metadata</th>
                    <th>Confirmed</th>
                    <th>Created</th>
                    <th>Updated</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={user <- @recent_users} id={"user-#{user.id}"}>
                    <td class="w-10">
                      <input
                        type="checkbox"
                        class="checkbox checkbox-sm"
                        phx-click="toggle_select"
                        phx-value-id={user.id}
                        checked={MapSet.member?(@selected_ids, user.id)}
                      />
                    </td>
                    <td>{user.id}</td>
                    <td class="font-mono text-sm">
                      <%= if user.lobby_id do %>
                        {user.lobby_id}
                      <% else %>
                        <span class="text-gray-500">-</span>
                      <% end %>
                    </td>
                    <td class="font-mono text-sm">{user.email}</td>
                    <td class="text-sm">
                      <%= if user.display_name && user.display_name != "" do %>
                        {user.display_name}
                      <% else %>
                        <span class="text-gray-500">-</span>
                      <% end %>
                    </td>
                    <td class="font-mono text-sm">
                      <%= if user.discord_id do %>
                        {user.discord_id}
                      <% else %>
                        <span class="text-gray-500">-</span>
                      <% end %>
                    </td>
                    <td class="font-mono text-sm">
                      <%= if user.steam_id do %>
                        {user.steam_id}
                      <% else %>
                        <span class="text-gray-500">-</span>
                      <% end %>
                    </td>
                    <td class="font-mono text-sm">
                      <%= if user.device_id do %>
                        {user.device_id}
                      <% else %>
                        <span class="text-gray-500">-</span>
                      <% end %>
                    </td>
                    <td>
                      <%= if user.profile_url do %>
                        <div class="flex items-center gap-2">
                          <img src={user.profile_url} alt="avatar" class="w-8 h-8 rounded-full" />
                          <a href={user.profile_url} target="_blank" class="text-sm link">Profile</a>
                        </div>
                      <% else %>
                        <span class="text-gray-500">-</span>
                      <% end %>
                    </td>
                    <td class="font-mono text-sm">
                      <%= if user.apple_id do %>
                        {user.apple_id}
                      <% else %>
                        <span class="text-gray-500">-</span>
                      <% end %>
                    </td>
                    <td class="font-mono text-sm">
                      <%= if user.google_id do %>
                        {user.google_id}
                      <% else %>
                        <span class="text-gray-500">-</span>
                      <% end %>
                    </td>
                    <td class="font-mono text-sm">
                      <%= if user.facebook_id do %>
                        {user.facebook_id}
                      <% else %>
                        <span class="text-gray-500">-</span>
                      <% end %>
                    </td>
                    <td>
                      <%= if user.is_admin do %>
                        <span class="badge badge-success badge-sm">Yes</span>
                      <% else %>
                        <span class="badge badge-neutral badge-sm">No</span>
                      <% end %>
                    </td>
                    <td>
                      <%= if user.metadata && user.metadata != %{} do %>
                        <span class="badge badge-info badge-sm">Set</span>
                      <% else %>
                        <span class="badge badge-ghost badge-sm">Empty</span>
                      <% end %>
                    </td>
                    <td>
                      <%= if user.confirmed_at do %>
                        <span class="badge badge-success badge-sm">Yes</span>
                      <% else %>
                        <span class="badge badge-warning badge-sm">No</span>
                      <% end %>
                    </td>
                    <td class="text-sm">
                      {Calendar.strftime(user.inserted_at, "%Y-%m-%d %H:%M")}
                    </td>
                    <td class="text-sm">
                      {Calendar.strftime(user.updated_at, "%Y-%m-%d %H:%M")}
                    </td>
                    <td>
                      <button
                        phx-click="edit_user"
                        phx-value-id={user.id}
                        class="btn btn-xs btn-outline btn-info mr-2"
                      >
                        Edit
                      </button>
                      <button
                        phx-click="delete_user"
                        phx-value-id={user.id}
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
              <button phx-click="admin_users_prev" class="btn btn-xs" disabled={@users_page <= 1}>
                Prev
              </button>
              <div class="text-xs text-base-content/70">
                page {@users_page} / {@users_total_pages} ({@users_count} total)
              </div>
              <button
                phx-click="admin_users_next"
                class="btn btn-xs"
                disabled={@users_page >= @users_total_pages || @users_total_pages == 0}
              >
                Next
              </button>
            </div>
          </div>
        </div>
      </div>

      <%= if @selected_user do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg">Edit User</h3>
            <.form for={@form} id="user-form" phx-submit="save_user">
              <.input field={@form[:email]} type="email" label="Email" />
              <.input field={@form[:display_name]} type="text" label="Display name" />
              <div class="form-control">
                <label class="label cursor-pointer">
                  <span class="label-text">Admin</span>
                  <input
                    type="checkbox"
                    name="user[is_admin]"
                    class="checkbox"
                    checked={@selected_user.is_admin}
                  />
                </label>
              </div>
              <div class="form-control">
                <label class="label">
                  <span class="label-text">Metadata (JSON)</span>
                  <textarea
                    name="user[metadata]"
                    class="textarea textarea-bordered"
                    rows="4"
                  ><%= Jason.encode!(@selected_user.metadata || %{}) %></textarea>
                </label>
              </div>
              <div class="modal-action">
                <button type="button" phx-click="cancel_edit" class="btn">Cancel</button>
                <button type="submit" class="btn btn-primary">Save</button>
              </div>
            </.form>
          </div>
        </div>
      <% end %>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    # paginated admin users view (admins can see all users)
    page = 1
    page_size = 25

    {users, total_count, total_pages} =
      load_users(
        page,
        page_size,
        socket.assigns[:search_query] || "",
        socket.assigns[:filters] || []
      )

    {:ok,
     socket
     |> assign(:users_count, total_count)
     |> assign(:recent_users, users)
     |> assign(:users_page, page)
     |> assign(:users_page_size, page_size)
     |> assign(:users_total_pages, total_pages)
     |> assign(:selected_user, nil)
     |> assign(:form, nil)
     |> assign(:search_query, "")
     |> assign(:filters, [])
     |> assign(:selected_ids, MapSet.new())}
  end

  @impl true
  def handle_event("edit_user", %{"id" => id}, socket) do
    user = Accounts.get_user!(String.to_integer(id))
    changeset = User.admin_changeset(user, %{})
    form = to_form(changeset, as: "user")

    {:noreply,
     socket
     |> assign(:selected_user, user)
     |> assign(:form, form)}
  end

  # Search / filter handlers
  def handle_event("search_users", %{"q" => q}, socket) do
    page = 1
    page_size = socket.assigns[:users_page_size] || 25

    {users, total_count, total_pages} = load_users(page, page_size, q, socket.assigns[:filters])

    {:noreply,
     socket
     |> assign(:search_query, q)
     |> assign(:users_page, page)
     |> assign(:recent_users, users)
     |> assign(:users_count, total_count)
     |> assign(:users_total_pages, total_pages)
     |> sync_selected_ids(user_ids(users))}
  end

  def handle_event("clear_search", _params, socket) do
    page = 1
    page_size = socket.assigns[:users_page_size] || 25

    {users, total_count, total_pages} = load_users(page, page_size, "", [])

    {:noreply,
     socket
     |> assign(:search_query, "")
     |> assign(:filters, [])
     |> assign(:users_page, page)
     |> assign(:recent_users, users)
     |> assign(:users_count, total_count)
     |> assign(:users_total_pages, total_pages)
     |> sync_selected_ids(user_ids(users))}
  end

  def handle_event("toggle_provider", %{"provider" => provider}, socket) do
    filters = socket.assigns[:filters] || []

    filters =
      if provider in filters do
        List.delete(filters, provider)
      else
        [provider | filters]
      end

    page = 1
    page_size = socket.assigns[:users_page_size] || 25
    q = socket.assigns[:search_query] || ""

    {users, total_count, total_pages} = load_users(page, page_size, q, filters)

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:users_page, page)
     |> assign(:recent_users, users)
     |> assign(:users_count, total_count)
     |> assign(:users_total_pages, total_pages)
     |> sync_selected_ids(user_ids(users))}
  end

  def handle_event("cancel_edit", _, socket) do
    {:noreply,
     socket
     |> assign(:selected_user, nil)
     |> assign(:form, nil)}
  end

  def handle_event("save_user", %{"user" => user_params}, socket) do
    user = socket.assigns.selected_user

    attrs =
      user_params
      |> Map.put(
        "confirmed_at",
        if(user_params["confirmed"] == "on", do: DateTime.utc_now(:second), else: nil)
      )
      |> Map.put("is_admin", user_params["is_admin"] == "on")
      |> Map.update("metadata", %{}, fn metadata_str ->
        case Jason.decode(metadata_str) do
          {:ok, map} when is_map(map) -> map
          _ -> %{}
        end
      end)

    case Accounts.update_user(user, attrs) do
      {:ok, _user} ->
        # re-fetch current page of users, keeping search and filters
        page = socket.assigns[:users_page] || 1
        page_size = socket.assigns[:users_page_size] || 25

        {users, total_count, total_pages} =
          load_users(
            page,
            page_size,
            socket.assigns[:search_query] || "",
            socket.assigns[:filters] || []
          )

        {:noreply,
         socket
         |> put_flash(:info, gettext("User updated successfully"))
         |> assign(:recent_users, users)
         |> assign(:users_count, total_count)
         |> assign(:users_total_pages, total_pages)
         |> assign(:selected_user, nil)
         |> assign(:form, nil)
         |> sync_selected_ids(user_ids(users))}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "user"))}
    end
  end

  def handle_event("delete_user", %{"id" => id}, socket) do
    user = Accounts.get_user!(String.to_integer(id))

    case Accounts.delete_user(user) do
      {:ok, _user} ->
        page = socket.assigns[:users_page] || 1
        page_size = socket.assigns[:users_page_size] || 25

        {users, total_count, total_pages} =
          load_users(
            page,
            page_size,
            socket.assigns[:search_query] || "",
            socket.assigns[:filters] || []
          )

        # ensure current page is within range (if we deleted the last item on last page)
        page2 = max(1, min(page, total_pages || 1))

        {users, total_count, total_pages} =
          if page2 != page do
            load_users(
              page2,
              page_size,
              socket.assigns[:search_query] || "",
              socket.assigns[:filters] || []
            )
          else
            {users, total_count, total_pages}
          end

        {:noreply,
         socket
         |> put_flash(:info, gettext("User deleted successfully"))
         |> assign(:users_count, total_count)
         |> assign(:recent_users, users)
         |> assign(:users_page, page2)
         |> assign(:users_total_pages, total_pages)
         |> sync_selected_ids(user_ids(users))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, gettext("Failed to delete user"))}
    end
  end

  @impl true
  def handle_event("admin_users_prev", _params, socket) do
    page = max(1, (socket.assigns[:users_page] || 1) - 1)
    page_size = socket.assigns[:users_page_size] || 25

    {users, total_count, total_pages} =
      load_users(
        page,
        page_size,
        socket.assigns[:search_query] || "",
        socket.assigns[:filters] || []
      )

    {:noreply,
     socket
     |> assign(:users_page, page)
     |> assign(:recent_users, users)
     |> assign(:users_count, total_count)
     |> assign(:users_total_pages, total_pages)
     |> sync_selected_ids(user_ids(users))}
  end

  def handle_event("admin_users_next", _params, socket) do
    page = (socket.assigns[:users_page] || 1) + 1
    page_size = socket.assigns[:users_page_size] || 25

    {users, total_count, total_pages} =
      load_users(
        page,
        page_size,
        socket.assigns[:search_query] || "",
        socket.assigns[:filters] || []
      )

    {:noreply,
     socket
     |> assign(:users_page, page)
     |> assign(:recent_users, users)
     |> assign(:users_count, total_count)
     |> assign(:users_total_pages, total_pages)
     |> sync_selected_ids(user_ids(users))}
  end

  @impl true
  def handle_event("toggle_select", %{"id" => id}, socket) do
    id = String.to_integer(to_string(id))
    selected = socket.assigns[:selected_ids] || MapSet.new()

    selected =
      if MapSet.member?(selected, id) do
        MapSet.delete(selected, id)
      else
        MapSet.put(selected, id)
      end

    {:noreply,
     assign(socket, :selected_ids, selected)
     |> sync_selected_ids(user_ids(socket.assigns.recent_users))}
  end

  @impl true
  def handle_event("toggle_select_all", _params, socket) do
    users = socket.assigns.recent_users || []
    ids = user_ids(users)

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
        user = Accounts.get_user!(id)

        case Accounts.delete_user(user) do
          {:ok, _} -> {d + 1, f}
          {:error, _} -> {d, f + 1}
        end
      end)

    page = socket.assigns[:users_page] || 1
    page_size = socket.assigns[:users_page_size] || 25
    q = socket.assigns[:search_query] || ""
    filters = socket.assigns[:filters] || []

    {users, total_count, total_pages} = load_users(page, page_size, q, filters)
    page2 = max(1, min(page, total_pages || 1))

    {users, total_count, total_pages} =
      if page2 != page do
        load_users(page2, page_size, q, filters)
      else
        {users, total_count, total_pages}
      end

    socket = assign(socket, :selected_ids, MapSet.new())

    socket =
      cond do
        failed == 0 ->
          put_flash(socket, :info, gettext("Deleted %{deleted} users", deleted: deleted))

        deleted == 0 ->
          put_flash(socket, :error, gettext("Failed to delete selected users"))

        true ->
          put_flash(
            socket,
            :error,
            gettext("Deleted %{deleted} users; failed %{failed}",
              deleted: deleted,
              failed: failed
            )
          )
      end

    {:noreply,
     socket
     |> assign(:users_count, total_count)
     |> assign(:recent_users, users)
     |> assign(:users_page, page2)
     |> assign(:users_total_pages, total_pages)
     |> sync_selected_ids(user_ids(users))}
  end

  # Helper to load users with search + provider filters
  defp load_users(page, page_size, search, filters) do
    base = from(u in User)

    search_term = String.trim(search || "")

    base = apply_search(base, search_term)
    base = apply_provider_filters(base, filters)

    total_count = Repo.one(from u in base, select: count(u.id)) || 0
    total_pages = if page_size > 0, do: div(total_count + page_size - 1, page_size), else: 0

    users =
      Repo.all(
        from u in base,
          order_by: [desc: u.inserted_at],
          offset: ^((page - 1) * page_size),
          limit: ^page_size
      )

    {users, total_count, total_pages}
  end

  defp apply_search(base, search_term) do
    cond do
      search_term == "" ->
        base

      Regex.match?(~r/^\d+$/, search_term) ->
        q = "%#{search_term}%"

        # Try to parse as integer for ID lookup, but handle potential overflow
        # if the number is too large (e.g. a Google ID)
        id_query =
          try do
            id = String.to_integer(search_term)

            # Check if it fits in a 64-bit signed integer (Postgres/SQLite limit)
            if id > 9_223_372_036_854_775_807 do
              dynamic([u], false)
            else
              dynamic([u], u.id == ^id)
            end
          rescue
            ArgumentError -> dynamic([u], false)
          end

        text_query =
          dynamic(
            [u],
            fragment("LOWER(?) LIKE LOWER(?)", u.email, ^q) or
              fragment("LOWER(?) LIKE LOWER(?)", u.display_name, ^q) or
              fragment("LOWER(?) LIKE LOWER(?)", u.device_id, ^q) or
              fragment("LOWER(?) LIKE LOWER(?)", u.google_id, ^q) or
              fragment("LOWER(?) LIKE LOWER(?)", u.apple_id, ^q) or
              fragment("LOWER(?) LIKE LOWER(?)", u.facebook_id, ^q) or
              fragment("LOWER(?) LIKE LOWER(?)", u.steam_id, ^q) or
              fragment("LOWER(?) LIKE LOWER(?)", u.discord_id, ^q)
          )

        final_query = dynamic([u], ^id_query or ^text_query)

        from u in base, where: ^final_query

      true ->
        q = "%#{search_term}%"

        from u in base,
          where:
            fragment("LOWER(?) LIKE LOWER(?)", u.email, ^q) or
              fragment("LOWER(?) LIKE LOWER(?)", u.display_name, ^q) or
              fragment("LOWER(?) LIKE LOWER(?)", u.device_id, ^q) or
              fragment("LOWER(?) LIKE LOWER(?)", u.google_id, ^q) or
              fragment("LOWER(?) LIKE LOWER(?)", u.apple_id, ^q) or
              fragment("LOWER(?) LIKE LOWER(?)", u.facebook_id, ^q) or
              fragment("LOWER(?) LIKE LOWER(?)", u.steam_id, ^q) or
              fragment("LOWER(?) LIKE LOWER(?)", u.discord_id, ^q)
    end
  end

  defp apply_provider_filters(base, filters) do
    conds =
      filters
      |> Enum.map(fn
        "discord" -> dynamic([u], not is_nil(u.discord_id) and u.discord_id != "")
        "google" -> dynamic([u], not is_nil(u.google_id) and u.google_id != "")
        "apple" -> dynamic([u], not is_nil(u.apple_id) and u.apple_id != "")
        "facebook" -> dynamic([u], not is_nil(u.facebook_id) and u.facebook_id != "")
        "steam" -> dynamic([u], not is_nil(u.steam_id) and u.steam_id != "")
        "device" -> dynamic([u], not is_nil(u.device_id) and u.device_id != "")
        "email" -> dynamic([u], not is_nil(u.hashed_password) and u.hashed_password != "")
      end)

    if conds == [] do
      base
    else
      combined = Enum.reduce(conds, fn c, acc -> dynamic([u], ^acc or ^c) end)
      from u in base, where: ^combined
    end
  end

  defp user_ids(users) when is_list(users), do: Enum.map(users, & &1.id)

  defp sync_selected_ids(socket, ids) when is_list(ids) do
    selected = socket.assigns[:selected_ids] || MapSet.new()
    allowed = MapSet.new(ids)
    assign(socket, :selected_ids, MapSet.intersection(selected, allowed))
  end
end
