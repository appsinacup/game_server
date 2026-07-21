# `GameServer.Hooks.KvSchemas`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/hooks/kv_schemas.ex#L1)

Registry of game-defined protobuf schemas for KV entry data.

KV keys are open-ended, so unlike metadata entities there is no naming
convention — a plugin registers schemas explicitly by exporting
`kv_schemas/0`, mapping exact keys or `*`-suffixed prefixes to protobuf
message modules:

    def kv_schemas do
      %{
        "loadout" => MyGame.V1.Loadout,
        "match:*" => MyGame.V1.MatchState
      }
    end

On protobuf sockets, `kv_updated` data for a matching key is pushed as
compact binary (`data_pb`) instead of JSON bytes; storage and REST stay
JSON, and data that does not fit the schema falls back to JSON so it is
never dropped. Exact keys win over prefixes; the longest prefix wins.
KV entry metadata always stays JSON.

The KV keyspace is **global**: when two plugins register the same key or
prefix pattern, the first plugin in name order wins and the losing
registration is logged.

# `all`

```elixir
@spec all() :: %{
  exact: %{required(String.t()) =&gt; module()},
  prefixes: [{String.t(), module()}]
}
```

Returns the full registry (for the admin overview).

# `module_for`

```elixir
@spec module_for(String.t()) :: module() | nil
```

Returns the registered schema module for a KV key, or nil.

# `refresh`

```elixir
@spec refresh([struct()]) :: :ok
```

Rebuilds the registry from the loaded plugin list.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
