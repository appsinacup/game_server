FROM elixir:1.19-slim

# Install git and other build dependencies
RUN apt-get update && \
    # Install build tools + sqlite dev headers so Exqlite NIF builds in-image
    apt-get install -y git build-essential libsqlite3-dev sqlite3 pkg-config ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set working directory
WORKDIR /app

# Set environment to production
ENV MIX_ENV=prod

# Plugin build configuration
ARG GAME_SERVER_PLUGINS_DIR=modules/plugins_examples
ENV GAME_SERVER_PLUGINS_DIR=${GAME_SERVER_PLUGINS_DIR}

ARG APP_VERSION=1.0.0
ENV APP_VERSION=${APP_VERSION}
RUN echo -n "${APP_VERSION}" > /app/VERSION

COPY mix.exs mix.lock ./

# Umbrella apps: include their mix.exs files so deps can be resolved in a cached layer
COPY apps/game_server_web/mix.exs apps/game_server_web/mix.exs
COPY apps/game_server_core/mix.exs apps/game_server_core/mix.exs
COPY apps/game_server_host/mix.exs apps/game_server_host/mix.exs

# Install dependencies
RUN mix deps.get


COPY . .

# Build any plugins that ship with the repository
RUN if [ -d "${GAME_SERVER_PLUGINS_DIR}" ]; then \
        for plugin_path in ${GAME_SERVER_PLUGINS_DIR}/*; do \
            if [ -d "${plugin_path}" ] && [ -f "${plugin_path}/mix.exs" ]; then \
                echo "Building plugin ${plugin_path}"; \
                (cd "${plugin_path}" && mix deps.get && mix compile && mix plugin.bundle); \
            fi; \
        done; \
    else \
        echo "Plugin sources dir ${GAME_SERVER_PLUGINS_DIR} missing, skipping plugin builds"; \
    fi

# Compile the application FIRST (generates phoenix-colocated hooks)
RUN mix do --app game_server_host compile

# Build and digest static assets for production (creates priv/static/cache_manifest.json)
# This now runs AFTER compile, so phoenix-colocated hooks exist
RUN mix do --app game_server_host assets.deploy

# Expose port
EXPOSE 4000

# Default command - run migrations and start server
CMD ["sh", "-c", "mix do --app game_server_host ecto.migrate && mix do --app game_server_host phx.server"]
