# `GameServer.Payments.ProviderProduct`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/payments/provider_product.ex#L1)

Maps an internal product to a provider-specific SKU or price id.

# `t`

```elixir
@type t() :: %GameServer.Payments.ProviderProduct{
  __meta__: term(),
  active: term(),
  currency: term(),
  external_id: term(),
  id: term(),
  inserted_at: term(),
  metadata: term(),
  product: term(),
  product_id: term(),
  provider: term(),
  purchases: term(),
  unit_amount: term(),
  updated_at: term()
}
```

# `changeset`

# `providers`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
