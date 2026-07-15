import Config

config :game_server_core, ecto_repos: [GameServer.Repo]

default_adapter =
  if System.get_env("DATABASE_ADAPTER") == "postgres",
    do: Ecto.Adapters.Postgres,
    else: Ecto.Adapters.SQLite3

config :game_server_core, GameServer.Repo,
  adapter: default_adapter,
  # All tables use UUID (v7) primary/foreign keys — see GameServer.UUIDv7.
  migration_primary_key: [name: :id, type: :binary_id],
  migration_foreign_key: [type: :binary_id]

config :game_server_core, GameServer.Mailer, adapter: Swoosh.Adapters.Local

config :game_server_core, GameServer.Cache,
  inclusion_policy: :inclusive,
  levels: [
    {GameServer.Cache.L1, []}
  ]
