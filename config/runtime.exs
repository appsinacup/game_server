import Config

# Compatibility shim for umbrella-root Mix commands and release tooling.
# The real runtime config now lives under the host app.
Code.require_file(Path.expand("../apps/game_server_host/config/runtime.exs", __DIR__))
