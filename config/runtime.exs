import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/game_server_web start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :game_server_web, GameServerWeb.Endpoint, server: true
end

# Configure log level from environment variable (defaults to :info in prod, :debug in dev)
if log_level = System.get_env("LOG_LEVEL") do
  level = String.to_existing_atom(log_level)
  config :logger, level: level
end

if config_env() == :prod do
  cache_enabled = GameServer.Env.bool("CACHE_ENABLED", true)

  cache_mode = System.get_env("CACHE_MODE") || "single"

  cache_l2 = System.get_env("CACHE_L2") || "partitioned"

  redis_conn_opts =
    case System.get_env("CACHE_REDIS_URL") || System.get_env("REDIS_URL") do
      nil ->
        []

      url ->
        uri = URI.parse(url)

        host = uri.host || "127.0.0.1"
        port = uri.port || 6379

        password =
          case uri.userinfo do
            nil -> nil
            userinfo -> userinfo |> String.split(":", parts: 2) |> List.last()
          end

        database =
          case uri.path do
            "/" <> db_str when db_str != "" ->
              case Integer.parse(db_str) do
                {db, _} -> db
                :error -> nil
              end

            _ ->
              nil
          end

        [host: host, port: port]
        |> then(fn opts ->
          if password, do: Keyword.put(opts, :password, password), else: opts
        end)
        |> then(fn opts ->
          if database != nil, do: Keyword.put(opts, :database, database), else: opts
        end)
    end

  l1_opts = [
    # Create new generation every 12 hours
    gc_interval: :timer.hours(12),
    # Max 1M entries
    max_size: 1_000_000,
    # Max 500MB of memory
    allocated_memory: 500_000_000,
    # Run size and memory checks every 10 seconds
    gc_memory_check_interval: :timer.seconds(10)
  ]

  levels =
    case cache_mode do
      "single" ->
        [{GameServer.Cache.L1, l1_opts}]

      _ ->
        l2_level =
          case cache_l2 do
            "redis" ->
              pool_size = GameServer.Env.integer("CACHE_REDIS_POOL_SIZE", 10)

              if redis_conn_opts == [] do
                raise "CACHE_MODE=multi with CACHE_L2=redis requires CACHE_REDIS_URL or REDIS_URL"
              end

              {GameServer.Cache.L2.Redis, pool_size: pool_size, conn_opts: redis_conn_opts}

            _ ->
              {GameServer.Cache.L2.Partitioned,
               primary: [
                 # Partitioned uses a local primary storage on each node.
                 gc_interval: :timer.hours(12),
                 max_size: 1_000_000,
                 allocated_memory: 500_000_000,
                 gc_memory_check_interval: :timer.seconds(10)
               ]}
          end

        [{GameServer.Cache.L1, l1_opts}, l2_level]
    end

  config :game_server_core, GameServer.Cache,
    bypass_mode: not cache_enabled,
    inclusion_policy: :inclusive,
    levels: levels

  access_log_level = GameServer.Env.log_level("ACCESS_LOG_LEVEL", :debug)

  config :game_server_web, GameServerWeb.Endpoint, access_log: access_log_level

  # Check if PostgreSQL environment variables are set
  has_postgres_config =
    System.get_env("DATABASE_URL") ||
      (System.get_env("POSTGRES_HOST") && System.get_env("POSTGRES_USER"))

  # NOTE: SQLite has a single-writer concurrency model. A very large pool
  # usually increases contention/lock waits rather than throughput.
  default_pool_size = if has_postgres_config, do: 10, else: 5

  repo_pool_size = GameServer.Env.integer("POOL_SIZE", default_pool_size)

  # Backpressure/overload tuning:
  # - pool_timeout: how long a request waits for a DB connection checkout (ms)
  # - queue_target/queue_interval: DBConnection queueing algorithm (ms)
  # - timeout: query timeout (ms)
  # NOTE: Increasing queue_target/interval makes requests wait longer (can increase memory under load).
  # Default to more forgiving backpressure in prod to avoid dropping requests too quickly
  # under bursty load. These can still be overridden via env vars.
  repo_pool_timeout = GameServer.Env.integer("DB_POOL_TIMEOUT", 10_000)
  repo_queue_target = GameServer.Env.integer("DB_QUEUE_TARGET", 10_000)
  repo_queue_interval = GameServer.Env.integer("DB_QUEUE_INTERVAL", 1000)
  repo_query_timeout = GameServer.Env.integer("DB_QUERY_TIMEOUT", 15_000)

  if has_postgres_config do
    # Use PostgreSQL when configured
    database_url =
      System.get_env("DATABASE_URL") ||
        "ecto://#{System.get_env("POSTGRES_USER")}:#{System.get_env("POSTGRES_PASSWORD")}@#{System.get_env("POSTGRES_HOST")}:#{System.get_env("POSTGRES_PORT", "5432")}/#{System.get_env("POSTGRES_DB", "game_server_prod")}"

    maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

    config :game_server_core, GameServer.Repo,
      url: database_url,
      adapter: Ecto.Adapters.Postgres,
      pool_size: repo_pool_size,
      pool_timeout: repo_pool_timeout,
      queue_target: repo_queue_target,
      queue_interval: repo_queue_interval,
      timeout: repo_query_timeout,
      socket_options: maybe_ipv6
  else
    # Fallback to persistent SQLite when no PostgreSQL config
    # Use SQLITE_DATABASE_PATH if set (e.g. a mounted Fly volume), otherwise default to db/game_server_prod.db
    db_path = System.get_env("SQLITE_DATABASE_PATH") || "db/game_server_prod.db"

    # SQLite performance/durability tuning.
    # - WAL: better read concurrency and typically fewer full-db fsyncs
    # - synchronous=normal: less fsync pressure vs full (tradeoff: slightly less durability)
    # - temp_store=memory: reduces disk writes for temp tables
    # - cache_size: in KiB when negative (e.g. -200_000 => ~200MB page cache)
    # - busy_timeout: wait for locks instead of immediate "database is locked" failures
    sqlite_synchronous =
      case System.get_env("SQLITE_SYNCHRONOUS") do
        "off" -> :off
        "normal" -> :normal
        "full" -> :full
        "extra" -> :extra
        _ -> :normal
      end

    sqlite_cache_size_kb = GameServer.Env.integer("SQLITE_CACHE_SIZE_KB", 200_000)
    sqlite_busy_timeout_ms = GameServer.Env.integer("SQLITE_BUSY_TIMEOUT", 10_000)
    sqlite_wal_autocheckpoint = GameServer.Env.integer("SQLITE_WAL_AUTOCHECKPOINT", 2000)

    config :game_server_core, GameServer.Repo,
      database: db_path,
      adapter: Ecto.Adapters.SQLite3,
      pool_size: repo_pool_size,
      pool_timeout: repo_pool_timeout,
      queue_target: repo_queue_target,
      queue_interval: repo_queue_interval,
      timeout: repo_query_timeout,
      pragmas: [
        foreign_keys: :on,
        journal_mode: :wal,
        synchronous: sqlite_synchronous,
        temp_store: :memory,
        cache_size: -sqlite_cache_size_kb,
        busy_timeout: sqlite_busy_timeout_ms,
        wal_autocheckpoint: sqlite_wal_autocheckpoint
      ]
  end

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  # Guardian JWT secret - can be the same as secret_key_base or separate
  guardian_secret_key =
    System.get_env("GUARDIAN_SECRET_KEY") || secret_key_base

  config :game_server_web, GameServerWeb.Auth.Guardian,
    issuer: "game_server",
    secret_key: guardian_secret_key,
    ttl: {15, :minutes}

  host = System.get_env("PHX_HOST") || "localhost"
  port = GameServer.Env.integer("PORT", 4000)

  config :game_server_web, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  # Configure Apple OAuth with proper redirect URI for production
  config :ueberauth, Ueberauth.Strategy.Apple.OAuth,
    client_id: System.get_env("APPLE_WEB_CLIENT_ID"),
    client_secret: {GameServer.Apple, :client_secret},
    redirect_uri: "https://#{host}/auth/apple/callback"

  config :game_server_web, GameServerWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :game_server, GameServerWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :game_server, GameServerWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # Configure the mailer - if SMTP_PASSWORD is set, use SMTP, otherwise use local mailbox
  if System.get_env("SMTP_PASSWORD") do
    # Prepare SNI charlist if provided — gen_smtp expects charlists for
    # server_name_indication, not binaries (passing a binary causes an
    # "incompatible options" error). Compute safely outside of keyword lists
    # so we don't call remote fns in guards.
    sni_env = System.get_env("SMTP_SNI") || System.get_env("SMTP_RELAY")

    sni =
      if is_binary(sni_env) do
        trimmed = String.trim(sni_env)

        if trimmed != "" do
          String.to_charlist(trimmed)
        else
          nil
        end
      else
        nil
      end

    config :game_server_core, GameServer.Mailer,
      adapter: Swoosh.Adapters.SMTP,
      relay: System.get_env("SMTP_RELAY"),
      username: System.get_env("SMTP_USERNAME"),
      password: System.get_env("SMTP_PASSWORD"),
      port: System.get_env("SMTP_PORT"),
      tls: String.to_existing_atom(System.get_env("SMTP_TLS") || "never"),
      ssl: String.to_existing_atom(System.get_env("SMTP_SSL") || "true"),
      retries: 2,
      auth: :always,
      no_mx_lookups: false,
      sockopts: [
        versions: [:"tlsv1.2", :"tlsv1.3"],
        verify: :verify_peer,
        cacerts: :public_key.cacerts_get(),
        depth: 3,
        customize_hostname_check: [
          match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
        ],
        server_name_indication: sni
      ]

    # Configure Swoosh to use Req for HTTP requests
    config :swoosh, :api_client, Swoosh.ApiClient.Req
  else
    # Use local adapter when SMTP is not configured - emails go to mailbox
    config :game_server_core, GameServer.Mailer, adapter: Swoosh.Adapters.Local

    # Disable swoosh api client for local adapter
    config :swoosh, :api_client, false
  end

  # ## Configuring Sentry
  #
  # Configure Sentry for error tracking and monitoring
  if dsn = System.get_env("SENTRY_DSN") do
    # Determine which log levels to send to Sentry (default: :error only)
    # Set SENTRY_LOG_LEVEL to capture more: info, warning, error
    sentry_log_level =
      case System.get_env("SENTRY_LOG_LEVEL") do
        "info" -> :info
        "warning" -> :warning
        "error" -> :error
        # default to error only
        _ -> :error
      end

    config :sentry,
      dsn: dsn,
      environment_name: :prod,
      enable_source_code_context: true,
      root_source_code_path: File.cwd!(),
      tags: %{
        env: "production"
      },
      # Set the minimum log level for Sentry to capture
      log_level: sentry_log_level
  end

  unless System.get_env("SENTRY_DSN") do
    require Logger

    Logger.warning(
      "SENTRY_DSN not set - Sentry will be disabled. Set SENTRY_DSN in production to enable error monitoring and log forwarding."
    )
  end
end
