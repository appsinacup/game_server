# `GameServer.Matchmaking.Broadcast`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/matchmaking/broadcast.ex#L1)

Broadcasts matchmaking events to users.

Core publishes on the `matchmaking:user:<id>` PubSub topic; the user
channel subscribes on join and forwards to the client (same shape as the
tournament events). Core never references the web endpoint directly.

# `match_found`

```elixir
@spec match_found([map()], Ecto.UUID.t()) :: :ok
```

Notifies every matched user that a lobby has been found.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
