import Config

config :game_server_web, GameServerWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"

config :swoosh, api_client: Swoosh.ApiClient.Req
config :swoosh, local: false

config :logger, level: :info

config :logger, compile_time_purge_matching: [[level_lower_than: :info]]
