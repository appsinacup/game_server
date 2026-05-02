import Config

config :bcrypt_elixir, :log_rounds, 1

if System.get_env("DATABASE_URL") ||
     (System.get_env("POSTGRES_HOST") && System.get_env("POSTGRES_USER")) do
  database_url =
    System.get_env("DATABASE_URL") ||
      "ecto://#{System.get_env("POSTGRES_USER")}:#{System.get_env("POSTGRES_PASSWORD")}@#{System.get_env("POSTGRES_HOST")}:#{System.get_env("POSTGRES_PORT", "5432")}/#{System.get_env("POSTGRES_DB", "game_server_web_test")}"

  config :game_server_core, GameServer.Repo,
    url: database_url,
    adapter: Ecto.Adapters.Postgres,
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: System.schedulers_online() * 2,
    pool_timeout: 10_000,
    queue_target: 10_000,
    queue_interval: 1_000,
    timeout: 15_000
else
  database_path =
    Path.expand(
      "../priv/db/game_server_web_test#{System.get_env("MIX_TEST_PARTITION")}.db",
      __DIR__
    )

  File.mkdir_p!(Path.dirname(database_path))

  config :game_server_core, GameServer.Repo,
    database: database_path,
    adapter: Ecto.Adapters.SQLite3,
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 1,
    pool_timeout: 10_000,
    queue_target: 10_000,
    queue_interval: 1_000,
    timeout: 15_000,
    pragmas: [
      foreign_keys: :on,
      journal_mode: :wal,
      synchronous: :normal,
      temp_store: :memory,
      busy_timeout: 10_000
    ]
end

config :game_server_web, GameServerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "dJoNJZBOt08JlBREyPV5xvuOdwgHPORxK9WHp/k3Cs+g0R9ctyheJ8/CMeg/AdI1",
  server: false

config :game_server_core, GameServer.Mailer, adapter: Swoosh.Adapters.Test
config :swoosh, :api_client, false

config :logger, level: :warning

config :game_server_core, GameServer.Cache,
  bypass_mode: true,
  inclusion_policy: :inclusive,
  levels: [
    {GameServer.Cache.L1, []}
  ]

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :game_server_web, GameServerWeb.Auth.Guardian,
  issuer: "game_server",
  secret_key: "dJoNJZBOt08JlBREyPV5xvuOdwgHPORxK9WHp/k3Cs+g0R9ctyheJ8/CMeg/AdI1",
  ttl: {15, :minutes}

config :game_server_web, GameServerWeb.Plugs.RateLimiter, enabled: false

# Background presence sweeping fights with sandbox ownership in tests and can
# keep logging after the test task itself is done.
config :game_server_core, GameServer.Accounts.StalePresenceSweeper, enabled: false
