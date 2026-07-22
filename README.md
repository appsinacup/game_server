![gamend banner](https://github.com/appsinacup/game_server/blob/main/priv/static/images/banner.png?raw=true)

# Gamend

**Open source Elixir game server with authentication, users, lobbies, groups, parties, friends, chat, notifications, achievements, leaderboards, tournaments, payments, server scripting and an admin portal with HTTP, WebSocket, and WebRTC support and SDK for JS and Godot.**

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
- **Payments** — Stripe Checkout, Google Play, App Store, and Steam provider flows with receipt validation, webhooks, entitlements, refunds, and admin tools
- **Key-Value Store** — Server-side key-value storage with access control hooks
- **Server Scripting** — Elixir hooks on server events (login, lobby created, achievement unlocked, etc.)
- **Background Jobs** — Durable, retryable background and scheduled (cron) jobs from server hooks, on Postgres or SQLite
- **Object Storage** — Avatar/UGC uploads with a pluggable backend: local disk or any S3-compatible service (AWS S3, Cloudflare R2, MinIO, …)
- **Admin Portal** — Built-in web dashboard for managing all resources

## Client SDKs

- [JavaScript SDK](https://www.npmjs.com/package/@ughuuu/game_server)
- [Godot SDK](https://godotengine.org/asset-library/asset/4510)
- [Elixir SDK](sdk/) — Stub modules for IDE autocomplete in custom hooks

## Run Locally

### Prerequisites

- **Elixir 1.20 & Erlang/OTP 29** — see [`.tool-versions`](.tool-versions); with [asdf](https://asdf-vm.com/) just run `asdf install`
- **Rust** ([rustup](https://rustup.rs/)) — required to build the WebRTC native dependency (`ex_sctp`)
- **PostgreSQL** — optional. Dev uses SQLite by default; set `POSTGRES_*` or `DATABASE_URL` in `.env` to use Postgres instead. The adapter is chosen at compile time, so after changing these run `mix deps.clean game_server_core game_server_web --build` and recompile. (Docker: use the `-postgres` image tag or build with `DATABASE_ADAPTER=postgres`.)

### First run

```sh
cp .env.example .env
mix setup
mix dev.start
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

## AI instructions file

This project has a [.github/copilot-instructions.md](.github/copilot-instructions.md) file you can use.
