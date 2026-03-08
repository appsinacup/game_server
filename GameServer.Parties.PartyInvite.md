# `GameServer.Parties.PartyInvite`

Ecto schema for the `party_invites` table.

Stores pending, accepted, declined, and cancelled invitations for parties.
Unlike the previous approach (which stored invites as notifications),
invite records are independent of the notification system — deleting
notifications does not affect pending invites.

## Statuses

- `"pending"`   – waiting for the recipient to decide
- `"accepted"`  – recipient joined the party
- `"declined"`  – recipient declined the invite
- `"cancelled"` – sender cancelled the invite

# `t`

```elixir
@type t() :: %GameServer.Parties.PartyInvite{
  __meta__: term(),
  id: term(),
  inserted_at: term(),
  party: term(),
  party_id: term(),
  recipient: term(),
  recipient_id: term(),
  sender: term(),
  sender_id: term(),
  status: term(),
  updated_at: term()
}
```

# `changeset`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
