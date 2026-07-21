# `GameServer.Payments.ProviderConfig`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/payments/provider_config.ex#L1)

Runtime payment-provider configuration helpers.

`PAYMENTS_ENVIRONMENT` is the single switch that selects sandbox versus
production provider credentials for this host.

# `environment`

```elixir
@type environment() :: String.t()
```

# `environment`

```elixir
@spec environment() :: environment()
```

# `environments`

```elixir
@spec environments() :: [String.t()]
```

# `normalize_environment`

# `production?`

```elixir
@spec production?() :: boolean()
```

# `sandbox_like?`

```elixir
@spec sandbox_like?() :: boolean()
```

# `stripe_api_version`

```elixir
@spec stripe_api_version() :: String.t()
```

# `stripe_api_version_source`

```elixir
@spec stripe_api_version_source() :: {String.t(), String.t()} | nil
```

# `stripe_candidate_labels`

```elixir
@spec stripe_candidate_labels(:secret_key | :webhook_secret) :: [String.t()]
```

# `stripe_default_api_version`

```elixir
@spec stripe_default_api_version() :: String.t()
```

# `stripe_secret_key`

```elixir
@spec stripe_secret_key() :: String.t() | nil
```

# `stripe_secret_key_source`

```elixir
@spec stripe_secret_key_source() :: {String.t(), String.t()} | nil
```

# `stripe_webhook_secret`

```elixir
@spec stripe_webhook_secret() :: String.t() | nil
```

# `stripe_webhook_secret_source`

```elixir
@spec stripe_webhook_secret_source() :: {String.t(), String.t()} | nil
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
