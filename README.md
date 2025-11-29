![gamend banner](https://github.com/appsinacup/game_server/blob/main/priv/static/images/banner.png?raw=true)

-----

**Open source _game server_ with _authentication, users, lobbies, and an admin portal_.**

Game + Backend = Gamend

-----

[Discord](https://discord.com/invite/56dMud8HYn) | [Elixir Docs](https://appsinacup.github.io/game_server/) | [API Docs](https://gamend.appsinacup.com/api/docs) | [Guides](https://gamend.appsinacup.com/docs/setup)

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

## How to deploy

1. Fork this repo.
2. Go to fly.io and deploy (select the forked repo).
3. Set secrets all values in `.env.example`. Run locally `fly secrets sync` and `fly secrets deploy` (in case secrets don't deploy/update).
4. Configure all things from [Guides](https://gamend.appsinacup.com/docs/setup) page.
5. Monthly cost (without Postgres) will be about 5$.
