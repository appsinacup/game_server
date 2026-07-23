# `GameServer.Economy.LedgerEntry`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/economy/ledger_entry.ex#L1)

Append-only record of a single wallet change (grant, spend, transfer, admin
adjustment). One row per balance mutation, keeping an auditable history.

# `t`

```elixir
@type t() :: %GameServer.Economy.LedgerEntry{
  __meta__: term(),
  balance_after: term(),
  currency: term(),
  delta: term(),
  id: term(),
  idempotency_key: term(),
  inserted_at: term(),
  metadata: term(),
  reason: term(),
  user: term(),
  user_id: term()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
