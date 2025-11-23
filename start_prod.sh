#!/bin/bash
# Load environment variables from .env file and start the server

if [ -f .env ]; then
  export $(cat .env | xargs)
fi

# Generate SECRET_KEY_BASE if not set
if [ -z "$SECRET_KEY_BASE" ]; then
  export SECRET_KEY_BASE=$(mix phx.gen.secret)
  echo "Generated SECRET_KEY_BASE: $SECRET_KEY_BASE"
fi

mix phx.server
