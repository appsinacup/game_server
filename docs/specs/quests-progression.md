# Quests / progression — generalizes achievements, pays into economy

Design spec for the Phase 3 **Quests/progression** item in
[ROADMAP.md](../../ROADMAP.md). **Depends on Economy** (rewards) and **Jobs**
(resets/timers). Completes the reward spine: economy → quests → achievements are
one design, and this is the engine the other two are special cases of.

Goal: one event-driven progression engine that covers **achievements** (permanent
one-shots), **daily/weekly quests** (repeat on a schedule), **event quests**
(time-boxed), and **chains** (prereq → next) — each able to **pay rewards into
the economy** exactly once.

## Why (achievements are 80% of a quest already)

`GameServer.Achievements` already models the hard part: a definition with a
`progress_target`, per-user progress (`increment_progress/3`), auto-unlock at the
target, and an `after_achievement_unlocked` hook. What it can't express is
everything that makes a *quest*: **multiple objectives**, **repetition on a
reset cycle**, **time windows**, **prerequisites**, and **rewards**. Rather than
grow a second half-copy of the progress machinery, quests generalize it: an
achievement becomes a quest of `kind: "achievement"` (permanent, non-repeating,
badge reward), and daily/weekly/event/chain quests are the other kinds on the
same engine.

### Decision: fold, don't fork

Achievements migrate into the quest tables as `kind: "achievement"`. Per the
project's "no backwards-compat shims" stance we take the clean break with a
`[breaking]` CHANGELOG note — **but** we keep the existing `/achievements` **read**
endpoints as a thin filtered view over quests (`kind = achievement`), because
those are a published client/SDK contract, not an internal fallback. Write paths
(`unlock`, `increment_progress`) route into the quest engine. (If the team
prefers, achievements can instead run *alongside* quests sharing only the
`report_event` dispatch — noted as the alternative, but fold is the intent of
"generalizes".)

## Data model (both adapters)

- **`quests`** (definitions): `key` (unique slug), `title`, `description`,
  `kind` (`"achievement"|"daily"|"weekly"|"event"|"chain"`),
  `objectives` (jsonb list — each `{event, target, params}`),
  `rewards` (jsonb — currencies/items granted via Economy),
  `repeatable` (bool), `reset_cron` (nullable — daily/weekly),
  `prerequisite_quest_key` (nullable — chains),
  `starts_at`/`ends_at` (nullable — event windows), `active`, `metadata`,
  timestamps. Index `[:kind]`, partial `index([:active], where: "active")`.
- **`quest_progress`** (per user per quest per period):
  `user_id`, `quest_key`, `period_key` (reset bucket — `"2026-07-22"` for a
  daily, `"static"` for a permanent), `objective_progress` (jsonb map
  objective→count), `status` (`"active"|"completed"|"claimed"`),
  `completed_at`, `claimed_at`, timestamps.
  `unique_index([:user_id, :quest_key, :period_key])`;
  partial `index([:user_id], where: "status = 'completed'")` for the
  "claimable" badge + sweep.

## Progress — event-driven dispatch (generalizes `increment_progress`)

```elixir
Quests.report_event(user_id, "enemy_killed", 1, meta)
```

- Finds the user's **active** quests whose objectives key on `"enemy_killed"`
  and advances each (creating the `quest_progress` row for the current
  `period_key` on first touch). This is the generalization of achievements'
  `increment_progress/3`.
- **Server-authoritative**: there is **no** public "increment my quest"
  endpoint — a client can't advance its own quests. Core wires common events
  (score submitted, match won/`record_result`, chat sent, login) to
  `report_event`; games/plugins call it for custom events from their hooks.
- When every objective meets its target → `status: completed`. If the quest
  auto-claims, rewards grant immediately; otherwise the player claims.

## Rewards — exactly-once into Economy (the "pays into economy" part)

On completion/claim, each reward is applied via
[Economy](economy-inventory.md) with `idempotency_key = quest_progress.id`:

```elixir
Economy.credit(user_id, "gold", 100, reason: "quest_reward", idempotency_key: progress_id)
Economy.grant_item(user_id, "loot_crate", 1, reason: "quest_reward", idempotency_key: progress_id)
```

The idempotency key means a retried claim, a double-tap, or a job re-run **can
never double-pay** — the ledger dedupes. The progress increment → completion →
reward path is a read-modify-write, so it runs under a `:quest` advisory-lock
namespace (next free id) keyed on `(user_id, quest_key)`; the reward call itself
takes the `:wallet` lock inside Economy. Hooks/rewards are dispatched **after**
the transaction commits (`defer/1`), never inside the lock.

## Resets & timers — on Jobs/Schedule (Phase 0)

- **Daily/weekly**: a durable `GameServer.Schedule` entry rolls `period_key`
  (new period ⇒ new `quest_progress` row on next `report_event`); no mass row
  rewrite needed, so reset is O(1). Old periods prune via a pruner job.
- **Event quests**: `starts_at`/`ends_at` gate eligibility; a
  `Jobs.enqueue_in/3` at `ends_at` finalizes/expires open progress.
- **Delayed grants** (e.g. "reward in 24h"): `Jobs.enqueue_hook`.

## Hooks (all six places, per CONTRIBUTING §Hooks)

- **`before_quest_claim(user_id, quest, progress)`** — pipeline veto (anti-cheat,
  eligibility). Add to `lifecycle_pipeline_hook?/2` + `normalize_pipeline_args/3`.
- **`after_quest_completed(progress)`** and **`after_quest_claimed(progress)`** —
  observe (push a notification, chain the next quest, analytics).

Each in all six places (`@callback`+`@optional_callbacks`, `internal_hooks()`,
`Hooks.Default`, SDK incl. `defoverridable`, docs). `after_achievement_unlocked`
stays as an alias fired for `kind: "achievement"` completions so existing plugins
keep working.

## Web / API

- `GET /me/quests` — active quests + progress + claimable flag (paginated).
- `POST /me/quests/:key/claim` — claim a completed quest's rewards.
- Quest **catalog** listing behind a `LIST_*_ENABLED` gate.
- `/achievements` read endpoints preserved as the `kind = achievement` view.
- Event reporting: **no public endpoint** (server-authoritative).

## Limits (`GameServer.Limits`, auto `LIMIT_*`, `@limit_categories`)

`max_quests`, `max_objectives_per_quest`, `max_active_quests_per_user`,
`max_quest_reward_entries`, `max_quest_period_history`.

## Admin

- `admin_live/quests.ex` — quest definitions CRUD (objectives + rewards editor),
  per-user progress viewer with **grant/reset/force-claim** actions, completion
  funnels per quest.
- `/admin` stat card (active quests, completions today, rewards paid) + route +
  nav + `admin_pages_render_test`.
- Admin API parity for every action.

## "Update everywhere" — file list

- **README** Features: Quests/progression (mention achievements are now a quest
  kind). **CHANGELOG** `[added]` Quests/progression · `[changed]`/`[breaking]`
  achievements folded into quests.
- **.env.example** — the `LIMIT_*` caps.
- **host_public_docs/** — new Quests page (kinds, objectives, `report_event`,
  reward/idempotency contract, resets); Server-scripting page gains the hooks;
  Data Schema gains `quests`/`quest_progress`, notes the achievements migration.
- **api_spec.ex** — feature list + quest endpoints; keep achievements entries.
- **SDK** — `Quests` stub + struct stubs; `@sdk_modules`, `gen.sdk`, placeholder
  rules; hooks mirrored (incl. the achievement alias).
- **AdvisoryLock** — `:quest` namespace documented.
- **runtime_introspection.ex** — quest stats (definitions, active, completions).
- **i18n** — 30 locales; **mix demo.seed** — a daily, a chain, and a migrated
  achievement, with some seeded progress + a claimable reward.

## Deferred / rejected

- **Visual quest-chain/DAG editor: defer.** `prerequisite_quest_key` expresses
  chains in data; a graphical editor is admin-UX polish for later.
- **Per-player dynamic/generated quests: defer.** The engine is
  definition-driven; procedural quests are a plugin that inserts definitions.
- **Leaderboard of quest completions: defer.** `after_quest_completed` can feed a
  leaderboard without core owning it.

## Definition of done (CONTRIBUTING)

- [ ] Migrations create `quests`/`quest_progress` and migrate achievement
      definitions/progress in; apply on SQLite **and** `DATABASE_ADAPTER=postgres`.
- [ ] `report_event` dispatch advances objectives; completion → reward via
      Economy with `idempotency_key` (no double-pay); resets on Schedule; event
      windows on Jobs; all under the `:quest` lock, hooks deferred post-commit.
- [ ] Paginated `list_*`/`count_*`; `Limits` caps; achievements read-view intact.
- [ ] Hooks `before_quest_claim` / `after_quest_completed` / `after_quest_claimed`
      (+ achievement alias) in all six places, RPC-blocked, SDK-mirrored.
- [ ] Admin page + `/admin` card + route + nav + `admin_pages_render_test`;
      admin API parity.
- [ ] Docs, `.env.example`, CHANGELOG, README, `api_spec.ex`; i18n 30 locales.
- [ ] Tests: context + controller + admin + LiveView, both adapters; boot and
      actually complete a multi-objective quest, claim it, confirm the economy
      credit is exactly-once on double-claim, and roll a daily period.
- [ ] `mix format`, `mix credo --strict`, full `mix test` green; `mix gen.sdk`
      clean; example plugin compiles warning-free.
