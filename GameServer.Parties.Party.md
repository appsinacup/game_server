# `GameServer.Parties.Party`

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

# `changeset`

# `generate_code`

Generates a random 6-character uppercase alphanumeric code.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
