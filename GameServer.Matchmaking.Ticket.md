# `GameServer.Matchmaking.Ticket`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/matchmaking/ticket.ex#L1)

Ecto schema for a matchmaking ticket.

A ticket represents one matchmaking request from a user. Tickets with
the same `match_params` are grouped and matched together.

A ticket queued on behalf of a party carries that party's `party_id`. Tickets
sharing a `party_id` form an indivisible unit: the matcher seats them in the
same lobby or leaves them all queued.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
