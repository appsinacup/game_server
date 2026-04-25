#!/bin/bash
# Run Ecto migrations against PostgreSQL database
# Usage: ./migrate.sh

set -e

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOST_DIR="$ROOT_DIR/apps/game_server_host"

export POSTGRES_HOST=localhost
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=postgres
export POSTGRES_DB=game_server_dev

cd "$HOST_DIR"
mix ecto.migrate
