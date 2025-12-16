defmodule GameServerWeb.Auth.Pipeline do
  @moduledoc """
  Guardian pipeline for API JWT authentication.

  This pipeline verifies JWT tokens from the Authorization header
  and loads the current user into the connection assigns.
  """

  use Guardian.Plug.Pipeline,
    otp_app: :game_server,
    module: GameServerWeb.Auth.Guardian,
    error_handler: GameServerWeb.Auth.ErrorHandler

  plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource
  plug GameServerWeb.Auth.AssignCurrentScope
end
