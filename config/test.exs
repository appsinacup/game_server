import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
# Use PostgreSQL if environment variables are set, otherwise use SQLite
if System.get_env("DATABASE_URL") ||
     (System.get_env("POSTGRES_HOST") && System.get_env("POSTGRES_USER")) do
  # Use PostgreSQL when configured
  database_url =
    System.get_env("DATABASE_URL") ||
      "ecto://#{System.get_env("POSTGRES_USER")}:#{System.get_env("POSTGRES_PASSWORD")}@#{System.get_env("POSTGRES_HOST")}:#{System.get_env("POSTGRES_PORT", "5432")}/#{System.get_env("POSTGRES_DB", "game_server_test")}"

  config :game_server, GameServer.Repo,
    url: database_url,
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: System.schedulers_online() * 2
else
  # Fallback to SQLite when no PostgreSQL config
  config :game_server, GameServer.Repo,
    database: "db/game_server_test#{System.get_env("MIX_TEST_PARTITION")}.db",
    adapter: Ecto.Adapters.SQLite3,
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 1
end

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :game_server, GameServerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "dJoNJZBOt08JlBREyPV5xvuOdwgHPORxK9WHp/k3Cs+g0R9ctyheJ8/CMeg/AdI1",
  server: false

# In test we don't send emails
config :game_server, GameServer.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Disable Sentry during testing
config :sentry,
  dsn: nil

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
