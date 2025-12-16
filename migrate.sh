#!/bin/bash
# Run Ecto migrations against PostgreSQL database
# Usage: ./migrate.sh

export POSTGRES_HOST=localhost
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=postgres
export POSTGRES_DB=game_server_dev

mix do --app game_server_web ecto.migrate
