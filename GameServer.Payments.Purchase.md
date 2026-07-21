# `GameServer.Payments.Purchase`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/payments/purchase.ex#L1)

Provider transaction record.

# `t`

```elixir
@type t() :: %GameServer.Payments.Purchase{
  __meta__: term(),
  amount: term(),
  currency: term(),
  entitlements: term(),
  environment: term(),
  expires_at: term(),
  id: term(),
  inserted_at: term(),
  metadata: term(),
  order_id: term(),
  product: term(),
  product_id: term(),
  provider: term(),
  provider_original_transaction_id: term(),
  provider_product: term(),
  provider_product_id: term(),
  provider_transaction_id: term(),
  purchased_at: term(),
  quantity: term(),
  raw_provider_payload: term(),
  revoked_at: term(),
  status: term(),
  updated_at: term(),
  user: term(),
  user_id: term()
}
```

# `changeset`

# `providers`

# `statuses`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
