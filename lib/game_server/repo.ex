defmodule GameServer.Repo do
  @adapter if System.get_env("DATABASE_URL") ||
             System.get_env("POSTGRES_HOST") ||
             System.get_env("POSTGRES_USER") ||
             System.get_env("POSTGRES_DB"),
           do: Ecto.Adapters.Postgres,
           else: Ecto.Adapters.SQLite3

  use Ecto.Repo,
    otp_app: :game_server,
    adapter: @adapter
end
