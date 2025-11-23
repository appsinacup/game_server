defmodule GameServerWeb.AdminLive.Users do
  use GameServerWeb, :live_view

  alias GameServer.Repo
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
                    <th>Discord ID</th>
                    <th>Discord Username</th>
                    <th>Discord Avatar</th>
                    <th>Apple ID</th>
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
                    <td class="font-mono text-sm">
                      <%= if user.discord_id do %>
                        {user.discord_id}
                      <% else %>
                        <span class="text-gray-500">-</span>
                      <% end %>
                    </td>
                    <td>
                      <%= if user.discord_username do %>
                        {user.discord_username}
                      <% else %>
                        <span class="text-gray-500">-</span>
                      <% end %>
                    </td>
                    <td>
                      <%= if user.discord_avatar do %>
                        <% avatar_src =
                          if String.starts_with?(user.discord_avatar, "http") do
                            user.discord_avatar
                          else
                            ext =
                              if String.starts_with?(user.discord_avatar, "a_"),
                                do: ".gif",
                                else: ".png"

                            "https://cdn.discordapp.com/avatars/#{user.discord_id}/#{user.discord_avatar}#{ext}"
                          end %>

                        <img src={avatar_src} alt="Discord Avatar" class="w-8 h-8 rounded-full" />
                      <% else %>
                        <span class="badge badge-ghost badge-sm">Not set</span>
                      <% end %>
                    </td>
                    <td class="font-mono text-sm">
                      <%= if user.apple_id do %>
                        {user.apple_id}
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
                        class="btn btn-xs btn-outline btn-error"
                        onclick="return confirm('Are you sure?')"
                      >
                        Delete
                      </button>
                    </td>
                  </tr>
                </tbody>
              </table>
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
    users_count = Repo.aggregate(User, :count)
    recent_users = Repo.all(from u in User, order_by: [desc: u.inserted_at], limit: 10)

    {:ok,
     socket
     |> assign(:users_count, users_count)
     |> assign(:recent_users, recent_users)
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

    case User.admin_changeset(user, attrs) |> Repo.update() do
      {:ok, _user} ->
        recent_users = Repo.all(from u in User, order_by: [desc: u.inserted_at], limit: 10)

        {:noreply,
         socket
         |> put_flash(:info, "User updated successfully")
         |> assign(:recent_users, recent_users)
         |> assign(:selected_user, nil)
         |> assign(:form, nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "user"))}
    end
  end

  def handle_event("delete_user", %{"id" => id}, socket) do
    user = Repo.get!(User, id)

    case Repo.delete(user) do
      {:ok, _user} ->
        users_count = Repo.aggregate(User, :count)
        recent_users = Repo.all(from u in User, order_by: [desc: u.inserted_at], limit: 10)

        {:noreply,
         socket
         |> put_flash(:info, "User deleted successfully")
         |> assign(:users_count, users_count)
         |> assign(:recent_users, recent_users)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete user")}
    end
  end
end
