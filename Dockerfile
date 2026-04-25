FROM elixir:1.19-slim

# Install git and other build dependencies
RUN apt-get update && \
    # Install build tools + sqlite dev headers so Exqlite NIF builds in-image
    # libssl-dev is required by ex_dtls (WebRTC DTLS encryption)
    apt-get install -y git build-essential libsqlite3-dev sqlite3 pkg-config ca-certificates curl libssl-dev && \
    rm -rf /var/lib/apt/lists/*

# Install Rust toolchain (required by ex_sctp for WebRTC DataChannels)
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set working directory
WORKDIR /app

# Set environment to production
ENV MIX_ENV=prod

# Database adapter for compile-time selection (sqlite or postgres).
# Set to "postgres" when deploying with PostgreSQL.
ARG DATABASE_ADAPTER=sqlite
ENV DATABASE_ADAPTER=${DATABASE_ADAPTER}

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

# Install dependencies
RUN mix deps.get


COPY . .

# Build any plugins that ship with the repository. Copy paste this to your own Dockerfile
RUN if [ -d "${GAME_SERVER_PLUGINS_DIR}" ]; then \
        for plugin_path in ${GAME_SERVER_PLUGINS_DIR}/*; do \
            if [ -d "${plugin_path}" ] && [ -f "${plugin_path}/mix.exs" ]; then \
                echo "Building plugin ${plugin_path}"; \
                (cd "${plugin_path}" && mix deps.get && mix compile && mix plugin.bundle --verbose); \
            fi; \
        done; \
    else \
        echo "Plugin sources dir ${GAME_SERVER_PLUGINS_DIR} missing, skipping plugin builds"; \
    fi

# Compile the application FIRST (generates phoenix-colocated hooks)
RUN mix compile

# Build and digest static assets for production for both the root host and game_server_web.
RUN mix assets.deploy

# Expose ports (HTTP + HTTPS)
EXPOSE 4000 443

# Default command - create DB (if needed), run migrations, and start server
CMD ["sh", "-c", "mix ecto.create --quiet 2>/dev/null; mix ecto.migrate && mix phx.server"]
