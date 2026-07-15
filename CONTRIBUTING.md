# Contributing

Checklist for adding a feature. Keep PRs small; one feature at a time.

## Data model (if the feature stores data)

- Schema in `apps/game_server_core/lib/game_server/<feature>/` using `use GameServer.Schema` (UUIDv7 ids).
- Migration in `apps/game_server_core/priv/repo/migrations/`. Must work on **both SQLite and Postgres** — no `ALTER COLUMN` on SQLite (rebuild the table instead), test with `DATABASE_ADAPTER=postgres` too.
- Size/count caps in `GameServer.Limits` (auto-exposed as `LIMIT_*` env vars).
- Document the tables in the [Data Schema](https://gamend.appsinacup.com/docs/setup) docs page (`lib/game_server_web/host_public_docs/data_schema.html.heex`).

## Functionality

- Context module in `game_server_core` (business logic, no web concerns).
- Hooks in `GameServer.Hooks` (`before_*` / `after_*`) so plugins can extend it.
- API controller in `apps/game_server_web/.../controllers/api/v1/` with OpenAPI schemas (ids are `type: :string, format: :uuid`).
- Routes in `apps/game_server_web/lib/game_server_web/router/shared.ex`. Public listing endpoints get a `LIST_*_ENABLED` feature gate.
- Realtime events via channel/PubSub if clients need pushes.

## Tests

- Context tests + controller tests in `apps/game_server_web/test/`.
- Run against both adapters: `mix test` and with `POSTGRES_HOST` set.

## Admin

- Admin LiveView page in `apps/game_server_web/lib/game_server_web/live/admin_live/`.
- Admin API controller under `controllers/api/v1/admin/` if applicable.

## Finish

- Docs page in `lib/game_server_web/host_public_docs/` if user-facing.
- New env vars documented in `.env.example`.
- `CHANGELOG.md` entry (`[added]` / `[changed]` / `[breaking]`).
- `mix format`, `mix credo --strict`, full `mix test` green.
- SDKs regenerate from the OpenAPI spec in CI — no manual SDK edits.
