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
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug OpenApiSpex.Plug.PutApiSpec, module: GameServerWeb.ApiSpec
  end

  scope "/", GameServerWeb do
    pipe_through :browser

    get "/", PageController, :home
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
    delete "/logout", SessionController, :delete
  end

  # API OAuth routes
  scope "/api/v1/auth", GameServerWeb do
    pipe_through :api

    get "/:provider", AuthController, :api_request
    get "/:provider/callback", AuthController, :api_callback
  end

  # Enable LiveDashboard and Swoosh mailbox preview for admins
  import Phoenix.LiveDashboard.Router

  scope "/" do
    pipe_through [:browser, :require_admin_user]

    live_dashboard "/admin/dashboard", metrics: GameServerWeb.Telemetry
    forward "/admin/mailbox", Plug.Swoosh.MailboxPreview
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
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end

  ## OAuth routes

  scope "/auth", GameServerWeb do
    pipe_through :browser

    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
  end
end
