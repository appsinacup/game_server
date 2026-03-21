defmodule GameServerWeb.AdminLive.Index do
  use GameServerWeb, :live_view

  alias GameServer.Accounts
  alias GameServer.Accounts.User
  alias GameServer.Accounts.UserToken
  alias GameServer.Achievements
  alias GameServer.Groups
  alias GameServer.KV
  alias GameServer.Leaderboards.Leaderboard
  alias GameServer.Lobbies.Lobby
  alias GameServer.Notifications
  alias GameServer.Parties
  alias GameServer.Repo
  alias GameServerWeb.Gettext.Stats, as: TranslationStats

  @dev_routes? Application.compile_env(:game_server_web, :dev_routes, false)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_path={assigns[:current_path]}>
      <div class="space-y-6">
        <.header>
          Admin Dashboard
          <:subtitle>System administration</:subtitle>
        </.header>

        <div class="flex gap-4 flex-wrap">
          <.link navigate={~p"/admin/config"} class="btn btn-primary">
            Configuration
          </.link>
          <.link navigate={~p"/admin/kv"} class="btn btn-primary">
            KV ({@kv_count})
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
          <.link navigate={~p"/admin/notifications"} class="btn btn-primary">
            Notifications ({@notifications_count})
          </.link>
          <.link navigate={~p"/admin/groups"} class="btn btn-primary">
            Groups ({@groups_count})
          </.link>
          <.link navigate={~p"/admin/parties"} class="btn btn-primary">
            Parties ({@parties_count})
          </.link>
          <.link navigate={~p"/admin/chat"} class="btn btn-primary">
            Chat ({@chat_count})
          </.link>
          <.link navigate={~p"/admin/achievements"} class="btn btn-primary">
            Achievements ({@achievements_count})
          </.link>
          <.link navigate={~p"/admin/connections"} class="btn btn-primary">
            Connections ({@conn_stats.total_connections})
          </.link>
          <.link navigate={~p"/admin/system"} class="btn btn-primary">
            System
          </.link>
        </div>

        <div class="card bg-base-200">
          <div class="card-body">
            <h2 class="card-title">Overview</h2>
            <p>
              Welcome to the admin dashboard. Use the buttons above to navigate to different sections.
            </p>

            <div class="mt-4 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5 gap-4">
              <%!-- 1. Users --%>
              <div class="card bg-base-100 p-4">
                <div class="flex items-center justify-between mb-2">
                  <div class="text-sm font-semibold">Users</div>
                  <.link navigate={~p"/admin/users"} class="link link-primary text-xs">
                    View →
                  </.link>
                </div>
                <div class="text-2xl font-bold">{@users_count}</div>
                <div class="text-xs text-base-content/60 mt-2 space-y-1">
                  <div>With email: {@users_password}</div>
                  <div>Google: {@users_google}</div>
                  <div>Facebook: {@users_facebook}</div>
                  <div>Discord: {@users_discord}</div>
                  <div>Apple: {@users_apple}</div>
                  <div>Steam: {@users_steam}</div>
                  <div>Device-linked: {@users_device}</div>
                </div>
              </div>

              <%!-- 2. Registration --%>
              <div class="card bg-base-100 p-4">
                <div class="text-sm font-semibold mb-2">Registration</div>
                <div class="text-xs text-base-content/60 mt-2 space-y-1">
                  <div class="font-semibold">Last 24 hours: {@users_registered_1d}</div>
                  <div class="font-semibold mt-2">
                    Last 7 days: {@users_registered_7d}
                  </div>
                  <div class="font-semibold mt-2">
                    Last 30 days: {@users_registered_30d}
                  </div>
                </div>
              </div>

              <%!-- 3. Activity --%>
              <div class="card bg-base-100 p-4">
                <div class="text-sm font-semibold mb-2">Activity</div>
                <div class="text-xs text-base-content/60 mt-2 space-y-1">
                  <div class="font-semibold">Last 24 hours: {@users_active_1d}</div>
                  <div class="font-semibold mt-2">Last 7 days: {@users_active_7d}</div>
                  <div class="font-semibold mt-2">Last 30 days: {@users_active_30d}</div>
                </div>
              </div>

              <%!-- 4. Lobbies --%>
              <div class="card bg-base-100 p-4">
                <div class="flex items-center justify-between mb-2">
                  <div class="text-sm font-semibold">Lobbies</div>
                  <.link navigate={~p"/admin/lobbies"} class="link link-primary text-xs">
                    View →
                  </.link>
                </div>
                <div class="text-2xl font-bold">{@lobbies_count}</div>
                <div class="text-xs text-base-content/60 mt-2 space-y-1">
                  <div>Hostless: {@lobbies_hostless}</div>
                  <div>Hidden: {@lobbies_hidden}</div>
                  <div>Locked: {@lobbies_locked}</div>
                  <div>With password: {@lobbies_passworded}</div>
                </div>
              </div>

              <%!-- 5. Leaderboards --%>
              <div class="card bg-base-100 p-4">
                <div class="flex items-center justify-between mb-2">
                  <div class="text-sm font-semibold">Leaderboards</div>
                  <.link navigate={~p"/admin/leaderboards"} class="link link-primary text-xs">
                    View →
                  </.link>
                </div>
                <div class="text-2xl font-bold">{@leaderboards_count}</div>
                <div class="text-xs text-base-content/60 mt-2 space-y-1">
                  <div>Scores total: {@leaderboard_records}</div>
                </div>
              </div>

              <%!-- 6. Groups --%>
              <div class="card bg-base-100 p-4">
                <div class="flex items-center justify-between mb-2">
                  <div class="text-sm font-semibold">Groups</div>
                  <.link navigate={~p"/admin/groups"} class="link link-primary text-xs">
                    View →
                  </.link>
                </div>
                <div class="text-2xl font-bold">{@groups_count}</div>
                <div class="text-xs text-base-content/60 mt-2 space-y-1">
                  <div>Public: {@groups_public}</div>
                  <div>Private: {@groups_private}</div>
                  <div>Hidden: {@groups_hidden}</div>
                  <div>Total members: {@groups_members}</div>
                </div>
              </div>

              <%!-- 7. Parties --%>
              <div class="card bg-base-100 p-4">
                <div class="flex items-center justify-between mb-2">
                  <div class="text-sm font-semibold">Parties</div>
                  <.link navigate={~p"/admin/parties"} class="link link-primary text-xs">
                    View →
                  </.link>
                </div>
                <div class="text-2xl font-bold">{@parties_count}</div>
                <div class="text-xs text-base-content/60 mt-2 space-y-1">
                  <div>Total members: {@parties_members}</div>
                </div>
              </div>

              <%!-- 8. Chat --%>
              <div class="card bg-base-100 p-4">
                <div class="flex items-center justify-between mb-2">
                  <div class="text-sm font-semibold">Chat</div>
                  <.link navigate={~p"/admin/chat"} class="link link-primary text-xs">
                    View →
                  </.link>
                </div>
                <div class="text-2xl font-bold">{@chat_count}</div>
                <div class="text-xs text-base-content/60 mt-2 space-y-1">
                  <div>Users who wrote: {@chat_senders}</div>
                  <div>Users who never wrote: {@chat_silent}</div>
                  <div>In lobbies: {@chat_by_lobby}</div>
                  <div>In groups: {@chat_by_group}</div>
                  <div>Friend DMs: {@chat_by_friend}</div>
                </div>
              </div>

              <%!-- 9. Translations --%>
              <div :for={stats <- @translation_stats} class="card bg-base-100 p-4">
                <div class="flex items-center justify-between mb-2">
                  <div class="text-sm font-semibold">
                    Translations ({String.upcase(stats.locale)})
                  </div>
                  <.link navigate={~p"/admin/translations"} class="link link-primary text-xs">
                    View →
                  </.link>
                </div>
                <div class="text-2xl font-bold">
                  {stats.percent}%
                </div>
                <div class="mt-2">
                  <div class="w-full bg-base-300 rounded-full h-2">
                    <div
                      class={[
                        "h-2 rounded-full transition-all",
                        if(stats.percent == 100.0, do: "bg-success", else: "bg-warning")
                      ]}
                      style={"width: #{stats.percent}%"}
                    >
                    </div>
                  </div>
                </div>
                <div class="text-xs text-base-content/60 mt-2 space-y-1">
                  <div>{stats.translated}/{stats.total} strings</div>
                  <div :for={d <- stats.domains}>
                    {d.domain}: {d.translated}/{d.total}
                  </div>
                </div>
              </div>

              <%!-- 10. Key-Value --%>
              <div class="card bg-base-100 p-4">
                <div class="flex items-center justify-between mb-2">
                  <div class="text-sm font-semibold">Key-Value</div>
                  <.link navigate={~p"/admin/kv"} class="link link-primary text-xs">
                    View →
                  </.link>
                </div>
                <div class="text-2xl font-bold">{@kv_count}</div>
                <div class="text-xs text-base-content/60 mt-2 space-y-1">
                  <div>Global entries: {@kv_global}</div>
                  <div>User entries: {@kv_user}</div>
                </div>
              </div>

              <%!-- 11. Achievements --%>
              <div class="card bg-base-100 p-4">
                <div class="flex items-center justify-between mb-2">
                  <div class="text-sm font-semibold">Achievements</div>
                  <.link navigate={~p"/admin/achievements"} class="link link-primary text-xs">
                    View →
                  </.link>
                </div>
                <div class="text-2xl font-bold">{@achievements_count}</div>
                <div class="text-xs text-base-content/60 mt-2 space-y-1">
                  <div>Hidden: {@achievement_stats.hidden}</div>
                  <div>Total unlocks: {@achievements_unlocks}</div>
                  <div>
                    Users with unlocks: {@achievement_stats.users_with_unlocks}
                  </div>
                  <div>
                    Avg per user: {@achievement_stats.avg_unlocks_per_user}
                  </div>
                  <%= if @achievement_stats.most_unlocked do %>
                    <div>
                      Most unlocked: {elem(@achievement_stats.most_unlocked, 1)} ({elem(
                        @achievement_stats.most_unlocked,
                        2
                      )})
                    </div>
                  <% end %>
                  <%= if @achievement_stats.least_unlocked do %>
                    <div>
                      Least unlocked: {elem(@achievement_stats.least_unlocked, 1)} ({elem(
                        @achievement_stats.least_unlocked,
                        2
                      )})
                    </div>
                  <% end %>
                </div>
              </div>

              <%!-- 12. Live Connections --%>
              <div class="card bg-base-100 p-4">
                <div class="flex items-center justify-between mb-2">
                  <div class="text-sm font-semibold">Connections</div>
                  <.link navigate={~p"/admin/connections"} class="text-xs text-primary hover:underline">
                    View →
                  </.link>
                </div>
                <div class="text-2xl font-bold">{@conn_stats.total_connections}</div>
                <div class="text-xs text-base-content/60 mt-2 space-y-1">
                  <div>WS sockets: {@conn_stats.ws_sockets}</div>
                  <div>WS channels: {@conn_stats.total_channels}</div>
                  <div>LiveViews: {@conn_stats.live_views}</div>
                  <div>WebRTC: {@conn_stats.webrtc_peers}</div>
                </div>
              </div>

              <%!-- 13. System (BEAM) --%>
              <div class="card bg-base-100 p-4">
                <div class="flex items-center justify-between mb-2">
                  <div class="text-sm font-semibold">System</div>
                  <.link navigate={~p"/admin/system"} class="text-xs text-primary hover:underline">
                    View →
                  </.link>
                </div>
                <div class="text-2xl font-bold">
                  {GameServerWeb.ConnectionTracker.format_uptime(@sys_stats.uptime_seconds)}
                </div>
                <div class="text-xs text-base-content/60 mt-2 space-y-1">
                  <div>OTP: {@sys_stats.otp_release}</div>
                  <div>Schedulers: {@sys_stats.schedulers}</div>
                  <div>Node: {@sys_stats.node}</div>
                  <div>Cluster: {@sys_stats.cluster_size} nodes</div>
                  <div>Memory: {@sys_stats.memory_total_mb} MB</div>
                  <div>
                    Processes: {@sys_stats.process_count} / {format_number(@sys_stats.process_limit)}
                  </div>
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
    notifications_count = Notifications.count_all_notifications()
    leaderboards_count = Repo.aggregate(Leaderboard, :count)
    kv_count = KV.count_entries()
    kv_global = KV.count_entries(global_only: true)
    kv_user = kv_count - kv_global

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

    # group stats
    groups_count = Groups.count_all_groups()
    groups_public = Groups.count_groups_by_type("public")
    groups_private = Groups.count_groups_by_type("private")
    groups_hidden = Groups.count_groups_by_type("hidden")
    groups_members = Groups.count_all_members()

    # party stats
    parties_count = Parties.count_all_parties()
    parties_members = Parties.count_all_party_members()

    # chat stats
    chat_count = GameServer.Chat.count_all_messages()
    chat_senders = GameServer.Chat.count_unique_senders()
    chat_by_type = GameServer.Chat.count_messages_by_type()

    # translation stats
    translation_stats = TranslationStats.all_completeness()

    # achievement stats
    achievements_count = Achievements.count_all_achievements()
    achievements_unlocks = Achievements.count_all_unlocks()
    achievement_stats = Achievements.dashboard_stats()

    # live connection & system stats (refreshed periodically)
    conn_stats = GameServerWeb.ConnectionTracker.cluster_counts()
    sys_stats = GameServerWeb.ConnectionTracker.system_stats()

    if connected?(socket), do: schedule_live_refresh()

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
       kv_count: kv_count,
       kv_global: kv_global,
       kv_user: kv_user,
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
       notifications_count: notifications_count,
       leaderboard_records: leaderboard_records,
       groups_count: groups_count,
       groups_public: groups_public,
       groups_private: groups_private,
       groups_hidden: groups_hidden,
       groups_members: groups_members,
       parties_count: parties_count,
       parties_members: parties_members,
       chat_count: chat_count,
       chat_senders: chat_senders,
       chat_silent: max(users_count - chat_senders, 0),
       chat_by_lobby: Map.get(chat_by_type, "lobby", 0),
       chat_by_group: Map.get(chat_by_type, "group", 0),
       chat_by_friend: Map.get(chat_by_type, "friend", 0),
       translation_stats: translation_stats,
       achievements_count: achievements_count,
       achievements_unlocks: achievements_unlocks,
       achievement_stats: achievement_stats,
       conn_stats: conn_stats,
       sys_stats: sys_stats,
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

  @impl true
  def handle_info(:refresh_live_stats, socket) do
    schedule_live_refresh()

    {:noreply,
     assign(socket,
       conn_stats: GameServerWeb.ConnectionTracker.cluster_counts(),
       sys_stats: GameServerWeb.ConnectionTracker.system_stats()
     )}
  end

  defp schedule_live_refresh, do: Process.send_after(self(), :refresh_live_stats, 5_000)

  defp format_number(n) when is_integer(n) and n >= 1_000_000 do
    "#{Float.round(n / 1_000_000, 1)}M"
  end

  defp format_number(n) when is_integer(n) and n >= 1_000 do
    "#{Float.round(n / 1_000, 1)}K"
  end

  defp format_number(n), do: to_string(n)
end
