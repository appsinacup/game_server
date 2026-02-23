# `GameServer.Groups.GroupMember`

Ecto schema for the `group_members` join table.

Tracks which users belong to which groups and their role within the group.

## Roles

- `"admin"` – can kick members, rename group, change settings, approve
  join requests, promote/demote members
- `"member"` – regular participant

# `t`

```elixir
@type t() :: %GameServer.Groups.GroupMember{
  __meta__: term(),
  group: term(),
  group_id: term(),
  id: term(),
  inserted_at: term(),
  role: term(),
  updated_at: term(),
  user: term(),
  user_id: term()
}
```

# `changeset`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
