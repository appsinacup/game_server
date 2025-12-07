defmodule GameServerWeb.AdminLive.Index do
  use GameServerWeb, :live_view

  alias GameServer.Accounts
  alias GameServer.Accounts.User
  alias GameServer.Accounts.UserToken
  alias GameServer.Leaderboards.Leaderboard
  alias GameServer.Lobbies.Lobby
  alias GameServer.Repo

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
          <.link navigate={~p"/admin/leaderboards"} class="btn btn-primary">
            Leaderboards ({@leaderboards_count})
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

            <div class="mt-4 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5 gap-4">
              <div class="card bg-base-100 p-4">
                <div class="text-sm font-semibold mb-2">Users</div>
                <div class="text-2xl font-bold">{@users_count}</div>
                <div class="text-xs text-base-content/60 mt-2 space-y-1">
                  <div>With password: {@users_password}</div>
                  <div>Google: {@users_google}</div>
                  <div>Facebook: {@users_facebook}</div>
                  <div>Discord: {@users_discord}</div>
                  <div>Apple: {@users_apple}</div>
                  <div>Steam: {@users_steam}</div>
                  <div>Device-linked: {@users_device}</div>
                </div>
              </div>

              <div class="card bg-base-100 p-4">
                <div class="text-sm font-semibold mb-2">Lobbies</div>
                <div class="text-2xl font-bold">{@lobbies_count}</div>
                <div class="text-xs text-base-content/60 mt-2 space-y-1">
                  <div>Hostless: {@lobbies_hostless}</div>
                  <div>Hidden: {@lobbies_hidden}</div>
                  <div>Locked: {@lobbies_locked}</div>
                  <div>With password: {@lobbies_passworded}</div>
                </div>
              </div>

              <div class="card bg-base-100 p-4">
                <div class="text-sm font-semibold mb-2">Leaderboards</div>
                <div class="text-2xl font-bold">{@leaderboards_count}</div>
                <div class="text-xs text-base-content/60 mt-2 space-y-1">
                  <div>Scores total: {@leaderboard_records}</div>
                </div>
              </div>

              <div class="card bg-base-100 p-4">
                <div class="text-sm font-semibold mb-2">Registration</div>
                <div class="text-xs text-base-content/60 mt-2 space-y-1">
                  <div class="font-semibold">Last 24 hours</div>
                  <div class="text-lg">{@users_registered_1d}</div>
                  <div class="font-semibold mt-2">Last 7 days</div>
                  <div class="text-lg">{@users_registered_7d}</div>
                  <div class="font-semibold mt-2">Last 30 days</div>
                  <div class="text-lg">{@users_registered_30d}</div>
                </div>
              </div>

              <div class="card bg-base-100 p-4">
                <div class="text-sm font-semibold mb-2">Activity</div>
                <div class="text-xs text-base-content/60 mt-2 space-y-1">
                  <div class="font-semibold">Last 24 hours</div>
                  <div class="text-lg">{@users_active_1d}</div>
                  <div class="font-semibold mt-2">Last 7 days</div>
                  <div class="text-lg">{@users_active_7d}</div>
                  <div class="font-semibold mt-2">Last 30 days</div>
                  <div class="text-lg">{@users_active_30d}</div>
                </div>
              </div>
            </div>
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
    leaderboards_count = Repo.aggregate(Leaderboard, :count)

    # finer-grained stats
    users_google = Accounts.count_users_with_provider(:google_id)
    users_facebook = Accounts.count_users_with_provider(:facebook_id)
    users_discord = Accounts.count_users_with_provider(:discord_id)
    users_apple = Accounts.count_users_with_provider(:apple_id)
    users_steam = Accounts.count_users_with_provider(:steam_id)
    users_device = Accounts.count_users_with_provider(:device_id)
    users_password = Accounts.count_users_with_password()

    lobbies_hostless = GameServer.Lobbies.count_hostless_lobbies()
    lobbies_hidden = GameServer.Lobbies.count_hidden_lobbies()
    lobbies_locked = GameServer.Lobbies.count_locked_lobbies()
    lobbies_passworded = GameServer.Lobbies.count_passworded_lobbies()

    leaderboard_records = GameServer.Leaderboards.count_all_records()

    # time-based metrics
    users_registered_1d = Accounts.count_users_registered_since(1)
    users_registered_7d = Accounts.count_users_registered_since(7)
    users_registered_30d = Accounts.count_users_registered_since(30)
    users_active_1d = Accounts.count_users_active_since(1)
    users_active_7d = Accounts.count_users_active_since(7)
    users_active_30d = Accounts.count_users_active_since(30)

    {:ok,
     assign(socket,
       users_count: users_count,
       sessions_count: sessions_count,
       lobbies_count: lobbies_count,
       leaderboards_count: leaderboards_count,
       users_google: users_google,
       users_facebook: users_facebook,
       users_discord: users_discord,
       users_apple: users_apple,
       users_steam: users_steam,
       users_device: users_device,
       users_password: users_password,
       lobbies_hostless: lobbies_hostless,
       lobbies_hidden: lobbies_hidden,
       lobbies_locked: lobbies_locked,
       lobbies_passworded: lobbies_passworded,
       leaderboard_records: leaderboard_records,
       users_registered_1d: users_registered_1d,
       users_registered_7d: users_registered_7d,
       users_registered_30d: users_registered_30d,
       users_active_1d: users_active_1d,
       users_active_7d: users_active_7d,
       users_active_30d: users_active_30d,
       dev_routes?: @dev_routes?
     )}
  end

  @impl true
  def handle_event("set_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :tab, tab)}
  end
end
