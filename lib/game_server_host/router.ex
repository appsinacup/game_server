defmodule GameServerHost.Router do
  @moduledoc """
  Host-owned router for the running application.

  Routes are defined directly here and reference reusable controllers,
  LiveViews, and plugs from `game_server_web`.
  """

  use GameServerWeb, :router

  import GameServerWeb.UserAuth
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GameServerWeb.Layouts, :root}
    plug :protect_from_forgery

    plug :put_secure_browser_headers, %{
      "content-security-policy" =>
        "default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' wss:; font-src 'self' data:; frame-src 'self' blob:; frame-ancestors 'self'"
    }

    plug GameServerWeb.Plugs.ColorMode
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug OpenApiSpex.Plug.PutApiSpec, module: GameServerWeb.ApiSpec
  end

  pipeline :oauth_callback do
    plug :accepts, ["html", "json"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GameServerWeb.Layouts, :root}

    plug :put_secure_browser_headers, %{
      "content-security-policy" =>
        "default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' wss:; font-src 'self' data:; frame-src 'self' blob:; frame-ancestors 'self'"
    }

    plug GameServerWeb.Plugs.ColorMode
    plug :fetch_current_scope_for_user
  end

  pipeline :api_auth do
    plug GameServerWeb.Auth.Pipeline
  end

  pipeline :api_optional_auth do
    plug GameServerWeb.Auth.OptionalPipeline
  end

  pipeline :api_admin do
    plug GameServerWeb.Plugs.RequireAdminApi
  end

  pipeline :mailbox_preview_enabled do
    plug GameServerWeb.Plugs.MailboxPreviewEnabled
  end

  pipeline :swagger_browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GameServerWeb.Layouts, :root}
    plug :protect_from_forgery

    plug :put_secure_browser_headers, %{
      "content-security-policy" =>
        "default-src 'self'; script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; img-src 'self' data: https:; connect-src 'self' wss:; font-src 'self' data:; frame-src 'self' blob:; frame-ancestors 'self'"
    }

    plug :fetch_current_scope_for_user
  end

  pipeline :openapi_gate do
    plug GameServerWeb.Plugs.FeatureGate, env: "OPENAPI_ENABLED", default: true
  end

  pipeline :metrics_auth do
    plug GameServerWeb.Plugs.MetricsAuth
  end

  scope "/content", GameServerWeb do
    get "/:type/*path", HostContentAssetController, :show
  end

  scope "/", GameServerWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/privacy", PageController, :privacy
    get "/data-deletion", PageController, :data_deletion
    get "/terms", PageController, :terms
  end

  scope "/" do
    pipe_through :browser

    get "/sitemap.xml", GameServerHost.SitemapController, :index
  end

  scope "/api" do
    pipe_through [:api, :openapi_gate]

    get "/openapi", OpenApiSpex.Plug.RenderSpec, []
  end

  scope "/api" do
    pipe_through [:swagger_browser, :openapi_gate]

    get "/docs", GameServerWeb.SwaggerController, :index
  end

  scope "/api/v1", GameServerWeb.Api.V1, as: :api_v1 do
    pipe_through :api

    get "/health", HealthController, :index
    get "/users", UserController, :index
    get "/users/:id", UserController, :show
    post "/login", SessionController, :create
    post "/login/device", SessionController, :create_device
    post "/refresh", SessionController, :refresh
    delete "/logout", SessionController, :delete
    get "/lobbies", LobbyController, :index

    get "/leaderboards", LeaderboardController, :index
    post "/leaderboards/resolve", LeaderboardController, :resolve
    get "/leaderboards/:id", LeaderboardController, :show
    get "/leaderboards/:id/records", LeaderboardController, :records
    get "/leaderboards/:id/records/around/:user_id", LeaderboardController, :around
    get "/groups", GroupController, :index
  end

  scope "/api/v1", GameServerWeb.Api.V1, as: :api_v1 do
    pipe_through [:api, :api_auth]

    get "/achievements/me", AchievementController, :me
  end

  scope "/api/v1", GameServerWeb.Api.V1, as: :api_v1 do
    pipe_through [:api, :api_optional_auth]

    get "/achievements", AchievementController, :index
    get "/achievements/user/:user_id", AchievementController, :user_achievements
    get "/achievements/:slug", AchievementController, :show
  end

  scope "/api/v1", GameServerWeb.Api.V1, as: :api_v1 do
    pipe_through [:api, :api_auth]

    get "/groups/invitations", GroupController, :invitations
    post "/groups/invitations/:invite_id/accept", GroupController, :accept_invite
    post "/groups/invitations/:invite_id/decline", GroupController, :decline_invite
    get "/groups/me", GroupController, :my_groups
    get "/groups/sent_invitations", GroupController, :sent_invitations
    delete "/groups/sent_invitations/:invite_id", GroupController, :cancel_invite
  end

  scope "/api/v1", GameServerWeb.Api.V1, as: :api_v1 do
    pipe_through :api

    get "/groups/:id", GroupController, :show
    get "/groups/:id/members", GroupController, :members
  end

  scope "/api/v1", GameServerWeb.Api.V1, as: :api_v1 do
    pipe_through [:api, :api_auth]

    get "/kv/:key", KvController, :show
  end

  scope "/api/v1", GameServerWeb.Api.V1, as: :api_v1 do
    pipe_through [:api, :api_auth]

    get "/me", MeController, :show
    delete "/me", MeController, :delete
    get "/lobbies/:id", LobbyController, :show
    post "/lobbies", LobbyController, :create
    post "/lobbies/quick_join", LobbyController, :quick_join
    patch "/lobbies", LobbyController, :update
    post "/lobbies/:id/join", LobbyController, :join
    post "/lobbies/leave", LobbyController, :leave
    post "/lobbies/kick", LobbyController, :kick
    patch "/me/password", MeController, :update_password
    patch "/me/display_name", MeController, :update_display_name
    delete "/me/providers/:provider", ProviderController, :unlink
    post "/me/device", ProviderController, :link_device
    delete "/me/device", ProviderController, :unlink_device
    post "/friends", FriendController, :create
    get "/me/friends", FriendController, :index
    get "/me/friend-requests", FriendController, :requests
    get "/me/blocked", FriendController, :blocked
    post "/friends/:id/accept", FriendController, :accept
    post "/friends/:id/reject", FriendController, :reject
    post "/friends/:id/block", FriendController, :block
    post "/friends/:id/unblock", FriendController, :unblock
    delete "/friends/:id", FriendController, :delete
    get "/notifications", NotificationController, :index
    post "/notifications", NotificationController, :create
    delete "/notifications", NotificationController, :delete
    post "/groups", GroupController, :create
    patch "/groups/:id", GroupController, :update
    post "/groups/:id/join", GroupController, :join
    post "/groups/:id/leave", GroupController, :leave
    post "/groups/:id/kick", GroupController, :kick
    post "/groups/:id/promote", GroupController, :promote
    post "/groups/:id/demote", GroupController, :demote
    get "/groups/:id/join_requests", GroupController, :join_requests
    post "/groups/:id/join_requests/:request_id/approve", GroupController, :approve_request
    post "/groups/:id/join_requests/:request_id/reject", GroupController, :reject_request
    delete "/groups/:id/join_requests/:request_id", GroupController, :cancel_request
    post "/groups/:id/invite", GroupController, :invite
    post "/groups/:id/notify", GroupController, :notify_group
    get "/hooks", HookController, :index
    post "/hooks/call", HookController, :invoke
    get "/leaderboards/:id/records/me", LeaderboardController, :me
    get "/parties/me", PartyController, :show
    post "/parties", PartyController, :create
    patch "/parties", PartyController, :update
    post "/parties/leave", PartyController, :leave
    post "/parties/kick", PartyController, :kick
    post "/parties/invite", PartyController, :invite
    post "/parties/invite/cancel", PartyController, :cancel_party_invite
    post "/parties/invite/accept", PartyController, :accept_party_invite
    post "/parties/invite/decline", PartyController, :decline_party_invite
    get "/parties/invitations", PartyController, :list_invitations
    get "/parties/invitations/sent", PartyController, :list_sent_invitations
    post "/parties/create_lobby", PartyController, :create_lobby
    post "/parties/join_lobby/:id", PartyController, :join_lobby
    get "/chat/messages", ChatController, :index
    get "/chat/messages/:id", ChatController, :show
    post "/chat/messages", ChatController, :send
    patch "/chat/messages/:id", ChatController, :update
    delete "/chat/messages/:id", ChatController, :delete
    post "/chat/read", ChatController, :mark_read
    get "/chat/unread", ChatController, :unread
  end

  scope "/api/v1/admin", GameServerWeb.Api.V1.Admin, as: :api_v1_admin do
    pipe_through [:api, :api_auth, :api_admin]

    get "/kv/entries", KvEntryController, :index
    post "/kv/entries", KvEntryController, :create
    patch "/kv/entries/:id", KvEntryController, :update
    delete "/kv/entries/:id", KvEntryController, :delete
    put "/kv", KvController, :upsert
    delete "/kv", KvController, :delete
    post "/leaderboards", LeaderboardController, :create
    patch "/leaderboards/:id", LeaderboardController, :update
    post "/leaderboards/:id/end", LeaderboardController, :end_leaderboard
    delete "/leaderboards/:id", LeaderboardController, :delete
    post "/leaderboards/:id/records", LeaderboardRecordController, :create
    patch "/leaderboards/:id/records/:record_id", LeaderboardRecordController, :update
    delete "/leaderboards/:id/records/:record_id", LeaderboardRecordController, :delete
    delete "/leaderboards/:id/records/user/:user_id", LeaderboardRecordController, :delete_user
    get "/lobbies", LobbyController, :index
    patch "/lobbies/:id", LobbyController, :update
    delete "/lobbies/:id", LobbyController, :delete
    patch "/users/:id", UserController, :update
    delete "/users/:id", UserController, :delete
    get "/notifications", NotificationController, :index
    post "/notifications", NotificationController, :create
    delete "/notifications/:id", NotificationController, :delete
    get "/groups", GroupController, :index
    patch "/groups/:id", GroupController, :update
    delete "/groups/:id", GroupController, :delete
    get "/sessions", SessionController, :index
    delete "/sessions/:id", SessionController, :delete
    delete "/users/:id/sessions", SessionController, :delete_user_sessions
    get "/chat", ChatController, :index
    delete "/chat/:id", ChatController, :delete
    delete "/chat/conversation", ChatController, :delete_conversation
    get "/achievements", AchievementController, :index
    post "/achievements", AchievementController, :create
    patch "/achievements/:id", AchievementController, :update
    delete "/achievements/:id", AchievementController, :delete
    post "/achievements/grant", AchievementController, :grant
    post "/achievements/revoke", AchievementController, :revoke
    post "/achievements/unlock", AchievementController, :unlock
    post "/achievements/increment", AchievementController, :increment
  end

  scope "/api/v1/auth", GameServerWeb do
    pipe_through :api

    get "/:provider", AuthController, :api_request
    post "/:provider/callback", AuthController, :api_callback
    post "/apple/ios/callback", AuthController, :api_apple_ios_callback
    post "/google/id_token", AuthController, :api_google_id_token
    get "/session/:session_id", AuthController, :api_session_status
  end

  scope "/" do
    pipe_through [:browser, :mailbox_preview_enabled]

    forward "/dev/mailbox", Plug.Swoosh.MailboxPreview
  end

  scope "/" do
    pipe_through [:browser, :require_admin_user]

    live_dashboard "/admin/dashboard", metrics: GameServerWeb.Telemetry
  end

  scope "/" do
    pipe_through [:metrics_auth]

    get "/metrics", PromEx.Plug, prom_ex_module: GameServerWeb.PromEx
  end

  scope "/", GameServerWeb do
    pipe_through [:browser, :require_admin_user]

    live_session :require_admin,
      on_mount: [
        {GameServerWeb.OnMount.Locale, :default},
        {GameServerWeb.UserAuth, :require_admin},
        {GameServerWeb.OnMount.Theme, :mount_theme},
        {GameServerWeb.OnMount.TrackConnection, :default}
      ] do
      live "/admin", AdminLive.Index, :index
      live "/admin/config", AdminLive.Config, :index
      live "/admin/kv", AdminLive.KV, :index
      live "/admin/lobbies", AdminLive.Lobbies, :index
      live "/admin/lobbies/live", LobbyLive.Index, :index
      live "/admin/leaderboards", AdminLive.Leaderboards, :index
      live "/admin/users", AdminLive.Users, :index
      live "/admin/sessions", AdminLive.Sessions, :index
      live "/admin/notifications", AdminLive.Notifications, :index
      live "/admin/groups", AdminLive.Groups, :index
      live "/admin/parties", AdminLive.Parties, :index
      live "/admin/chat", AdminLive.Chat, :index
      live "/admin/achievements", AdminLive.Achievements, :index
      live "/admin/translations", AdminLive.Translations, :index
      live "/admin/connections", AdminLive.Connections, :index
      live "/admin/rate-limiting", AdminLive.RateLimiting, :index
      live "/admin/logs", AdminLive.Logs, :index
      live "/admin/geo", AdminLive.Geo, :index
      live "/admin/system", AdminLive.System, :index
    end
  end

  scope "/", GameServerWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [
        {GameServerWeb.OnMount.Locale, :default},
        {GameServerWeb.UserAuth, :require_authenticated},
        {GameServerWeb.OnMount.Theme, :mount_theme},
        {GameServerWeb.OnMount.TrackConnection, :default}
      ] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
      live "/notifications", NotificationsLive, :index
      live "/chat", ChatLive, :index
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", GameServerWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [
        {GameServerWeb.OnMount.Locale, :default},
        {GameServerWeb.UserAuth, :mount_current_scope},
        {GameServerWeb.OnMount.Theme, :mount_theme},
        {GameServerWeb.OnMount.TrackConnection, :default}
      ] do
      live "/users/register", UserLive.Registration, :new
      live "/groups", GroupsLive, :index
      live "/groups/:id", GroupsLive, :show
      live "/achievements", AchievementsLive, :index
      live "/leaderboards", LeaderboardsLive, :index
      live "/leaderboards/:slug/:id", LeaderboardsLive, :show
      live "/leaderboards/:slug", LeaderboardsLive, :show_active
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
      get "/users/confirm/:token", UserSessionController, :confirm
      live "/docs/setup", HostPublicDocs, :index
      live "/changelog", HostChangelogLive, :index
      live "/roadmap", HostRoadmapLive, :index
      live "/blog", HostBlogLive, :index
      live "/blog/:slug", HostBlogLive, :show
      live "/auth/success", AuthSuccessLive, :index
      live "/play", PlayLive, :index
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end

  scope "/auth", GameServerWeb do
    pipe_through :oauth_callback

    post "/:provider/callback", AuthController, :callback
    get "/steam/callback", AuthController, :steam_callback
  end

  scope "/auth", GameServerWeb do
    pipe_through :browser

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
  end

  scope "/", GameServerWeb do
    pipe_through :browser

    get "/*path", PageController, :configured_page
  end
end
