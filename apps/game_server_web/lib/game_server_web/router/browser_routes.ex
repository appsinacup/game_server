defmodule GameServerWeb.Router.BrowserRoutes do
  @moduledoc false

  defmacro browser_routes do
    quote do
      get "/", PageController, :home
      get "/privacy", PageController, :privacy
      get "/data-deletion", PageController, :data_deletion
      get "/terms", PageController, :terms

      ## Authentication routes (localized)

      scope "/" do
        pipe_through [:require_admin_user]

        live_session :require_admin,
          on_mount: [
            {GameServerWeb.OnMount.Locale, :default},
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

      scope "/" do
        pipe_through [:require_authenticated_user]

        live_session :require_authenticated_user,
          on_mount: [
            {GameServerWeb.OnMount.Locale, :default},
            {GameServerWeb.UserAuth, :require_authenticated},
            {GameServerWeb.OnMount.Theme, :mount_theme}
          ] do
          live "/users/settings", UserLive.Settings, :edit
          live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
        end

        post "/users/update-password", UserSessionController, :update_password
      end

      scope "/" do
        live_session :current_user,
          on_mount: [
            {GameServerWeb.OnMount.Locale, :default},
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
    end
  end
end
