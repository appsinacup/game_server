defmodule GameServerHost.Router do
  @moduledoc """
  Host-owned router for running application.

  Routes reference reusable controllers, LiveViews, and plugs from `game_server_web`.
  """

  use GameServerWeb, :router

  import GameServerWeb.UserAuth
  import GameServerWeb.Router.Shared
  import Phoenix.LiveDashboard.Router

  game_server_pipelines()

  @require_admin_on_mount GameServerWeb.Router.Shared.require_admin_on_mount()
  @require_authenticated_on_mount GameServerWeb.Router.Shared.require_authenticated_on_mount()
  @current_user_on_mount GameServerWeb.Router.Shared.current_user_on_mount()

  scope "/content", GameServerWeb do
    get "/:type/*path", HostContentAssetController, :show
  end

  game_server_static_page_routes()

  scope "/" do
    pipe_through :browser

    get "/sitemap.xml", GameServerHost.SitemapController, :index
  end

  game_server_api_routes()
  game_server_support_routes()
  game_server_admin_live_routes(@require_admin_on_mount)
  game_server_authenticated_live_routes(@require_authenticated_on_mount)

  game_server_current_user_routes(@current_user_on_mount,
    docs: HostPublicDocs,
    changelog: HostChangelogLive,
    roadmap: HostRoadmapLive,
    blog: HostBlogLive
  )

  game_server_oauth_routes()
  game_server_configured_page_fallback_routes()
end
