# `GameServer.Groups.Group`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/groups/group.ex#L1)

Ecto schema for the `groups` table.

A group is a persistent community that users can join. Unlike lobbies (which
are ephemeral game sessions), groups are long-lived and support admin roles,
join-request workflows, and invitation flows.

## Fields

- `title` – human-readable display title (unique)
- `description` – optional longer description
- `type` – visibility: `"public"`, `"private"`, or `"hidden"`
- `max_members` – maximum number of members (default 100)
- `metadata` – arbitrary server-managed key/value map
- `creator_id` – the user who originally created the group

# `t`

```elixir
@type t() :: %GameServer.Groups.Group{
  __meta__: term(),
  creator: term(),
  creator_id: term(),
  description: term(),
  id: term(),
  inserted_at: term(),
  max_members: term(),
  members: term(),
  metadata: term(),
  slowdown: term(),
  title: term(),
  type: term(),
  updated_at: term()
}
```

# `changeset`

```elixir
@spec changeset(t(), map()) :: Ecto.Changeset.t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
