# `GameServer.Tournaments.Tournament`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/tournaments/tournament.ex#L1)

A bracket tournament occurrence.

Recurring tournaments share a `slug` (one row per occurrence, like
leaderboard seasons); `recur` holds the cron expression that spawns the next
occurrence. `team_size` is advisory — core only ever tracks entry leaders.
A nil `starts_at` means manual start: registration stays open until an
admin/game sets `starts_at` (the "draw now" force action does exactly that).

# `changeset`

# `deadline_policies`

# `states`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
