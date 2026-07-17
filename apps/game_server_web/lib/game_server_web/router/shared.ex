defmodule GameServerWeb.Router.Shared do
  @moduledoc false

  @browser_csp "default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' wss:; font-src 'self' data:; frame-src 'self' blob:; frame-ancestors 'self'"
  @swagger_csp "default-src 'self'; script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; img-src 'self' data: https:; connect-src 'self' wss:; font-src 'self' data:; frame-src 'self' blob:; frame-ancestors 'self'"

  def browser_headers, do: %{"content-security-policy" => @browser_csp}
  def swagger_headers, do: %{"content-security-policy" => @swagger_csp}

  def require_admin_on_mount do
    [
      {GameServerWeb.OnMount.Locale, :default},
      {GameServerWeb.UserAuth, :require_admin},
      {GameServerWeb.OnMount.Theme, :mount_theme},
      {GameServerWeb.OnMount.TrackConnection, :default}
    ]
  end

  def require_authenticated_on_mount do
    [
      {GameServerWeb.OnMount.Locale, :default},
      {GameServerWeb.UserAuth, :require_authenticated},
      {GameServerWeb.OnMount.Theme, :mount_theme},
      {GameServerWeb.OnMount.TrackConnection, :default}
    ]
  end

  def current_user_on_mount do
    [
      {GameServerWeb.OnMount.Locale, :default},
      {GameServerWeb.UserAuth, :mount_current_scope},
      {GameServerWeb.OnMount.Theme, :mount_theme},
      {GameServerWeb.OnMount.TrackConnection, :default}
    ]
  end

  defmacro game_server_pipelines do
    quote do
      alias GameServerWeb.Router.Shared, as: RouterShared

      pipeline :browser do
        plug :accepts, ["html"]
        plug :fetch_session
        plug :fetch_live_flash
        plug :put_root_layout, html: {GameServerWeb.Layouts, :root}
        plug :protect_from_forgery
        plug :put_secure_browser_headers, RouterShared.browser_headers()
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
        plug :put_secure_browser_headers, RouterShared.browser_headers()
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
        plug :put_secure_browser_headers, RouterShared.swagger_headers()
        plug :fetch_current_scope_for_user
      end

      pipeline :openapi_gate do
        plug GameServerWeb.Plugs.FeatureGate, env: "OPENAPI_ENABLED", default: true
      end

      pipeline :list_users_gate do
        plug GameServerWeb.Plugs.FeatureGate, env: "LIST_USERS_ENABLED", default: true
      end

      pipeline :list_lobbies_gate do
        plug GameServerWeb.Plugs.FeatureGate, env: "LIST_LOBBIES_ENABLED", default: true
      end

      pipeline :list_groups_gate do
        plug GameServerWeb.Plugs.FeatureGate, env: "LIST_GROUPS_ENABLED", default: true
      end

      pipeline :list_leaderboards_gate do
        plug GameServerWeb.Plugs.FeatureGate, env: "LIST_LEADERBOARDS_ENABLED", default: true
      end

      pipeline :list_achievements_gate do
        plug GameServerWeb.Plugs.FeatureGate, env: "LIST_ACHIEVEMENTS_ENABLED", default: true
      end

      pipeline :metrics_auth do
        plug GameServerWeb.Plugs.MetricsAuth
      end
    end
  end

  defmacro game_server_static_page_routes do
    quote do
      scope "/", GameServerWeb do
        pipe_through :browser

        get "/", PageController, :home
        get "/privacy", PageController, :privacy
        get "/data-deletion", PageController, :data_deletion
        get "/terms", PageController, :terms
      end
    end
  end

  defmacro game_server_api_routes do
    quote do
      game_server_api_docs_routes()
      game_server_public_api_routes()
      game_server_achievement_api_routes()
      game_server_group_api_routes()
      game_server_kv_api_routes()
      game_server_account_lobby_api_routes()
      game_server_friend_notification_api_routes()
      game_server_group_mutation_api_routes()
      game_server_hook_leaderboard_party_api_routes()
      game_server_chat_api_routes()
      game_server_admin_api_routes()
      game_server_api_auth_routes()
    end
  end

  defmacro game_server_api_docs_routes do
    quote do
      scope "/api" do
        pipe_through [:api, :openapi_gate]

        get "/openapi", OpenApiSpex.Plug.RenderSpec, []
      end

      scope "/api" do
        pipe_through [:swagger_browser, :openapi_gate]

        get "/docs", GameServerWeb.SwaggerController, :index
      end
    end
  end

  defmacro game_server_public_api_routes do
    quote do
      scope "/api/v1", GameServerWeb.Api.V1, as: :api_v1 do
        pipe_through :api

        get "/health", HealthController, :index
        post "/login", SessionController, :create
        post "/login/device", SessionController, :create_device
        post "/refresh", SessionController, :refresh
        delete "/logout", SessionController, :delete
        get "/payments/catalog", PaymentController, :catalog
        post "/payments/webhooks/stripe", PaymentWebhookController, :stripe
        post "/payments/webhooks/google", PaymentWebhookController, :google
        post "/payments/webhooks/apple", PaymentWebhookController, :apple
      end

      scope "/api/v1", GameServerWeb.Api.V1, as: :api_v1 do
        pipe_through [:api, :list_users_gate]

        get "/users", UserController, :index
        get "/users/:id", UserController, :show
      end

      scope "/api/v1", GameServerWeb.Api.V1, as: :api_v1 do
        pipe_through [:api, :list_lobbies_gate]

        get "/lobbies", LobbyController, :index
      end

      scope "/api/v1", GameServerWeb.Api.V1, as: :api_v1 do
        pipe_through [:api, :list_groups_gate]

        get "/groups", GroupController, :index
      end

      scope "/api/v1", GameServerWeb.Api.V1, as: :api_v1 do
        pipe_through [:api, :list_leaderboards_gate]

        get "/leaderboards", LeaderboardController, :index
        post "/leaderboards/resolve", LeaderboardController, :resolve
        get "/leaderboards/:id", LeaderboardController, :show
        get "/leaderboards/:id/records", LeaderboardController, :records
        get "/leaderboards/:id/records/around/:user_id", LeaderboardController, :around
      end
    end
  end

  defmacro game_server_achievement_api_routes do
    quote do
      scope "/api/v1", GameServerWeb.Api.V1, as: :api_v1 do
        pipe_through [:api, :api_auth]

        get "/achievements/me", AchievementController, :me
      end

      scope "/api/v1", GameServerWeb.Api.V1, as: :api_v1 do
        pipe_through [:api, :api_optional_auth, :list_achievements_gate]

        get "/achievements", AchievementController, :index
        get "/achievements/user/:user_id", AchievementController, :user_achievements
        get "/achievements/:slug", AchievementController, :show
      end
    end
  end

  defmacro game_server_group_api_routes do
    quote do
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
        pipe_through [:api, :list_groups_gate]

        get "/groups/:id", GroupController, :show
        get "/groups/:id/members", GroupController, :members
      end
    end
  end

  defmacro game_server_kv_api_routes do
    quote do
      scope "/api/v1", GameServerWeb.Api.V1, as: :api_v1 do
        pipe_through [:api, :api_auth]

        get "/kv/:key", KvController, :show
      end
    end
  end

  defmacro game_server_account_lobby_api_routes do
    quote do
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
        patch "/me/username", MeController, :update_username
        get "/payments/entitlements", PaymentController, :entitlements
        post "/payments/checkout/stripe", PaymentController, :stripe_checkout
        post "/payments/checkout/steam", PaymentController, :steam_checkout
        post "/payments/steam/finalize", PaymentController, :steam_finalize
        post "/payments/validate/:provider", PaymentController, :validate
        delete "/me/providers/:provider", ProviderController, :unlink
        post "/me/device", ProviderController, :link_device
        delete "/me/device", ProviderController, :unlink_device
      end
    end
  end

  defmacro game_server_friend_notification_api_routes do
    quote do
      scope "/api/v1", GameServerWeb.Api.V1, as: :api_v1 do
        pipe_through [:api, :api_auth]

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
      end
    end
  end

  defmacro game_server_group_mutation_api_routes do
    quote do
      scope "/api/v1", GameServerWeb.Api.V1, as: :api_v1 do
        pipe_through [:api, :api_auth]

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
      end
    end
  end

  defmacro game_server_hook_leaderboard_party_api_routes do
    quote do
      scope "/api/v1", GameServerWeb.Api.V1, as: :api_v1 do
        pipe_through [:api, :api_auth]

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
      end
    end
  end

  defmacro game_server_chat_api_routes do
    quote do
      scope "/api/v1", GameServerWeb.Api.V1, as: :api_v1 do
        pipe_through [:api, :api_auth]

        get "/chat/messages", ChatController, :index
        get "/chat/messages/:id", ChatController, :show
        post "/chat/messages", ChatController, :send
        patch "/chat/messages/:id", ChatController, :update
        delete "/chat/messages/:id", ChatController, :delete
        post "/chat/read", ChatController, :mark_read
        get "/chat/unread", ChatController, :unread
      end
    end
  end

  defmacro game_server_admin_api_routes do
    quote do
      game_server_admin_kv_leaderboard_api_routes()
      game_server_admin_management_api_routes()
      game_server_admin_chat_achievement_api_routes()
    end
  end

  defmacro game_server_admin_kv_leaderboard_api_routes do
    quote do
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

        delete "/leaderboards/:id/records/user/:user_id",
               LeaderboardRecordController,
               :delete_user
      end
    end
  end

  defmacro game_server_admin_management_api_routes do
    quote do
      scope "/api/v1/admin", GameServerWeb.Api.V1.Admin, as: :api_v1_admin do
        pipe_through [:api, :api_auth, :api_admin]

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
      end
    end
  end

  defmacro game_server_admin_chat_achievement_api_routes do
    quote do
      scope "/api/v1/admin", GameServerWeb.Api.V1.Admin, as: :api_v1_admin do
        pipe_through [:api, :api_auth, :api_admin]

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
    end
  end

  defmacro game_server_api_auth_routes do
    quote do
      scope "/api/v1/auth", GameServerWeb do
        pipe_through :api

        get "/:provider", AuthController, :api_request
        post "/:provider/callback", AuthController, :api_callback
        post "/apple/ios/callback", AuthController, :api_apple_ios_callback
        post "/google/id_token", AuthController, :api_google_id_token
        get "/session/:session_id", AuthController, :api_session_status
      end
    end
  end

  defmacro game_server_support_routes do
    quote do
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
    end
  end

  defmacro game_server_admin_live_routes(on_mount) do
    quote do
      scope "/", GameServerWeb do
        pipe_through [:browser, :require_admin_user]

        live_session :require_admin,
          on_mount: unquote(on_mount) do
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
          live "/admin/payments", AdminLive.Payments, :index
          live "/admin/translations", AdminLive.Translations, :index
          live "/admin/connections", AdminLive.Connections, :index
          live "/admin/rate-limiting", AdminLive.RateLimiting, :index
          live "/admin/logs", AdminLive.Logs, :index
          live "/admin/geo", AdminLive.Geo, :index
          live "/admin/system", AdminLive.System, :index
        end
      end
    end
  end

  defmacro game_server_authenticated_live_routes(on_mount) do
    quote do
      scope "/", GameServerWeb do
        pipe_through [:browser, :require_authenticated_user]

        live_session :require_authenticated_user,
          on_mount: unquote(on_mount) do
          live "/users/settings", UserLive.Settings, :edit
          live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
          live "/store", StoreLive.Index, :index
          live "/store/success", StoreLive.Index, :success
          live "/store/cancel", StoreLive.Index, :cancel
          live "/notifications", NotificationsLive, :index
          live "/chat", ChatLive, :index
        end

        post "/users/update-password", UserSessionController, :update_password
        get "/payments/downloads/:id", PaymentDownloadController, :show
      end
    end
  end

  defmacro game_server_current_user_routes(on_mount, opts \\ []) do
    docs = Keyword.get(opts, :docs)
    changelog = Keyword.fetch!(opts, :changelog)
    roadmap = Keyword.fetch!(opts, :roadmap)
    blog = Keyword.fetch!(opts, :blog)

    docs_route =
      if docs do
        quote do
          live "/docs/setup", unquote(docs), :index
        end
      end

    quote do
      scope "/", GameServerWeb do
        pipe_through [:browser]

        live_session :current_user,
          on_mount: unquote(on_mount) do
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
          unquote(docs_route)
          live "/changelog", unquote(changelog), :index
          live "/roadmap", unquote(roadmap), :index
          live "/blog", unquote(blog), :index
          live "/blog/:slug", unquote(blog), :show
          live "/auth/success", AuthSuccessLive, :index
          live "/play", PlayLive, :index
        end

        post "/users/log-in", UserSessionController, :create
        delete "/users/log-out", UserSessionController, :delete
      end
    end
  end

  defmacro game_server_oauth_routes do
    quote do
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
    end
  end

  defmacro game_server_configured_page_fallback_routes do
    quote do
      scope "/", GameServerWeb do
        pipe_through :browser

        get "/*path", PageController, :configured_page
      end
    end
  end
end
