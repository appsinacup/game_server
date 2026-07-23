# `GameServer.Inventory.Item`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/inventory/item.ex#L1)

A user's stack of one item. Items are free-form string codes
(`"health_potion"`, `"sword"`, `"card_374"`) — the game decides which exist.
`metadata` holds per-stack properties.

# `t`

```elixir
@type t() :: %GameServer.Inventory.Item{
  __meta__: term(),
  id: term(),
  inserted_at: term(),
  item: term(),
  metadata: term(),
  quantity: term(),
  updated_at: term(),
  user: term(),
  user_id: term()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
