# `GameServer.Matchmaking.Match`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/matchmaking/match.ex#L1)

Creates the lobby for a claimed match and notifies the players.

Runs *outside* the sweep's cluster lock: `Lobbies.create_lobby/1` and
`join_lobby/2` fire plugin hooks and broadcasts, which must never run
inside a transaction. The tickets are already claimed (status `matched`),
so no other node can pick them up meanwhile; on failure they are requeued
and retried on the next tick.

Errors return tuples instead of raising, so one bad match never aborts the
rest of the sweep.

# `create`

```elixir
@spec create([GameServer.Types.matchmaking_ticket()]) ::
  {:ok, Ecto.UUID.t()} | {:error, term()}
```

Creates a hidden lobby for the claimed tickets, seats the users, locks the
lobby, records it on the tickets and broadcasts `match_found`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
