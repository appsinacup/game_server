![gamend banner](https://github.com/appsinacup/game_server/blob/main/apps/game_server_web/priv/static/images/banner.png?raw=true)

# Gamend

**Open source game server with authentication, users, lobbies, groups, parties, friends, chat, notifications, achievements, leaderboards, server scripting and an admin portal**

Game + Backend = Gamend

[Discord](https://discord.com/invite/v649emcpAu) | [Guides](https://gamend.appsinacup.com/docs/setup) | [API Docs](https://gamend.appsinacup.com/api/docs) | [Elixir Docs](https://appsinacup.github.io/game_server/) | [Starter Template](https://github.com/appsinacup/gamend_starter)

## Features

- **Auth** — Email/password, magic link, OAuth (Discord, Google, Apple, Facebook, Steam), JWT API tokens
- **Users** — Profiles, metadata, device tokens, account lifecycle
- **Lobbies** — Host-managed, max users, hidden/locked, passwords, real-time updates
- **Groups** — Public / private / hidden communities, roles, join requests, invites
- **Parties** — Ephemeral groups (2–10 players), invite-based, lobby integration
- **Friends** — Requests, accept/reject, blocking
- **Chat** — Lobby, group, party, and friend DMs with read cursors and unread counts
- **Notifications** — Typed notifications for all social events, read/unread, real-time delivery
- **Achievements** — Progress tracking, hidden achievements, unlock percentage (rarity), admin management
- **Leaderboards** — Global and per-user rankings
- **Key-Value Store** — Server-side key-value storage with access control hooks
- **Server Scripting** — Elixir hooks on server events (login, lobby created, achievement unlocked, etc.)
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
