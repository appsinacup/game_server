defmodule GameServerHost.Router do
  @moduledoc """
  Host router that currently delegates everything to the upstream router.

  This is the intended extension point: forks can add host-specific routes
  here while keeping the upstream UI (GameServerWeb) unchanged.

  The running endpoint is still `GameServerWeb.Endpoint` (defined in the
  `game_server_web` app). When started via `game_server_host`, the host app
  sets `config :game_server_web, :router, GameServerHost.Router` at runtime,
  so changing routes here immediately affects the running app.
  """

  use Phoenix.Router

  forward "/", GameServerWeb.Router
end
