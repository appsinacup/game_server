# `GameServer.Notifications.Types`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/notifications/types.ex#L1)

The `metadata["type"]` codes a notification may carry.

A notification's type is never read by the server — it exists purely so a
client can decide how to render and route it. That makes an unregistered code
fail silently: the server stores and delivers it happily, and the client
simply never handles it. So the set is closed. `GameServer.Notifications`
rejects an unknown code at write time, and this module is the list clients
can rely on.

Plugins add their own by exporting `notification_types/0` (see
`GameServer.Hooks.Declarations`); those merge with the core codes below.

# `all`

```elixir
@spec all() :: %{required(String.t()) =&gt; String.t()}
```

Core plus plugin-declared codes.

# `core`

```elixir
@spec core() :: %{required(String.t()) =&gt; String.t()}
```

Core notification codes, mapped to their description.

# `known?`

```elixir
@spec known?(term()) :: boolean()
```

True when `code` is declared by core or a loaded plugin.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
