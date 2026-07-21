# `GameServer.Hooks.MetadataSchemas`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/hooks/metadata_schemas.ex#L1)

Registry of game-defined protobuf schemas for entity metadata.

Metadata is stored and served as JSON (database, REST API, admin UI), but
realtime pushes on protobuf-format connections can carry it as compact
binary when the game registers a schema. Registration is convention-based:
when a plugin loads, its modules are scanned for protobuf messages named
`UserMeta`, `LobbyMeta`, `GroupMeta` or `PartyMeta` (any namespace), which
are registered for the matching entity automatically. A plugin can override
or disable the convention by exporting `metadata_schemas/0` returning e.g.
`%{user: MyGame.Proto.Profile, lobby: nil}`.

Entity metadata schemas are **global** (one per deployment): unlike hook
schemas, which are namespaced per plugin, every plugin contributes to the
same four entity slots. On conflict the precedence is well-defined:
explicit `metadata_schemas/0` entries beat name conventions, and within
the same priority the first plugin in name order wins; every losing
registration is logged. An explicit `nil` disables the entity globally
(sticky — conventions from other plugins cannot re-add it).

Lookups run on every push, so the registry lives in `:persistent_term`
(refreshed by `GameServer.Hooks.PluginManager` on every plugin reload).

# `all`

```elixir
@spec all() :: %{required(atom()) =&gt; module()}
```

Returns the full entity -> module registry (for the admin overview).

# `entities`

```elixir
@spec entities() :: [atom()]
```

The entities that can carry a game metadata schema.

# `module_for`

```elixir
@spec module_for(atom()) :: module() | nil
```

Returns the registered protobuf module for an entity, or nil.

# `refresh`

```elixir
@spec refresh([struct()]) :: :ok
```

Rebuilds the registry from the loaded plugin list.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
