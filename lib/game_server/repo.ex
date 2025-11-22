defmodule GameServer.Repo do
  use Ecto.Repo,
    otp_app: :game_server,
    adapter: Ecto.Adapters.Postgres
end
