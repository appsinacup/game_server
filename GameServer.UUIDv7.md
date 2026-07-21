# `GameServer.UUIDv7`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/uuid_v7.ex#L1)

UUIDv7 Ecto type used for all primary and foreign keys.

UUIDv7 embeds a 48-bit unix-millisecond timestamp in the most significant
bits, so freshly inserted rows sort (and index) in insertion order like the
old integer ids did, while remaining unguessable — random ids prevent
enumeration of API resources.

Cast/dump/load are delegated to `Ecto.UUID`, so storage behavior matches
`:binary_id` on both SQLite and Postgres; only generation differs (v7
instead of v4).

# `cast_or_nil`

```elixir
@spec cast_or_nil(term()) :: Ecto.UUID.t() | nil
```

Casts a value to a UUID string, returning `nil` when invalid.

Convenience for boundary code (channel topics, URL params) that previously
used `Integer.parse/1` to validate ids.

# `generate`

```elixir
@spec generate() :: Ecto.UUID.t()
```

Generates a UUIDv7 string (time-ordered, RFC 9562).

Uses the 12 `rand_a` bits as a per-millisecond sequence counter (RFC 9562
§6.2 method 1) so ids generated on the same node within one millisecond
still sort in generation order — code that orders by id (chat cursors,
pagination) keeps working under bursts.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
