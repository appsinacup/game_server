import Config

# Compatibility shim for umbrella-root Mix commands.
# The real compile-time config now lives under the host app.
import_config "../apps/game_server_host/config/config.exs"
