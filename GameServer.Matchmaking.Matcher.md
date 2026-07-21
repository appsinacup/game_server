# `GameServer.Matchmaking.Matcher`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/matchmaking/matcher.ex#L1)

Match-forming logic for a group of tickets that share the same
`match_params`.

The unit of matching is not a ticket but a *group*: tickets sharing a
`party_id` are indivisible, and a solo queuer is a group of one. A match is
built by packing whole groups, so a party is either seated together or stays
queued — it is never split across lobbies.

A match is formed when:
  * the packed groups total at least `min_players`, and
  * the packed groups total exactly `max_players`, or
  * the oldest group has waited at least `timeout_ms`.

Groups are consumed in FIFO order by their oldest ticket. A single bucket can
produce multiple matches in one sweep.

Players who have blocked each other are never placed in the same match. The
blocked set is passed in rather than queried here, so this module stays pure
and the caller resolves every pair in a single query (see
`GameServer.Friends.blocked_pairs/1`).

# `form_matches`

```elixir
@spec form_matches([GameServer.Types.matchmaking_ticket()], MapSet.t()) ::
  {[[GameServer.Types.matchmaking_ticket()]],
   [GameServer.Types.matchmaking_ticket()]}
```

Forms all possible matches from a list of tickets.

`blocked` is a `MapSet` of order-independent user pairs (as built by
`GameServer.Friends.blocked_pairs/1`) that must not share a match. Defaults
to empty, which forms matches on FIFO order alone.

Returns `{matches, remaining}` where `matches` is a list of ticket lists
and `remaining` are the tickets that could not be matched yet.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
