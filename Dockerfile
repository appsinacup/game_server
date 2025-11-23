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

# Install dependencies for production and compile them (so NIFs/deps are built)
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy the rest of the application
COPY . .

# Build and digest static assets for production (creates priv/static/cache_manifest.json)
RUN mix assets.deploy

# Compile the application
RUN mix compile

# Expose port
EXPOSE 4000

# Default command - run migrations and start server
CMD ["sh", "-c", "mix ecto.migrate && mix phx.server"]
