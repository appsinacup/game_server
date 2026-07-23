# `GameServer.Economy.Wallet`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/economy/wallet.ex#L1)

A user's balance of one currency. Currencies are free-form string codes
(`"gold"`, `"gems"`, `"energy"`) — the game decides which exist.

# `t`

```elixir
@type t() :: %GameServer.Economy.Wallet{
  __meta__: term(),
  balance: term(),
  currency: term(),
  id: term(),
  inserted_at: term(),
  updated_at: term(),
  user: term(),
  user_id: term()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
