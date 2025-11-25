defmodule GameServerWeb.AdminLive.Index do
  use GameServerWeb, :live_view

  alias GameServer.Repo
  alias GameServer.Accounts.User
  alias GameServer.Accounts.UserToken
  alias GameServer.Lobbies.Lobby

  @dev_routes? Application.compile_env(:game_server, :dev_routes, false)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <.header>
          Admin Dashboard
          <:subtitle>System administration</:subtitle>
        </.header>

        <div class="flex gap-4 flex-wrap">
          <.link navigate={~p"/admin/config"} class="btn btn-primary">
            Configuration
          </.link>
          <.link navigate={~p"/admin/users"} class="btn btn-primary">
            Users ({@users_count})
          </.link>
          <.link navigate={~p"/admin/lobbies"} class="btn btn-primary">
            Lobbies ({@lobbies_count})
          </.link>
          <.link navigate={~p"/admin/sessions"} class="btn btn-primary">
            Tokens ({@sessions_count})
          </.link>
        </div>

        <div class="card bg-base-200">
          <div class="card-body">
            <h2 class="card-title">Overview</h2>
            <p>
              Welcome to the admin dashboard. Use the buttons above to navigate to different sections.
            </p>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    users_count = Repo.aggregate(User, :count)
    sessions_count = Repo.aggregate(UserToken, :count)

    lobbies_count = Repo.aggregate(Lobby, :count)

    {:ok,
     assign(socket,
       users_count: users_count,
       sessions_count: sessions_count,
       lobbies_count: lobbies_count,
       dev_routes?: @dev_routes?
     )}
  end

  @impl true
  def handle_event("set_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab, tab)}
  end
end
