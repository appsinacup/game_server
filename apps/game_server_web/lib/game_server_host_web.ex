defmodule GameServerHostWeb do
  @moduledoc false

  @host_gettext_backend Application.compile_env(
                          :game_server_web,
                          :host_gettext_backend,
                          GameServerWeb.Gettext
                        )
  @configured_host_router Application.compile_env(
                            :game_server_web,
                            :host_router,
                            GameServerWeb.Router
                          )
  @host_router if Code.ensure_loaded?(@configured_host_router),
                 do: @configured_host_router,
                 else: GameServerWeb.Router

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def controller do
    backend = @host_gettext_backend

    quote do
      use Phoenix.Controller, formats: [:html, :json]

      use Gettext, backend: unquote(backend)

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      unquote(html_helpers())
    end
  end

  defp html_helpers do
    backend = @host_gettext_backend

    quote do
      use Gettext, backend: unquote(backend)

      import GameServerWeb.DocText, only: [doc_text: 1, doc_text: 2]

      import Phoenix.HTML
      import GameServerWeb.CoreComponents
      import GameServerWeb.Components.DynamicIcon

      alias GameServerWeb.Layouts
      alias GameServerWeb.SRI
      alias Phoenix.LiveView.JS

      unquote(verified_routes())
    end
  end

  def verified_routes do
    host_router = @host_router

    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: GameServerWeb.Endpoint,
        router: unquote(host_router),
        statics: GameServerWeb.static_paths()
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
