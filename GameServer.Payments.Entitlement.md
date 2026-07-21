# `GameServer.Payments.Entitlement`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/payments/entitlement.ex#L1)

User access grant derived from a purchase or admin/server action.

# `t`

```elixir
@type t() :: %GameServer.Payments.Entitlement{
  __meta__: term(),
  expires_at: term(),
  id: term(),
  inserted_at: term(),
  key: term(),
  metadata: term(),
  product: term(),
  product_id: term(),
  revoked_at: term(),
  source_purchase: term(),
  source_purchase_id: term(),
  starts_at: term(),
  status: term(),
  updated_at: term(),
  user: term(),
  user_id: term()
}
```

# `changeset`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
