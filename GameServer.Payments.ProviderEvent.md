# `GameServer.Payments.ProviderEvent`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/payments/provider_event.ex#L1)

Dedupe record for webhook and store notification events.

# `t`

```elixir
@type t() :: %GameServer.Payments.ProviderEvent{
  __meta__: term(),
  event_id: term(),
  event_type: term(),
  id: term(),
  inserted_at: term(),
  metadata: term(),
  payload: term(),
  processed_at: term(),
  provider: term(),
  updated_at: term()
}
```

# `changeset`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
