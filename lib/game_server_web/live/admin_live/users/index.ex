defmodule GameServerWeb.AdminLive.Users.Index do
  use GameServerWeb, :live_view

  alias GameServer.Repo
  alias GameServer.Accounts
  alias GameServer.Accounts.User
  import Ecto.Query

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-4">
        <.header>
          User Management
          <:subtitle>Manage all users in the system</:subtitle>
          <:actions>
            <.link navigate={~p"/admin"} class="btn btn-ghost btn-sm">
              <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to Admin
            </.link>
          </:actions>
        </.header>

        <div class="card bg-base-200">
          <div class="card-body">
            <div class="overflow-x-auto">
              <table class="table table-zebra">
                <thead>
                  <tr>
                    <th>ID</th>
                    <th>Email</th>
                    <th>Discord Username</th>
                    <th>Discord ID</th>
                    <th>Confirmed</th>
                    <th>Created</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={user <- @users} id={"user-#{user.id}"}>
                    <td>{user.id}</td>
                    <td class="font-mono text-sm">{user.email}</td>
                    <td class="text-sm">{user.discord_username || "-"}</td>
                    <td class="font-mono text-xs">{user.discord_id || "-"}</td>
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
                    <td>
                      <div class="flex gap-2">
                        <button
                          phx-click="edit_user"
                          phx-value-id={user.id}
                          class="btn btn-sm btn-ghost"
                        >
                          <.icon name="hero-pencil" class="w-4 h-4" />
                        </button>
                        <button
                          phx-click="delete_user"
                          phx-value-id={user.id}
                          data-confirm="Are you sure you want to delete this user?"
                          class="btn btn-sm btn-error btn-ghost"
                        >
                          <.icon name="hero-trash" class="w-4 h-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <%!-- Edit User Modal --%>
        <div :if={@selected_user} class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg mb-4">Edit User #{@selected_user.id}</h3>
            <.form
              for={@form}
              id="user-form"
              phx-submit="save_user"
              class="space-y-4"
            >
              <.input
                field={@form[:email]}
                type="email"
                label="Email"
                required
              />

              <div class="form-control">
                <label class="label cursor-pointer">
                  <span class="label-text">Confirmed</span>
                  <input
                    type="checkbox"
                    name="user[confirmed]"
                    checked={!!@selected_user.confirmed_at}
                    class="checkbox"
                  />
                </label>
              </div>

              <div class="modal-action">
                <button type="button" phx-click="cancel_edit" class="btn btn-ghost">
                  Cancel
                </button>
                <button type="submit" class="btn btn-primary">
                  Save
                </button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    users = Repo.all(from u in User, order_by: [desc: u.inserted_at])

    {:ok,
     socket
     |> assign(:users, users)
     |> assign(:selected_user, nil)
     |> assign(:form, nil)}
  end

  @impl true
  def handle_event("edit_user", %{"id" => id}, socket) do
    user = Repo.get!(User, id)
    changeset = Accounts.change_user_email(user, %{}, validate_unique: false)
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
      Map.put(
        user_params,
        "confirmed_at",
        if(user_params["confirmed"] == "on", do: DateTime.utc_now(:second), else: nil)
      )

    case update_user(user, attrs) do
      {:ok, _user} ->
        users = Repo.all(from u in User, order_by: [desc: u.inserted_at])

        {:noreply,
         socket
         |> put_flash(:info, "User updated successfully")
         |> assign(:users, users)
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
        users = Repo.all(from u in User, order_by: [desc: u.inserted_at])

        {:noreply,
         socket
         |> put_flash(:info, "User deleted successfully")
         |> assign(:users, users)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete user")}
    end
  end

  defp update_user(user, attrs) do
    user
    |> Ecto.Changeset.cast(attrs, [:email, :confirmed_at])
    |> Ecto.Changeset.validate_required([:email])
    |> Ecto.Changeset.validate_format(:email, ~r/^[^\s]+@[^\s]+$/,
      message: "must be a valid email"
    )
    |> Ecto.Changeset.unique_constraint(:email)
    |> Repo.update()
  end
end
