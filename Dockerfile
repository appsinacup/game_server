FROM elixir:1.19-slim

# Install git and other build dependencies
RUN apt-get update && \
    # Install build tools + sqlite dev headers so Exqlite NIF builds in-image
    apt-get install -y git build-essential libsqlite3-dev sqlite3 pkg-config && \
    rm -rf /var/lib/apt/lists/*

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set working directory
WORKDIR /app

# Set environment to production
ENV MIX_ENV=prod

COPY mix.exs mix.lock ./

# Install dependencies
RUN mix deps.get


# Copy the rest of the application
COPY . .

# Compile the application FIRST (generates phoenix-colocated hooks)
RUN mix compile

# Build and digest static assets for production (creates priv/static/cache_manifest.json)
# This now runs AFTER compile, so phoenix-colocated hooks exist
RUN mix assets.deploy

# Expose port
EXPOSE 4000

# Default command - run migrations and start server
CMD ["sh", "-c", "mix ecto.migrate && mix phx.server"]
