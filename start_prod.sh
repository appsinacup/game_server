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

# Generate SECRET_KEY_BASE if not set
if [ -z "$SECRET_KEY_BASE" ]; then
  export SECRET_KEY_BASE=$(mix phx.gen.secret)
  echo "Generated SECRET_KEY_BASE: $SECRET_KEY_BASE"
fi

mix phx.server
