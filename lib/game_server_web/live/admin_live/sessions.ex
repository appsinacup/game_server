defmodule GameServerWeb.AdminLive.Sessions do
  use GameServerWeb, :live_view

  alias GameServer.Accounts.UserToken
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

        <.header>
          Tokens
          <:subtitle>Manage user tokens and sessions</:subtitle>
        </.header>

        <div class="card bg-base-200">
          <div class="card-body">
            <h2 class="card-title">Active Sessions ({@sessions_count})</h2>
            <div class="overflow-x-auto">
              <table class="table table-zebra">
                <thead>
                  <tr>
                    <th>User Email</th>
                    <th>Context</th>
                    <th>Created</th>
                    <th>Last Used</th>
                    <th>Expires</th>
                    <th>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={session <- @recent_sessions} id={"session-#{session.id}"}>
                    <td class="font-mono text-sm">{session.user.email}</td>
                    <td>
                      <span class="badge badge-info badge-sm">{session.context}</span>
                    </td>
                    <td class="text-sm">
                      {Calendar.strftime(session.inserted_at, "%Y-%m-%d %H:%M")}
                    </td>
                    <td class="text-sm">
                      <%= if session.authenticated_at do %>
                        {Calendar.strftime(session.authenticated_at, "%Y-%m-%d %H:%M")}
                      <% else %>
                        <span class="text-gray-500">Never</span>
                      <% end %>
                    </td>
                    <td class="text-sm">
                      <%= if session.context == "session" do %>
                        {Calendar.strftime(
                          DateTime.add(session.inserted_at, 14, :day),
                          "%Y-%m-%d %H:%M"
                        )}
                      <% else %>
                        <span class="text-gray-500">-</span>
                      <% end %>
                    </td>
                    <td>
                      <button
                        phx-click="delete_session"
                        phx-value-id={session.id}
                        data-confirm="Are you sure you want to delete this session?"
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
              <button
                phx-click="admin_sessions_prev"
                class="btn btn-xs"
                disabled={@sessions_page <= 1}
              >
                Prev
              </button>
              <div class="text-xs text-base-content/70">
                page {@sessions_page} / {@sessions_total_pages} ({@sessions_count} total)
              </div>
              <button
                phx-click="admin_sessions_next"
                class="btn btn-xs"
                disabled={@sessions_page >= @sessions_total_pages || @sessions_total_pages == 0}
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

    sessions_count = Repo.aggregate(from(t in UserToken, where: t.context == "session"), :count)

    recent_sessions =
      Repo.all(
        from t in UserToken,
          join: u in assoc(t, :user),
          where: t.context == "session",
          order_by: [desc: t.inserted_at],
          offset: ^((page - 1) * page_size),
          limit: ^page_size,
          preload: [:user]
      )

    total_pages = if page_size > 0, do: div(sessions_count + page_size - 1, page_size), else: 0

    {:ok,
     socket
     |> assign(:sessions_count, sessions_count)
     |> assign(:recent_sessions, recent_sessions)
     |> assign(:sessions_page, page)
     |> assign(:sessions_page_size, page_size)
     |> assign(:sessions_total_pages, total_pages)}
  end

  @impl true
  def handle_event("delete_session", %{"id" => id}, socket) do
    session = Repo.get!(UserToken, id)

    case Repo.delete(session) do
      {:ok, _session} ->
        page = socket.assigns[:sessions_page] || 1
        page_size = socket.assigns[:sessions_page_size] || 50

        sessions_count =
          Repo.aggregate(from(t in UserToken, where: t.context == "session"), :count)

        total_pages =
          if page_size > 0, do: div(sessions_count + page_size - 1, page_size), else: 0

        page = max(1, min(page, total_pages || 1))

        recent_sessions =
          Repo.all(
            from t in UserToken,
              join: u in assoc(t, :user),
              where: t.context == "session",
              order_by: [desc: t.inserted_at],
              offset: ^((page - 1) * page_size),
              limit: ^page_size,
              preload: [:user]
          )

        {:noreply,
         socket
         |> put_flash(:info, "Token deleted successfully")
         |> assign(:sessions_count, sessions_count)
         |> assign(:recent_sessions, recent_sessions)
         |> assign(:sessions_page, page)
         |> assign(:sessions_total_pages, total_pages)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete token")}
    end
  end

  @impl true
  def handle_event("admin_sessions_prev", _params, socket) do
    page = max(1, (socket.assigns[:sessions_page] || 1) - 1)
    page_size = socket.assigns[:sessions_page_size] || 50

    recent_sessions =
      Repo.all(
        from t in UserToken,
          join: u in assoc(t, :user),
          where: t.context == "session",
          order_by: [desc: t.inserted_at],
          offset: ^((page - 1) * page_size),
          limit: ^page_size,
          preload: [:user]
      )

    sessions_count = Repo.aggregate(from(t in UserToken, where: t.context == "session"), :count)
    total_pages = if page_size > 0, do: div(sessions_count + page_size - 1, page_size), else: 0

    {:noreply,
     socket
     |> assign(:sessions_page, page)
     |> assign(:recent_sessions, recent_sessions)
     |> assign(:sessions_count, sessions_count)
     |> assign(:sessions_total_pages, total_pages)}
  end

  def handle_event("admin_sessions_next", _params, socket) do
    page = (socket.assigns[:sessions_page] || 1) + 1
    page_size = socket.assigns[:sessions_page_size] || 50

    recent_sessions =
      Repo.all(
        from t in UserToken,
          join: u in assoc(t, :user),
          where: t.context == "session",
          order_by: [desc: t.inserted_at],
          offset: ^((page - 1) * page_size),
          limit: ^page_size,
          preload: [:user]
      )

    sessions_count = Repo.aggregate(from(t in UserToken, where: t.context == "session"), :count)
    total_pages = if page_size > 0, do: div(sessions_count + page_size - 1, page_size), else: 0

    {:noreply,
     socket
     |> assign(:sessions_page, page)
     |> assign(:recent_sessions, recent_sessions)
     |> assign(:sessions_count, sessions_count)
     |> assign(:sessions_total_pages, total_pages)}
  end
end
