#!/bin/bash
# Load environment variables from .env file and start the server

if [ -f .env ]; then
  export $(cat .env | xargs)
fi

mix phx.server
