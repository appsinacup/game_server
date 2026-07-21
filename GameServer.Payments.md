# `GameServer.Payments`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/payments.ex#L1)

Payment catalog, purchase ledger, and entitlements.

Provider-specific integrations validate or create transactions, but this
context remains the source of truth for what a user owns inside the game.

# `admin_stats`

```elixir
@spec admin_stats() :: map()
```

# `cancel_stripe_subscription_at_period_end`

```elixir
@spec cancel_stripe_subscription_at_period_end(
  GameServer.Accounts.User.t(),
  Ecto.UUID.t()
) ::
  {:ok,
   %{
     purchase: GameServer.Payments.Purchase.t(),
     entitlement: GameServer.Payments.Entitlement.t(),
     stripe_subscription: map()
   }}
  | {:error, term()}
```

# `count_entitlements`

```elixir
@spec count_entitlements(keyword()) :: non_neg_integer()
```

# `count_products`

```elixir
@spec count_products(keyword()) :: non_neg_integer()
```

# `count_provider_events`

```elixir
@spec count_provider_events(keyword()) :: non_neg_integer()
```

# `count_provider_products`

```elixir
@spec count_provider_products(keyword()) :: non_neg_integer()
```

# `count_purchases`

```elixir
@spec count_purchases(keyword()) :: non_neg_integer()
```

# `count_reconciliation_cursors`

```elixir
@spec count_reconciliation_cursors(keyword()) :: non_neg_integer()
```

# `create_product`

```elixir
@spec create_product(map()) ::
  {:ok, GameServer.Payments.Product.t()} | {:error, Ecto.Changeset.t()}
```

# `create_provider_product`

```elixir
@spec create_provider_product(map()) ::
  {:ok, GameServer.Payments.ProviderProduct.t()} | {:error, Ecto.Changeset.t()}
```

# `create_purchase`

```elixir
@spec create_purchase(
  GameServer.Accounts.User.t(),
  GameServer.Payments.ProviderProduct.t(),
  map()
) ::
  {:ok, GameServer.Payments.Purchase.t()} | {:error, Ecto.Changeset.t()}
```

# `create_steam_checkout`

```elixir
@spec create_steam_checkout(GameServer.Accounts.User.t(), map()) ::
  {:ok,
   %{
     purchase: GameServer.Payments.Purchase.t(),
     provider_transaction_id: String.t() | nil,
     steam_url: String.t() | nil
   }}
  | {:error, term()}
```

# `create_stripe_checkout`

```elixir
@spec create_stripe_checkout(GameServer.Accounts.User.t(), map()) ::
  {:ok,
   %{
     purchase: GameServer.Payments.Purchase.t(),
     checkout_url: String.t(),
     provider_session_id: String.t()
   }}
  | {:error, term()}
```

# `finalize_steam_purchase`

```elixir
@spec finalize_steam_purchase(GameServer.Accounts.User.t(), map()) ::
  {:ok, %{purchase: GameServer.Payments.Purchase.t()}} | {:error, term()}
```

# `fulfill_purchase`

```elixir
@spec fulfill_purchase(GameServer.Payments.Purchase.t(), map()) ::
  {:ok, GameServer.Payments.Purchase.t()} | {:error, term()}
```

# `get_product`

```elixir
@spec get_product(Ecto.UUID.t()) :: GameServer.Payments.Product.t() | nil
```

# `get_product_by_sku`

```elixir
@spec get_product_by_sku(String.t()) :: GameServer.Payments.Product.t() | nil
```

# `get_provider_product`

```elixir
@spec get_provider_product(Ecto.UUID.t()) ::
  GameServer.Payments.ProviderProduct.t() | nil
```

# `get_provider_product`

```elixir
@spec get_provider_product(String.t(), String.t()) ::
  GameServer.Payments.ProviderProduct.t() | nil
```

# `get_purchase`

```elixir
@spec get_purchase(Ecto.UUID.t()) :: GameServer.Payments.Purchase.t() | nil
```

# `get_purchase_by_order_id`

```elixir
@spec get_purchase_by_order_id(String.t()) :: GameServer.Payments.Purchase.t() | nil
```

# `get_purchase_by_provider_original_transaction`

```elixir
@spec get_purchase_by_provider_original_transaction(String.t(), String.t()) ::
  GameServer.Payments.Purchase.t() | nil
```

# `get_purchase_by_provider_transaction`

```elixir
@spec get_purchase_by_provider_transaction(String.t(), String.t()) ::
  GameServer.Payments.Purchase.t() | nil
```

# `handle_apple_webhook`

```elixir
@spec handle_apple_webhook(binary()) :: {:ok, atom()} | {:error, term()}
```

# `handle_google_webhook`

```elixir
@spec handle_google_webhook(binary(), binary() | nil) ::
  {:ok, atom()} | {:error, term()}
```

# `handle_stripe_webhook`

```elixir
@spec handle_stripe_webhook(binary(), binary() | nil) ::
  {:ok, atom()} | {:error, term()}
```

# `has_entitlement?`

```elixir
@spec has_entitlement?(Ecto.UUID.t(), String.t()) :: boolean()
```

# `list_admin_entitlements`

```elixir
@spec list_admin_entitlements(keyword()) :: [GameServer.Payments.Entitlement.t()]
```

# `list_admin_products`

```elixir
@spec list_admin_products(keyword()) :: [GameServer.Payments.Product.t()]
```

# `list_admin_provider_products`

```elixir
@spec list_admin_provider_products(keyword()) :: [
  GameServer.Payments.ProviderProduct.t()
]
```

# `list_admin_purchases`

```elixir
@spec list_admin_purchases(keyword()) :: [GameServer.Payments.Purchase.t()]
```

# `list_catalog`

```elixir
@spec list_catalog(String.t() | nil) :: [GameServer.Payments.ProviderProduct.t()]
```

# `list_products`

```elixir
@spec list_products(keyword()) :: [GameServer.Payments.Product.t()]
```

# `list_provider_events`

```elixir
@spec list_provider_events(keyword()) :: [GameServer.Payments.ProviderEvent.t()]
```

# `list_reconciliation_cursors`

```elixir
@spec list_reconciliation_cursors(keyword()) :: [
  GameServer.Payments.ReconciliationCursor.t()
]
```

# `list_user_entitlements`

```elixir
@spec list_user_entitlements(
  Ecto.UUID.t(),
  keyword()
) :: [GameServer.Payments.Entitlement.t()]
```

# `list_user_purchases`

```elixir
@spec list_user_purchases(
  Ecto.UUID.t(),
  keyword()
) :: [GameServer.Payments.Purchase.t()]
```

# `product_entitlement_key`

```elixir
@spec product_entitlement_key(GameServer.Payments.Product.t()) :: String.t()
```

# `provider_adapter_statuses`

```elixir
@spec provider_adapter_statuses() :: [map()]
```

# `reconcile_stripe_purchase`

```elixir
@spec reconcile_stripe_purchase(GameServer.Payments.Purchase.t()) ::
  {:ok,
   %{
     purchase: GameServer.Payments.Purchase.t(),
     result: atom(),
     stripe_session: map()
   }}
  | {:error, term()}
```

# `record_provider_event`

```elixir
@spec record_provider_event(String.t(), String.t(), String.t(), map(), map()) ::
  {:ok, GameServer.Payments.ProviderEvent.t(), boolean()}
  | {:error, Ecto.Changeset.t()}
```

# `revoke_purchase`

```elixir
@spec revoke_purchase(GameServer.Payments.Purchase.t(), map()) ::
  {:ok, GameServer.Payments.Purchase.t()} | {:error, term()}
```

# `stripe_config_status`

```elixir
@spec stripe_config_status() :: map()
```

# `update_product`

```elixir
@spec update_product(GameServer.Payments.Product.t(), map()) ::
  {:ok, GameServer.Payments.Product.t()} | {:error, Ecto.Changeset.t()}
```

# `update_provider_product`

```elixir
@spec update_provider_product(GameServer.Payments.ProviderProduct.t(), map()) ::
  {:ok, GameServer.Payments.ProviderProduct.t()} | {:error, Ecto.Changeset.t()}
```

# `validate_store_purchase`

```elixir
@spec validate_store_purchase(GameServer.Accounts.User.t(), String.t(), map()) ::
  {:ok, %{purchase: GameServer.Payments.Purchase.t(), seen_before: boolean()}}
  | {:error, term()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
