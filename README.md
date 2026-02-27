![gamend banner](https://github.com/appsinacup/game_server/blob/main/apps/game_server_web/priv/static/images/banner.png?raw=true)

# Gamend

**Open source game server with authentication, users, lobbies, groups, notifications, server scripting and an admin portal**

Game + Backend = Gamend

[Discord](https://discord.com/invite/56dMud8HYn) | [Guides](https://gamend.appsinacup.com/docs/setup) | [API Docs](https://gamend.appsinacup.com/api/docs) | [Elixir Docs](https://appsinacup.github.io/game_server/) | [Starter Template](https://github.com/appsinacup/gamend_starter)

## Features

- **Auth** — Email/password, magic link, OAuth (Discord, Google, Apple, Facebook, Steam), JWT API tokens
- **Users** — Profiles, metadata, device tokens, account lifecycle
- **Lobbies** — Host-managed, max users, hidden/locked, passwords, real-time updates
- **Groups** — Public / private / hidden communities, roles, join requests, invites
- **Friends** — Requests, accept/reject, blocking
- **Notifications** — User-to-user + server-wide, read/unread, real-time delivery
- **Server Scripting** — Elixir hooks on server events (login, lobby created, etc.)
- **Admin Portal** — Built-in web dashboard for managing all resources

## Client SDKs

- [JavaScript SDK](https://www.npmjs.com/package/@ughuuu/game_server)
- [Godot SDK](https://godotengine.org/asset-library/asset/4510)
- [Elixir SDK](sdk/) — Stub modules for IDE autocomplete in custom hooks

## Quick Start

```sh
cp .env.example .env
./start.sh
```

Visit [localhost:4000](http://localhost:4000).

## Docker

```sh
# Single instance
docker compose up

# Multi-instance (2 apps + nginx + PostgreSQL + Redis)
docker compose -f docker-compose.multi.yml up --scale app=2
```

## Deploy

See the [Deployment Tutorial](https://appsinacup.com/gamend-deploy/) and [Starter Template](https://github.com/appsinacup/gamend_starter) for production deployment on fly.io (~$5/month without Postgres).
