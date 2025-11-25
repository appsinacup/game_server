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
    post "/login", SessionController, :create
    post "/refresh", SessionController, :refresh
    delete "/logout", SessionController, :delete
  end

  # Protected API routes - require JWT authentication
  scope "/api/v1", GameServerWeb.Api.V1, as: :api_v1 do
    pipe_through [:api, :api_auth]

    get "/me", MeController, :show
    patch "/me/password", MeController, :update_password
    patch "/me/display_name", MeController, :update_display_name
    delete "/me/providers/:provider", ProviderController, :unlink
  end

  # API OAuth routes
  scope "/api/v1/auth", GameServerWeb do
    pipe_through :api

    get "/:provider", AuthController, :api_request
    get "/session/:session_id", AuthController, :api_session_status
  end

  scope "/api/v1/auth", GameServerWeb do
    pipe_through [:api, :api_auth]

    post "/:provider/conflict-delete", AuthController, :api_conflict_delete
  end

  # Enable LiveDashboard and Swoosh mailbox preview for admins (dev only)
  import Phoenix.LiveDashboard.Router

  scope "/" do
    pipe_through [:browser, :require_admin_user]

    live_dashboard "/admin/dashboard", metrics: GameServerWeb.Telemetry

    # Mailbox preview only in development
    if Mix.env() == :dev do
      forward "/admin/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", GameServerWeb do
    pipe_through [:browser, :require_admin_user]

    live_session :require_admin,
      on_mount: [{GameServerWeb.UserAuth, :require_admin}] do
      # Admin routes
      live "/admin", AdminLive.Index, :index
      live "/admin/config", AdminLive.Config, :index
      live "/admin/users", AdminLive.Users, :index
      live "/admin/sessions", AdminLive.Sessions, :index
    end
  end

  scope "/", GameServerWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{GameServerWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", GameServerWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{GameServerWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
      live "/docs/setup", PublicDocs, :index
      live "/auth/success", AuthSuccessLive, :index
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end

  ## OAuth routes - unified for both browser and API flows

  scope "/auth", GameServerWeb do
    pipe_through :browser

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
  end

  # Apple OAuth uses POST callback (response_mode=form_post)
  # This must be exempt from CSRF protection since it's a cross-site POST from Apple's domain
  scope "/auth", GameServerWeb do
    pipe_through :oauth_callback

    post "/:provider/callback", AuthController, :callback
  end
end
