#!/bin/bash
# Load environment variables from .env file and start the server

set -e

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOST_DIR="$ROOT_DIR/apps/game_server_host"
HOST_CSS="$HOST_DIR/priv/static/assets/css/app.css"
WEB_JS="$ROOT_DIR/apps/game_server_web/priv/static/assets/js/app.js"

if [ -f .env ]; then
  # Source .env and export all variables. Using `export $(cat .env | xargs)` breaks
  # multiline values (eg. APPLE_PRIVATE_KEY). `set -a; . .env; set +a` safely
  # exports variables while preserving multi-line values and quoting.
  set -a
  # shellcheck disable=SC1091
  . .env
  set +a
fi

if [ ! -f "$HOST_CSS" ] || [ ! -f "$WEB_JS" ]; then
  (
    cd "$HOST_DIR"
    MIX_ENV=dev mix assets.build
  )
fi

# Ensure the dev database exists and current host-local migrations are applied
# before supervised workers start querying tables like users.
(
  cd "$HOST_DIR"
  MIX_ENV=dev mix ecto.create --quiet >/dev/null 2>&1 || true
  MIX_ENV=dev mix ecto.migrate
)

# Ensure the runnable host is compiled (so adapter configuration loaded from .env/config files)
(
  cd "$HOST_DIR"
  MIX_ENV=dev mix compile
)

# Boot the runnable host Phoenix app
cd "$HOST_DIR"
MIX_ENV=dev mix phx.server
