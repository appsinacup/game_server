# `GameServer.Parties.Party`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/parties/party.ex#L1)

Ecto schema for the `parties` table.

A party is a pre-lobby grouping mechanism. Players form a party before
creating or joining a lobby together. The party leader controls when the
party enters a lobby, and all members join atomically.

Rules:
- A party has a leader (creator) and members.
- Members join via invite (notification-based).
- The leader sets `max_size` (capacity).
- If the leader leaves, the party is disbanded (deleted).
- When the leader creates or joins a lobby, all party members join that
  lobby atomically (the lobby must have enough space).
- A user can be in both a party and a lobby simultaneously.
- A user can only be in one party at a time.

# `t`

```elixir
@type t() :: %GameServer.Parties.Party{
  __meta__: term(),
  id: term(),
  inserted_at: term(),
  leader: term(),
  leader_id: term(),
  max_size: term(),
  members: term(),
  metadata: term(),
  updated_at: term()
}
```

# `changeset`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
