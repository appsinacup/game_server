# `GameServer.Economy`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/economy.ex#L1)

Virtual-currency wallets with an append-only ledger.

Currencies are free-form string codes (`"gold"`, `"gems"`, `"energy"`) — the
game decides which exist. Every balance change is atomic and recorded in the
ledger, so two concurrent spends can never overspend and every mutation is
auditable.

## Usage (server-side / hooks)

    Economy.grant(user_id, "gold", 100, reason: "match_reward")
    case Economy.spend(user_id, "gold", 30, reason: "store_purchase") do
      {:ok, balance} -> :ok
      {:error, :insufficient_funds} -> :not_enough_gold
    end

    Economy.balance(user_id, "gold")   #=> 70
    Economy.balances(user_id)          #=> %{"gold" => 70}

## Idempotency

Pass `:idempotency_key` so a retried request (network retry, at-least-once job)
can't double-apply — the second call is a no-op that returns the current
balance:

    Economy.grant(user_id, "gems", 5, idempotency_key: "purchase:#{order_id}")

## Safety

These are **server-authoritative**: expose them from hooks and admin tools,
never as a raw client "add currency" endpoint. Clients only read their wallet.

# `currency`

```elixir
@type currency() :: String.t()
```

# `user_id`

```elixir
@type user_id() :: Ecto.UUID.t()
```

# `balance`

```elixir
@spec balance(user_id(), currency()) :: non_neg_integer()
```

Current balance of one currency (0 when the user has no wallet for it).

# `balances`

```elixir
@spec balances(user_id()) :: %{required(currency()) =&gt; non_neg_integer()}
```

All non-zero balances for a user, as a `%{currency => balance}` map.

# `grant`

```elixir
@spec grant(user_id(), currency(), pos_integer(), keyword()) ::
  {:ok, non_neg_integer()} | {:error, term()}
```

Add `amount` of `currency` to a user's wallet.

Options: `:reason` (ledger label), `:idempotency_key`, `:metadata`.
Returns `{:ok, new_balance}`.

# `spend`

```elixir
@spec spend(user_id(), currency(), pos_integer(), keyword()) ::
  {:ok, non_neg_integer()} | {:error, :insufficient_funds | term()}
```

Remove `amount` of `currency` from a user's wallet, atomically.

Returns `{:ok, new_balance}` or `{:error, :insufficient_funds}` — the balance
is never left negative.

# `subscribe`

```elixir
@spec subscribe(user_id()) :: :ok | {:error, term()}
```

Subscribe the calling process to a user's live wallet updates.

# `unsubscribe`

```elixir
@spec unsubscribe(user_id()) :: :ok
```

Stop receiving a user's wallet updates.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
