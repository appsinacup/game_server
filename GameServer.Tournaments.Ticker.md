# `GameServer.Tournaments.Ticker`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/tournaments/ticker.ex#L1)

Periodic driver for tournament lifecycles: state transitions, match-ready
firing, deadline sweeps and recurrence spawns (`GameServer.Tournaments.tick/0`).

Safe in multi-instance deployments: the tick body is serialized cluster-wide
via `GameServer.Lock`.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
