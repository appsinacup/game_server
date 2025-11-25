# Data schema changes — Lobbies

This document describes the new lobbies model and the small change to the `users` table.

## Lobby model (table: lobbies)

- id : integer (PK)
- name : string (unique, required)
- title : string (optional)
- host_id : integer (references users.id) — nullable (server-managed or hostless lobbies may leave it nil)
- hostless : boolean flag (default false) — indicates the lobby is managed by the server (but public creation of hostless lobbies is disabled)
- max_users : integer default 8 — maximum concurrent users in this lobby
- is_hidden : boolean default false — hidden lobbies are never returned in public list APIs
- is_locked : boolean default false — requires password to join
- password_hash : string (bcrypt hashed password)
- metadata : map (JSON/object) — free-form key/value metadata for search and filtering
- inserted_at, updated_at : timestamps

Notes:
- `is_private` flag has been removed. Use `is_hidden` (not shown) and `is_locked` for privacy or restricted access.
- Listing APIs intentionally never return hidden lobbies; only administrative interfaces can view hidden lobbies.

## User model (table: users) change

- A new column `lobby_id` was added (nullable, references `lobbies.id`).
  - Each user may belong to at most one lobby at any time.
  - Lobby membership is represented by the `users.lobby_id` foreign key (removes the previous join table `lobby_users`).

Migration files:
- `priv/repo/migrations/20251125010000_create_lobbies_and_lobby_users.exs` — initial lobbies and old join table; project later migrated to membership in `users`.
- `priv/repo/migrations/20251125030000_migrate_membership_to_users.exs` — adds `users.lobby_id` and drops the `lobby_users` join table.
