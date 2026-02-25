![gamend banner](https://github.com/appsinacup/game_server/blob/main/apps/game_server_web/priv/static/images/banner.png?raw=true)

-----

**Open source _game server_ with _authentication, users, lobbies, groups, notifications, server scripting and an admin portal_.**

Game + Backend = Gamend

-----

[Discord](https://discord.com/invite/56dMud8HYn) | [Elixir Docs](https://appsinacup.github.io/game_server/) | [API Docs](https://gamend.appsinacup.com/api/docs) | [Guides](https://gamend.appsinacup.com/docs/setup) | [Starter Template](https://github.com/appsinacup/gamend_starter) | [Deployment Tutorial](https://appsinacup.com/gamend-deploy/) | [Scaling Article](https://appsinacup.com/gamend-scaling/)

To start your server:

* Run `mix setup` to install and setup dependencies.

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Authentication

This application supports two authentication methods:

### Browser Authentication (Session-based)

Traditional session-based authentication for browser flows:
- Email/password registration and login
- Discord OAuth
- Apple Sign In
- Google OAuth
- Steam OpenID
- Facebook OAuth
- Session tokens stored in database
- Managed via cookies and Phoenix sessions

### API Authentication (JWT)

Modern JWT authentication using access + refresh tokens (industry standard):

**Token Types:**
- **Access tokens**: Short-lived (15 minutes), used for API requests
- **Refresh tokens**: Long-lived (30 days), used to obtain new access tokens

## Users

User management:

- Multiple sign-in flows supported: Email/password, device tokens (SDK), and OAuth (Discord / Google / Facebook / Apple).
- Per-user profile metadata as JSON
- Account lifecycle: registration, login, password reset, and account deletion endpoints.

## Friends

Social features:

- Friend requests with accept / reject / block flows.

## Lobbies

Matchmaking and lobbies:

- Host-managed behavior, max users, hidden/locked states, and password protection.
- Public APIs are provided for listing, creating, joining, leaving, updating and kicking.

## Notifications

User-to-user notification system:

- Send notifications between users (sender must be a friend of the recipient).
- Persistent storage with read/unread tracking.
- Pagination and filtering support.
- Admin API for creating server-wide notifications (bypasses friend requirement).
- Real-time delivery via PubSub to recipient's channel.

## Groups

Persistent communities with role-based administration:

- **Public groups** – anyone can join directly.
- **Private groups** – users send a join request; group admins approve or reject.
- **Hidden groups** – invite-only; admins invite users via the notification system.
- Configurable max members (default 100, 1–10 000).
- Admin roles: kick members, rename group, change max members, promote/demote.
- Cannot reduce max members below current member count.
- Unique group names enforced at the database level.
- Server-settable JSON metadata (similar to lobbies).
- Filter/search by name, title, type, metadata (`lang_tag`), and member count range.
- Cached with version-key invalidation for fast reads.

## Server scripting (Elixir)

Extendable server behavior:

- Hooks on server events (eg. on_user_login, on_lobby_created)

## Client SDK

- [Javascript SDK](https://www.npmjs.com/package/@ughuuu/game_server)
- [Godot SDK](https://godotengine.org/asset-library/asset/4510)

## Elixir SDK

The `sdk/` folder contains stub modules that provide IDE autocomplete and documentation for custom hook scripts. When building your own [Starter Template](https://github.com/appsinacup/gamend_starter), add the SDK as a dependency:

```elixir
# mix.exs
defp deps do
  [
    {:game_server_sdk, github: "appsinacup/game_server", sparse: "sdk"}
  ]
end
```

Example hook with autocomplete:

```elixir
defmodule MyApp.Hooks do
  use GameServer.Hooks

  @impl true
  def after_user_login(user) do
    # IDE autocomplete works for user fields and Accounts functions
    GameServer.Accounts.update_user(user, %{
      metadata: Map.put(user.metadata, "last_login", DateTime.utc_now())
    })
    :ok
  end
end
```

To regenerate SDK stubs from the main project:

```sh
mix gen.sdk
```

## How to deploy ([Starter Template](https://github.com/appsinacup/gamend_starter))

1. Fork this repo (or create a Dockerfile like this):

```sh
FROM ghcr.io/appsinacup/game_server:latest

WORKDIR /app

COPY modules/ ./modules/
COPY apps/game_server_web/priv/static/assets/css/theme/ ./apps/game_server_web/priv/static/assets/css/theme/
COPY apps/game_server_web/priv/static/images/ ./apps/game_server_web/priv/static/images/

# Build any plugins shipped in this repo (overlay) so they're available at runtime.
ARG GAME_SERVER_PLUGINS_DIR=modules/plugins
ENV GAME_SERVER_PLUGINS_DIR=${GAME_SERVER_PLUGINS_DIR}

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
```

2. Go to fly.io and deploy (select the forked repo).
3. Set secrets all values in `.env.example`. Run locally `fly secrets sync` and `fly secrets deploy` (in case secrets don't deploy/update).

4. Configure all things from [Guides](https://gamend.appsinacup.com/docs/setup) page.
5. Monthly cost (without Postgres) will be about 5$.

## Run locally

To run locally using Elixir:

1. Configure the `.env` file (copy `.env.example` to `.env`).


2. Then run:

```sh
./start.sh
```

## Run locally (Docker Compose)

To run with single instance, run:

```sh
docker compose up
```

To run multi instance with 2 instances, nginx load balancer, PostgreSQL database, Redis cache, run:

```sh
docker compose -f docker-compose.multi.yml up --scale app=2
```

## Git hooks

To install precommit hooks, run:

```sh
	bin/setup-git-hooks
```

To skip, run:

```sh
	SKIP_PRECOMMIT=1 git commit
```
