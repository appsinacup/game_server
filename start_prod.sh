#!/bin/bash
# Load environment variables from .env file and start the server

set -e

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOST_DIR="$ROOT_DIR"
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

# Generate SECRET_KEY_BASE if not set
if [ -z "$SECRET_KEY_BASE" ]; then
  export SECRET_KEY_BASE=$(mix phx.gen.secret)
  echo "Generated SECRET_KEY_BASE: $SECRET_KEY_BASE"
fi

if [ ! -f "$HOST_CSS" ] || [ ! -f "$WEB_JS" ]; then
  (
    cd "$HOST_DIR"
    MIX_ENV=prod mix assets.deploy
  )
fi

(
  cd "$HOST_DIR"
  MIX_ENV=prod mix ecto.setup
)

cd "$HOST_DIR"
MIX_ENV=prod mix phx.server
