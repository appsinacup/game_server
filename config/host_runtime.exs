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

# ── Configurable limits ────────────────────────────────────────────────────────
# Override any limit defined in GameServer.Limits by setting the corresponding
# LIMIT_<KEY> environment variable, e.g. LIMIT_MAX_METADATA_SIZE=32768.
# Unset variables keep the compiled defaults.
_limit_overrides =
  [
    :max_metadata_size,
    :max_page_size,
    :max_display_name,
    :max_email,
    :max_profile_url,
    :max_device_id,
    :max_group_title,
    :max_group_description,
    :max_group_members,
    :max_groups_per_user,
    :max_groups_created_per_user,
    :max_group_pending_invites,
    :max_lobby_title,
    :max_lobby_users,
    :max_lobby_password,
    :max_party_size,
    :max_party_pending_invites,
    :max_chat_content,
    :max_notification_title,
    :max_notification_content,
    :max_notifications_per_user,
    :max_friends_per_user,
    :max_pending_friend_requests,
    :max_hook_args_size,
    :max_hook_args_count,
    :max_kv_key,
    :max_kv_value_size,
    :max_kv_entries_per_user,
    :max_leaderboard_title,
    :max_leaderboard_description,
    :max_leaderboard_slug
  ]
  |> Enum.reduce([], fn key, acc ->
    env_name = "LIMIT_#{key |> Atom.to_string() |> String.upcase()}"

    case System.get_env(env_name) do
      nil ->
        acc

      val ->
        case Integer.parse(val) do
          {n, _} -> [{key, n} | acc]
          :error -> acc
        end
    end
  end)
  |> then(fn
    [] -> :ok
    overrides -> config :game_server_core, GameServer.Limits, overrides
  end)

# ── Account activation ──────────────────────────────────────────────────────
# Read REQUIRE_ACCOUNT_ACTIVATION once at boot so the function only hits the
# fast Application.get_env path at runtime.
if require_activation = System.get_env("REQUIRE_ACCOUNT_ACTIVATION") do
  config :game_server_core,
    require_account_activation: require_activation in ["1", "true", "TRUE", "True"]
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
    # Use SQLITE_DATABASE_PATH if set (e.g. a mounted Fly volume), otherwise default to the host-local db directory.
    default_db_path = Path.expand("../db/game_server_prod.db", __DIR__)

    db_path =
      case System.get_env("SQLITE_DATABASE_PATH") do
        nil ->
          File.mkdir_p!(Path.dirname(default_db_path))
          default_db_path

        override ->
          override
      end

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
    sqlite_busy_timeout_ms = GameServer.Env.integer("SQLITE_BUSY_TIMEOUT", 15_000)
    sqlite_wal_autocheckpoint = GameServer.Env.integer("SQLITE_WAL_AUTOCHECKPOINT", 2000)

    # Ensure Ecto/DBConnection timeout does not fire before SQLite's busy timeout.
    sqlite_query_timeout = max(repo_query_timeout, sqlite_busy_timeout_ms + 5_000)

    config :game_server_core, GameServer.Repo,
      database: db_path,
      adapter: Ecto.Adapters.SQLite3,
      pool_size: repo_pool_size,
      pool_timeout: repo_pool_timeout,
      queue_target: repo_queue_target,
      queue_interval: repo_queue_interval,
      timeout: sqlite_query_timeout,
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

  scheme =
    System.get_env("PHX_SCHEME") ||
      if host in ["localhost", "127.0.0.1"], do: "http", else: "https"

  config :game_server_web, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  # Configure Apple OAuth with proper redirect URI for production
  config :ueberauth, Ueberauth.Strategy.Apple.OAuth,
    client_id: System.get_env("APPLE_WEB_CLIENT_ID"),
    client_secret: {GameServer.Apple, :client_secret},
    redirect_uri: "#{scheme}://#{host}/auth/apple/callback"

  # Allow runtime configuration of allowed WebSocket origins via PHX_ALLOWED_ORIGINS.
  # Format: comma-separated values. Prefix with "regex:" for regex entries, e.g.
  #   PHX_ALLOWED_ORIGINS="//polyglotpirates.com,regex:^https:\/\/(.+\.)?itch\.io(:\d+)?$"
  allowed_origins = System.get_env("PHX_ALLOWED_ORIGINS", "") |> String.trim()

  check_origin =
    if allowed_origins == "" do
      nil
    else
      allowed_origins
      |> String.split(",", trim: true)
      |> Enum.map(fn entry ->
        entry = String.trim(entry)

        case entry do
          <<"regex:", rest::binary>> ->
            Regex.compile!(rest)

          other ->
            if String.starts_with?(other, "//") or String.starts_with?(other, "http") do
              other
            else
              "//" <> other
            end
        end
      end)
    end

  # Build the Corsica origins list. When explicit origins are configured we prefer
  # using those for HTTP CORS as well. If no PHX_ALLOWED_ORIGINS is set we fall
  # back to "*" which allows all origins for simple CORS requests.
  cors_allowed_origins =
    if allowed_origins == "" do
      "*"
    else
      allowed_origins
      |> String.split(",", trim: true)
      |> Enum.map(fn entry ->
        entry = String.trim(entry)

        case entry do
          <<"regex:", rest::binary>> ->
            # Corsica accepts compiled regex
            Regex.compile!(rest)

          other ->
            # Normalize bare host -> protocol-agnostic //host, allow http/https as appropriate
            if String.starts_with?(other, "//") or String.starts_with?(other, "http") do
              other
            else
              "//" <> other
            end
        end
      end)
    end

  # Expose these choices via application config so endpoint/plug can pick them up
  config :game_server_web, :cors_allowed_origins, cors_allowed_origins

  # Rate Limiting — configurable per-IP request throttling via RATE_LIMIT_* env vars.
  rate_limit_opts = [
    general_limit: String.to_integer(System.get_env("RATE_LIMIT_HTTP_GENERAL_LIMIT", "240")),
    general_window: String.to_integer(System.get_env("RATE_LIMIT_HTTP_GENERAL_WINDOW", "60000")),
    auth_limit: String.to_integer(System.get_env("RATE_LIMIT_HTTP_AUTH_LIMIT", "10")),
    auth_window: String.to_integer(System.get_env("RATE_LIMIT_HTTP_AUTH_WINDOW", "60000")),
    ws_limit: String.to_integer(System.get_env("RATE_LIMIT_WS_LIMIT", "60")),
    ws_window: String.to_integer(System.get_env("RATE_LIMIT_WS_WINDOW", "10000")),
    dc_limit: String.to_integer(System.get_env("RATE_LIMIT_WEBRTC_LIMIT", "300")),
    dc_window: String.to_integer(System.get_env("RATE_LIMIT_WEBRTC_WINDOW", "10000"))
  ]

  config :game_server_web, GameServerWeb.Plugs.RateLimiter, rate_limit_opts

  endpoint_config =
    [
      url: [host: host, port: if(scheme == "https", do: 443, else: port), scheme: scheme],
      http: [
        # Enable IPv6 and bind on all interfaces.
        # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
        # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
        # for details about using IPv6 vs IPv4 and loopback vs public addresses.
        ip: {0, 0, 0, 0, 0, 0, 0, 0},
        port: port
      ],
      secret_key_base: secret_key_base
    ]
    |> then(fn cfg ->
      if check_origin == nil, do: cfg, else: Keyword.put(cfg, :check_origin, check_origin)
    end)

  # ── HTTPS / TLS ─────────────────────────────────────────────────────────────
  # Enable native HTTPS directly in Phoenix/Bandit by setting SSL_CERTFILE and
  # SSL_KEYFILE to the paths of your certificate and private key PEM files.
  # Erlang's :ssl automatically reloads certificate files from disk, so
  # renewed certificates (e.g. from certbot) are picked up without restart.
  #
  # Environment variables:
  #   SSL_CERTFILE  — path to fullchain.pem (certificate + CA chain)
  #   SSL_KEYFILE   — path to privkey.pem
  #   HTTPS_PORT    — HTTPS listen port (default: 443)
  #   FORCE_SSL     — set to "true" to redirect HTTP → HTTPS and enable HSTS
  #   ACME_WEBROOT  — webroot directory for Let's Encrypt HTTP-01 challenge files
  #                   (default: /var/www/acme when SSL is enabled; same path you
  #                   pass to certbot --webroot-path)
  ssl_certfile = System.get_env("SSL_CERTFILE")
  ssl_keyfile = System.get_env("SSL_KEYFILE")

  # Validate that certificate files actually exist before enabling HTTPS.
  # This prevents a crash on startup when SSL_CERTFILE/SSL_KEYFILE are set
  # but the files haven't been created yet (e.g. before running certbot).
  ssl_files_ready? =
    if ssl_certfile && ssl_keyfile do
      cert_exists? = File.exists?(ssl_certfile)
      key_exists? = File.exists?(ssl_keyfile)

      unless cert_exists? do
        require Logger

        Logger.warning(
          "SSL_CERTFILE is set to #{ssl_certfile} but the file does not exist. " <>
            "HTTPS will NOT be enabled. Run certbot to generate the certificate first, " <>
            "then restart the server."
        )
      end

      unless key_exists? do
        require Logger

        Logger.warning(
          "SSL_KEYFILE is set to #{ssl_keyfile} but the file does not exist. " <>
            "HTTPS will NOT be enabled. Run certbot to generate the certificate first, " <>
            "then restart the server."
        )
      end

      cert_exists? and key_exists?
    else
      false
    end

  endpoint_config =
    if ssl_files_ready? do
      https_port = GameServer.Env.integer("HTTPS_PORT", 443)

      https_opts = [
        ip: {0, 0, 0, 0, 0, 0, 0, 0},
        port: https_port,
        cipher_suite: :strong,
        certfile: ssl_certfile,
        keyfile: ssl_keyfile
        # Suppress noisy TLS handshake notices from bots/scanners
        # probing with old TLS versions or unsupported cipher suites.
      ]

      Keyword.put(endpoint_config, :https, https_opts)
    else
      endpoint_config
    end

  # ACME webroot for Let's Encrypt HTTP-01 validation.
  # Certbot (or any ACME client) writes challenge tokens to
  # <webroot>/.well-known/acme-challenge/<token>; the AcmeChallenge plug
  # serves them over HTTP so the CA can verify domain ownership.
  # This is the same path you pass to `certbot --webroot-path`.
  # Enabled whenever SSL_CERTFILE is set (even if the file doesn't exist yet)
  # so certbot can complete its first challenge.
  acme_webroot =
    System.get_env("ACME_WEBROOT") ||
      if(ssl_certfile, do: "/var/www/acme")

  if acme_webroot do
    # Ensure the ACME webroot directory exists. If it doesn't, try to create
    # it so certbot can write challenge tokens before its first run. If creation
    # fails (e.g. permission denied), log a warning and skip the config so the
    # server doesn't emit confusing errors when serving challenge requests.
    acme_dir_ready? =
      if File.dir?(acme_webroot) do
        true
      else
        case File.mkdir_p(acme_webroot) do
          :ok ->
            true

          {:error, reason} ->
            require Logger

            Logger.warning(
              "ACME webroot directory #{acme_webroot} does not exist and could not be created " <>
                "(#{reason}). ACME HTTP-01 challenges will not be served. " <>
                "Create the directory manually: sudo mkdir -p #{acme_webroot}"
            )

            false
        end
      end

    if acme_dir_ready? do
      config :game_server_web, :acme_webroot, acme_webroot
    end
  end

  # Force SSL — redirect all HTTP to HTTPS and set HSTS header.
  # Only enabled when cert files actually exist (ssl_files_ready?), otherwise
  # we'd redirect to HTTPS that isn't listening and break the server.
  # The ACME challenge path and health-check endpoints are excluded so
  # certbot can complete HTTP-01 validation and load balancers can probe.
  force_ssl = GameServer.Env.bool("FORCE_SSL", ssl_files_ready?)

  endpoint_config =
    if force_ssl do
      Keyword.put(endpoint_config, :force_ssl,
        rewrite_on: [:x_forwarded_proto, :x_forwarded_port],
        hsts: true,
        expires: 31_536_000,
        subdomains: true,
        preload: true,
        exclude: fn conn ->
          conn.host in ["localhost", "127.0.0.1"] or
            String.starts_with?(conn.request_path, "/.well-known/acme-challenge") or
            conn.request_path == "/api/v1/health"
        end
      )
    else
      endpoint_config
    end

  config :game_server_web, GameServerWeb.Endpoint, endpoint_config

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

    # Enable Swoosh Local in-memory mailbox storage so the mailbox preview works.
    # In real production deployments you should configure SMTP instead.
    config :swoosh, local: true

    # Disable swoosh api client for local adapter
    config :swoosh, :api_client, false
  end

  # ── Metrics auth ──
  # Set METRICS_AUTH_TOKEN to require Bearer token for /metrics endpoint.
  # Without it, the endpoint is open (suitable for internal Docker networks).
  if token = System.get_env("METRICS_AUTH_TOKEN") do
    config :game_server_web, :metrics_auth_token, token
  end

  # ── GeoIP database ──
  # Prefer the host-owned default path under data/, but
  # still allow GEOIP_DB_PATH to override it for custom deployments.
  default_geoip_db = Path.expand("../data/GeoLite2-Country.mmdb", __DIR__)

  geoip_db =
    System.get_env("GEOIP_DB_PATH") ||
      if File.exists?(default_geoip_db), do: default_geoip_db, else: nil

  if geoip_db do
    config :geolix,
      databases: [
        %{
          id: :country,
          adapter: Geolix.Adapter.MMDB2,
          source: geoip_db
        }
      ]
  end
end
