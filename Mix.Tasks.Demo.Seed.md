# `mix demo.seed`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/mix/tasks/demo.seed.ex#L1)

Fills the database with enough demo data to exercise pagination and the
list/detail pages at realistic sizes.

Everything is namespaced with a `demo-seed` prefix so `--clean` can remove it
again without touching real data.

## Usage

    mix demo.seed                       # all sets, 1000 rows each
    mix demo.seed --count 250           # smaller run
    mix demo.seed --only leaderboard    # one set (comma-separated)
    mix demo.seed --only group,tournament
    mix demo.seed --clean               # remove everything this task created

## Sets

  * `leaderboard` — a leaderboard with N scored records
  * `group`       — a public group with N members
  * `tournament`  — a tournament with N registered entries, still open
  * `lobby_snapshot` — recorded runs for `/admin/lobby-snapshots`, capped at 12
    regardless of `--count` (this set is about having something to read, not
    volume)

The `lobby_snapshot` set goes through the real `capture_lobby/3` path rather
than inserting rows, so what you see is shaped exactly like production data —
including content-addressed section dedup. One of its runs reproduces the July
2026 rubber-banding bug (a distance that reverts between snapshots), which is
the case the section diff exists to make obvious.

Seeded runs keep their lobby row so `--clean` can find them again. Real
completed runs outlive theirs, since a lobby is deleted when its last member
leaves.

All sets share one pool of N anonymous device accounts, so the same players
appear across them (as they would in a real deployment).

Rows are inserted in bulk rather than through the contexts: this is about
volume, not about exercising business rules, and 1000 individual writes on
SQLite is slow. The cache is flushed afterwards so pages read the new rows.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
