defmodule GameServerWeb.AdminLive.Users do
  use GameServerWeb, :live_view

  alias GameServer.Repo
  alias GameServer.Accounts
  alias GameServer.Accounts.User

  import Ecto.Query

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <.link navigate={~p"/admin"} class="btn btn-outline mb-4">
          ← Back to Admin
        </.link>

        <.header>
          Users
          <:subtitle>Manage system users</:subtitle>
        </.header>

        <div class="card bg-base-200">
          <div class="card-body">
            <h2 class="card-title">Users ({@users_count})</h2>
            <div class="overflow-x-auto">
              <table class="table table-zebra">
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Email</th>
                    <th>Display Name</th>
                    <th>Discord ID</th>
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
                    <td>{user.id}</td>
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
              <button phx-click="admin_users_prev" class="btn btn-xs" disabled={@users_page <= 1}>Prev</button>
              <div class="text-xs text-base-content/70">page {@users_page} / {@users_total_pages} ({@users_count} total)</div>
              <button phx-click="admin_users_next" class="btn btn-xs" disabled={@users_page >= @users_total_pages || @users_total_pages == 0}>Next</button>
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
              <div class="form-control">
                <label class="label cursor-pointer">
                  <span class="label-text">Confirmed</span>
                  <input
                    type="checkbox"
                    name="user[confirmed]"
                    class="checkbox"
                    checked={@selected_user.confirmed_at != nil}
                  />
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

    users =
      Repo.all(from u in User, order_by: [desc: u.inserted_at], offset: ^((page - 1) * page_size), limit: ^page_size)

    total_count = Repo.aggregate(User, :count)
    total_pages = if page_size > 0, do: div(total_count + page_size - 1, page_size), else: 0

    {:ok,
     socket
     |> assign(:users_count, total_count)
     |> assign(:recent_users, users)
     |> assign(:users_page, page)
     |> assign(:users_page_size, page_size)
     |> assign(:users_total_pages, total_pages)
     |> assign(:selected_user, nil)
     |> assign(:form, nil)}
  end

  @impl true
  def handle_event("edit_user", %{"id" => id}, socket) do
    user = Repo.get!(User, id)
    changeset = User.admin_changeset(user, %{})
    form = to_form(changeset, as: "user")

    {:noreply,
     socket
     |> assign(:selected_user, user)
     |> assign(:form, form)}
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

    case Accounts.update_user_admin(user, attrs) do
      {:ok, _user} ->
        # re-fetch current page of users
        page = socket.assigns[:users_page] || 1
        page_size = socket.assigns[:users_page_size] || 25

        users =
          Repo.all(from u in User, order_by: [desc: u.inserted_at], offset: ^((page - 1) * page_size), limit: ^page_size)

        total_count = Repo.aggregate(User, :count)
        total_pages = if page_size > 0, do: div(total_count + page_size - 1, page_size), else: 0

        {:noreply,
         socket
         |> put_flash(:info, "User updated successfully")
         |> assign(:recent_users, users)
         |> assign(:users_count, total_count)
         |> assign(:users_total_pages, total_pages)
         |> assign(:selected_user, nil)
         |> assign(:form, nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "user"))}
    end

  end

  def handle_event("delete_user", %{"id" => id}, socket) do
    user = Repo.get!(User, id)

    case Accounts.delete_user(user) do
      {:ok, _user} ->
        page = socket.assigns[:users_page] || 1
        page_size = socket.assigns[:users_page_size] || 25

        total_count = Repo.aggregate(User, :count)
        total_pages = if page_size > 0, do: div(total_count + page_size - 1, page_size), else: 0

        # ensure current page is within range (if we deleted the last item on last page)
        page = max(1, min(page, total_pages || 1))

        users =
          Repo.all(from u in User, order_by: [desc: u.inserted_at], offset: ^((page - 1) * page_size), limit: ^page_size)

        {:noreply,
         socket
         |> put_flash(:info, "User deleted successfully")
         |> assign(:users_count, total_count)
         |> assign(:recent_users, users)
         |> assign(:users_page, page)
         |> assign(:users_total_pages, total_pages)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete user")}
    end
  end
  @impl true
  def handle_event("admin_users_prev", _params, socket) do
    page = max(1, (socket.assigns[:users_page] || 1) - 1)
    page_size = socket.assigns[:users_page_size] || 25

    users =
      Repo.all(from u in User, order_by: [desc: u.inserted_at], offset: ^((page - 1) * page_size), limit: ^page_size)

    total_count = Repo.aggregate(User, :count)
    total_pages = if page_size > 0, do: div(total_count + page_size - 1, page_size), else: 0

    {:noreply,
     socket
     |> assign(:users_page, page)
     |> assign(:recent_users, users)
     |> assign(:users_count, total_count)
     |> assign(:users_total_pages, total_pages)}
  end

  def handle_event("admin_users_next", _params, socket) do
    page = (socket.assigns[:users_page] || 1) + 1
    page_size = socket.assigns[:users_page_size] || 25

    users =
      Repo.all(from u in User, order_by: [desc: u.inserted_at], offset: ^((page - 1) * page_size), limit: ^page_size)

    total_count = Repo.aggregate(User, :count)
    total_pages = if page_size > 0, do: div(total_count + page_size - 1, page_size), else: 0

    {:noreply,
     socket
     |> assign(:users_page, page)
     |> assign(:recent_users, users)
     |> assign(:users_count, total_count)
     |> assign(:users_total_pages, total_pages)}
  end

  end
