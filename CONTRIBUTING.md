# Contributing

Checklist for adding a feature. Keep PRs small; one feature at a time.

## Data model (if the feature stores data)

- Schema in `apps/game_server_core/lib/game_server/<feature>/` using `use GameServer.Schema` (UUIDv7 ids).
- Migration in `apps/game_server_core/priv/repo/migrations/`. Must work on **both SQLite and Postgres** — no `ALTER COLUMN` and no `DISTINCT ON` on SQLite (rebuild the table / group in Elixir instead), test with `DATABASE_ADAPTER=postgres` too.
- Index every column you filter, sort or count on. Use partial indexes for hot predicates (e.g. `create index(:t, [:deadline], where: "resolved_at IS NULL")`) — they serve sweeps and dashboard counters at once.
- Size/count caps in `GameServer.Limits` (auto-exposed as `LIMIT_*` env vars), enforced in the changeset, and listed in `@limit_categories` on the admin Config page.
- Document the tables in the [Data Schema](https://gamend.appsinacup.com/docs/setup) docs page (`lib/game_server_web/host_public_docs/data_schema.html.heex`).

## Functionality

- Context module in `game_server_core` (business logic, no web concerns).
- Every list function takes `:page` / `:page_size` and has a matching `count_*`. Pagination is not optional — assume 10k rows.
- Advisory lock namespaces go in `GameServer.Repo.AdvisoryLock` `@namespaces` before `GameServer.Lock.serialize/3` can use them.
- Any read-modify-write (merging a map, checking capacity before insert) must hold a lock. Plain "set field X" writes do not.
- Background work (sweeps, schedulers) as a supervised GenServer — add it to `lib/game_server_host/application.ex` **and** to the starter repo's supervision tree.

## Hooks (so plugins can extend the feature)

Adding one callback touches six places — miss one and plugins break in confusing ways:

1. `@callback` in `GameServer.Hooks`, listed under `@optional_callbacks` so existing plugins keep compiling.
2. Add the name to `internal_hooks()` — otherwise clients can invoke it over RPC.
3. `before_*` hooks: add to `lifecycle_pipeline_hook?/2`, plus a `normalize_pipeline_args/3` clause if the hook only vetoes (returns the value unchanged).
4. No-op implementation in `GameServer.Hooks.Default`.
5. Mirror in the SDK (`sdk/lib/game_server/hooks.ex`): `@callback`, `@optional_callbacks`, a default in `__using__`, **and the `defoverridable` list** — a default that isn't listed there cannot be overridden by plugins.
6. Document the hook on the Server-scripting docs page.

**Never dispatch a hook or broadcast inside a transaction or lock.** The hook runs in another process, so anything it writes contends with the transaction that spawned it. Queue the effect and flush it after commit (see `defer/1` in `GameServer.Tournaments`). This also keeps subscribers from seeing uncommitted state.

## SDK (plugin-facing)

- Add the context to `@sdk_modules` in `mix gen.sdk`, then run `mix gen.sdk`.
- Hand-write struct stubs in `sdk/lib/game_server/<feature>/` (the generator does not create them) — plugins can't compile against a struct that doesn't exist.
- Add placeholder rules in `gen.sdk` for the new structs (`T | nil` and `{:ok, T}` return types). Without them a stub returns only `nil`/`{:ok, _}`, and every plugin that pattern-matches the other branch gets a bogus "clause cannot match" warning.
- Verify with `cd modules/plugins_examples/example_hook && mix compile --force` — it must be warning-free.
- The server loads plugins from their bundled `ebin/`, not from `_build` — after changing a plugin, run `mix plugin.bundle` in its directory (or the admin Config build button) or the running server keeps the old code.

## Web

- API controller in `apps/game_server_web/.../controllers/api/v1/` with OpenAPI schemas (ids are `type: :string, format: :uuid`). List endpoints return a `meta` block with `page`, `page_size`, `total_count`, `total_pages`.
- Routes in `apps/game_server_web/lib/game_server_web/router/shared.ex`. Public listing endpoints get a `LIST_*_ENABLED` feature gate.
- Server-authoritative actions get **no public endpoint** — expose them through hooks.
- Realtime events via channel/PubSub if clients need pushes; forward them in `UserChannel` and subscribe/unsubscribe on join/terminate.
- Public LiveView: copy the layout of an existing page (leaderboards is the reference) rather than inventing one — same heading sizes, card grid, badges and `<.pagination>` component.
- Nav links live in **two** places: `theme/config.*.json` (`navigation.primary_links`) and the Elixir defaults in `host_layouts.ex`. A configured dropdown wins outright — nested items are not merged — so a link added only to the defaults will not appear.

## Admin

- Admin LiveView page in `apps/game_server_web/lib/game_server_web/live/admin_live/`, plus its route, a nav link and a stat card on `/admin`, and an entry in `admin_pages_render_test`.
- Show names, not raw UUIDs, and paginate every table.
- Admin API controller under `controllers/api/v1/admin/` with **parity for every admin UI action** — anything an admin can click, a script can call.

## Tests

- Context tests + controller tests + admin API tests + LiveView tests in `apps/game_server_web/test/`.
- Run against both adapters: `mix test` and with `POSTGRES_HOST` set. SQLite and Postgres differ in ways tests hide: `config/test.exs` sets `busy_timeout`, so concurrent-write failures that bite in dev never surface in CI.
- **Run the feature, don't only test it.** Boot the app (`mix run` a script, or the dev server) and exercise the real path — several classes of bug (hooks inside transactions, stale caches, missing supervision children) only appear at runtime.
- Add a set to `mix demo.seed` so the feature can be viewed at volume (pagination, large brackets, long lists).

## i18n

- `mix gettext.extract && mix gettext.merge priv/gettext` from `apps/game_server_web`, then translate every locale — `.po` files are kept fully translated.
- **Check for fuzzy matches after merging.** The merger silently borrows translations from similar strings (a new "Brackets" once picked up "Back"), and fuzzy entries are used at runtime. Grep for `fuzzy` and fix or clear them.
- Prefer `gettext("Players")` + a value over `ngettext` — plural rules differ wildly across the 30 locales.
- Plugin/sample content (example hook titles, seeded data) is not localized; it belongs to the host, not core.

## Finish

- Docs page in `lib/game_server_web/host_public_docs/` if user-facing, registered in `host_public_docs.ex`, plus the realtime events table and the feature list in `api_spec.ex`.
- New env vars documented in `.env.example`.
- `CHANGELOG.md` entry (`[added]` / `[changed]` / `[breaking]`), 3–4 words, grouped with related items.
- `mix format`, `mix credo --strict`, full `mix test` green.
- SDKs regenerate from the OpenAPI spec in CI — no manual SDK edits.
