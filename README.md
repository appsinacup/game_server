![gamend banner](https://github.com/appsinacup/game_server/blob/main/priv/static/images/banner.png?raw=true)

-----

**Open source _game server_ with _authentication, users, lobbies, server scripting and an admin portal_.**

Game + Backend = Gamend

-----

[Discord](https://discord.com/invite/56dMud8HYn) | [Elixir Docs](https://appsinacup.github.io/game_server/) | [API Docs](https://gamend.appsinacup.com/api/docs) | [Guides](https://gamend.appsinacup.com/docs/setup) | [Starter Template](https://github.com/appsinacup/gamend_starter) | [Architecture](./ARCHITECTURE.md)

To start your server:

* Run `mix setup` to install and setup dependencies.

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Authentication

This application supports two authentication methods:

### Browser Authentication (Session-based)

Traditional session-based authentication for browser flows:
- Email/password registration and login
- Discord OAuth
- Apple Sing In
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

## How to deploy [Starter Template](https://github.com/appsinacup/gamend_starter)

1. Fork this repo (or create a Dockerfile like this):

```sh
FROM ghcr.io/appsinacup/game_server:latest

WORKDIR /app

COPY modules/ ./modules/
```

2. Go to fly.io and deploy (select the forked repo).
3. Set secrets all values in `.env.example`. Run locally `fly secrets sync` and `fly secrets deploy` (in case secrets don't deploy/update).
4. Configure all things from [Guides](https://gamend.appsinacup.com/docs/setup) page.
5. Monthly cost (without Postgres) will be about 5$.

## Git hooks

To install precommit hooks, run:

```sh
	bin/setup-git-hooks
```

To skip, run:

```sh
	SKIP_PRECOMMIT=1 git commit
```
