import Config

if System.get_env("DATABASE_URL") ||
     (System.get_env("POSTGRES_HOST") && System.get_env("POSTGRES_USER")) do
  database_url =
    System.get_env("DATABASE_URL") ||
      "ecto://#{System.get_env("POSTGRES_USER")}:#{System.get_env("POSTGRES_PASSWORD")}@#{System.get_env("POSTGRES_HOST")}:#{System.get_env("POSTGRES_PORT", "5432")}/#{System.get_env("POSTGRES_DB", "game_server_web_dev")}"

  config :game_server_core, GameServer.Repo,
    url: database_url,
    adapter: Ecto.Adapters.Postgres,
    stacktrace: true,
    show_sensitive_data_on_connection_error: true,
    pool_size: 10
else
  database_path = Path.expand("../priv/db/game_server_web_dev.db", __DIR__)
  File.mkdir_p!(Path.dirname(database_path))

  config :game_server_core, GameServer.Repo,
    database: database_path,
    adapter: Ecto.Adapters.SQLite3,
    stacktrace: true,
    show_sensitive_data_on_connection_error: true,
    pool_size: 10
end

config :game_server_web, GameServerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT") || "4000")],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "l/tTJZ4KUNjIfiUsNQDQLWOTgFlyiOz8RQ2EgSRa7mopMzPLJuu7/8s5pA7iiSgO",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:game_server_web, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:game_server_web, ~w(--watch)]}
  ]

config :game_server_web, GameServerWeb.Endpoint,
  live_reload: [
    web_console_logger: true,
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/game_server_web/(?:controllers|live|components|router|plugs)/?.*\.(ex|heex)$"
    ]
  ]

config :game_server_web, dev_routes: true

config :logger, :default_formatter, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true,
  enable_expensive_runtime_checks: true

if System.get_env("SMTP_PASSWORD") do
  config :game_server_core, GameServer.Mailer,
    adapter: Swoosh.Adapters.SMTP,
    relay: System.get_env("SMTP_RELAY"),
    username: System.get_env("SMTP_USERNAME"),
    password: System.get_env("SMTP_PASSWORD"),
    port: String.to_integer(System.get_env("SMTP_PORT") || "587"),
    tls: String.to_existing_atom(System.get_env("SMTP_TLS") || "never"),
    ssl: String.to_existing_atom(System.get_env("SMTP_SSL") || "true"),
    auth: :always,
    no_mx_lookups: false,
    retries: 2,
    sockopts: [
      versions: [:"tlsv1.2", :"tlsv1.3"],
      verify: :verify_peer,
      cacerts: :public_key.cacerts_get(),
      depth: 3,
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ],
      server_name_indication:
        if(sni = System.get_env("SMTP_SNI"), do: String.to_charlist(sni), else: :disable)
    ]

  config :swoosh, :api_client, Swoosh.ApiClient.Req
else
  config :swoosh, :api_client, false
end

config :game_server_web, GameServerWeb.Auth.Guardian,
  issuer: "game_server",
  secret_key: "l/tTJZ4KUNjIfiUsNQDQLWOTgFlyiOz8RQ2EgSRa7mopMzPLJuu7/8s5pA7iiSgO",
  ttl: {15, :minutes}
