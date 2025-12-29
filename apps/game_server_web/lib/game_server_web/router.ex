defmodule GameServerWeb.Router do
  use GameServerWeb, :router

  import GameServerWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GameServerWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    # Attach Sentry context information (user id, path, request id) to
    # Sentry's per-request scope so events are enriched with user info.
    plug GameServerWeb.Plugs.SentryContext
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
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug GameServerWeb.Plugs.SentryContext
  end

  pipeline :api_auth do
    plug GameServerWeb.Auth.Pipeline
    plug GameServerWeb.Plugs.SentryContext
  end

  scope "/", GameServerWeb do
    pipe_through :browser

    get "/", PageController, :home
    get "/privacy", PageController, :privacy
    get "/data-deletion", PageController, :data_deletion
    get "/terms", PageController, :terms
  end

  scope "/api" do
    pipe_through :api

    get "/openapi", OpenApiSpex.Plug.RenderSpec, []
  end

  scope "/api" do
    pipe_through :browser

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

    # Leaderboards (public read)
    get "/leaderboards", LeaderboardController, :index
    get "/leaderboards/:id", LeaderboardController, :show
    get "/leaderboards/:id/records", LeaderboardController, :records
    get "/leaderboards/:id/records/around/:user_id", LeaderboardController, :around
  end

  # Key/value retrieval (authenticated only, hooks still control public/private semantics)
  scope "/api/v1", GameServerWeb.Api.V1, as: :api_v1 do
    pipe_through [:api, :api_auth]

    get "/kv/:key", KvController, :show
  end

  # Protected API routes - require JWT authentication
  scope "/api/v1", GameServerWeb.Api.V1, as: :api_v1 do
    pipe_through [:api, :api_auth]

    get "/me", MeController, :show
    delete "/me", MeController, :delete
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
    # Friends API
    post "/friends", FriendController, :create
    get "/me/friends", FriendController, :index
    get "/me/friend-requests", FriendController, :requests
    get "/me/blocked", FriendController, :blocked
    post "/friends/:id/accept", FriendController, :accept
    post "/friends/:id/reject", FriendController, :reject
    post "/friends/:id/block", FriendController, :block
    post "/friends/:id/unblock", FriendController, :unblock
    delete "/friends/:id", FriendController, :delete
    # Hooks API - list available hook functions and call them
    get "/hooks", HookController, :index
    post "/hooks/call", HookController, :invoke
    # Leaderboards (authenticated)
    get "/leaderboards/:id/records/me", LeaderboardController, :me
  end

  # API OAuth routes
  scope "/api/v1/auth", GameServerWeb do
    pipe_through :api

    get "/:provider", AuthController, :api_request
    post "/:provider/callback", AuthController, :api_callback
    post "/apple/ios/callback", AuthController, :api_apple_ios_callback
    post "/google/id_token", AuthController, :api_google_id_token
    get "/session/:session_id", AuthController, :api_session_status
  end

  # Enable LiveDashboard and Swoosh mailbox preview for admins (dev only)
  import Phoenix.LiveDashboard.Router

  scope "/" do
    pipe_through [:browser]
    # Mailbox preview enabled in dev or if MAILBOX_PREVIEW_ENABLED is set
    if Mix.env() == :dev or System.get_env("MAILBOX_PREVIEW_ENABLED") in ["1", "true", "TRUE"] do
      forward "/dev/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  scope "/" do
    pipe_through [:browser, :require_admin_user]

    live_dashboard "/admin/dashboard", metrics: GameServerWeb.Telemetry
  end

  ## Authentication routes

  scope "/", GameServerWeb do
    pipe_through [:browser, :require_admin_user]

    live_session :require_admin,
      on_mount: [
        {GameServerWeb.UserAuth, :require_admin},
        {GameServerWeb.OnMount.Theme, :mount_theme}
      ] do
      # Admin routes
      live "/admin", AdminLive.Index, :index
      live "/admin/config", AdminLive.Config, :index
      live "/admin/kv", AdminLive.KV, :index
      live "/admin/lobbies", AdminLive.Lobbies, :index
      live "/admin/leaderboards", AdminLive.Leaderboards, :index
      live "/admin/users", AdminLive.Users, :index
      live "/admin/sessions", AdminLive.Sessions, :index
    end
  end

  scope "/", GameServerWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [
        {GameServerWeb.UserAuth, :require_authenticated},
        {GameServerWeb.OnMount.Theme, :mount_theme}
      ] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", GameServerWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [
        {GameServerWeb.UserAuth, :mount_current_scope},
        {GameServerWeb.OnMount.Theme, :mount_theme}
      ] do
      live "/users/register", UserLive.Registration, :new
      live "/lobbies", LobbyLive.Index, :index
      live "/leaderboards", LeaderboardsLive, :index
      live "/leaderboards/:slug/:id", LeaderboardsLive, :show
      live "/leaderboards/:slug", LeaderboardsLive, :show_active
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
      get "/users/confirm/:token", UserSessionController, :confirm
      live "/docs/setup", PublicDocs, :index
      live "/auth/success", AuthSuccessLive, :index
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end

  ## OAuth routes - unified for both browser and API flows

  # Apple OAuth uses POST callback (response_mode=form_post)
  # This must be exempt from CSRF protection since it's a cross-site POST from Apple's domain
  # Steam uses OpenID GET callback which also fails CSRF checks
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
