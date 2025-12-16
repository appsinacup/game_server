#!/bin/bash
# Load environment variables from .env file and start the server

if [ -f .env ]; then
  # Source .env and export all variables. Using `export $(cat .env | xargs)` breaks
  # multiline values (eg. APPLE_PRIVATE_KEY). `set -a; . .env; set +a` safely
  # exports variables while preserving multi-line values and quoting.
  set -a
  # shellcheck disable=SC1091
  . .env
  set +a
fi

# Ensure the runnable host is compiled (so adapter configuration loaded from .env/config files)
MIX_ENV=dev mix do --app game_server_host compile

# Boot the runnable host Phoenix app
MIX_ENV=dev mix do --app game_server_host phx.server
