# `GameServer.Hooks`

Behaviour for application-level hooks / callbacks.

Implement this behaviour to receive lifecycle events from core flows
(registration, login, provider linking, deletion) and run custom logic.

A module implementing this behaviour can be configured with

    config :game_server_core, :hooks_module, MyApp.HooksImpl

The default implementation is a no-op.

# `hook_result`

```elixir
@type hook_result(attrs_or_user) :: {:ok, attrs_or_user} | {:error, term()}
```

# `kv_opts`

```elixir
@type kv_opts() :: map() | keyword()
```

Options passed to hooks that accept an options map/keyword list.

Common keys include `:user_id` (pos_integer) and other domain-specific
options. Hooks may accept either a map or keyword list for convenience.

# `after_group_create`

```elixir
@callback after_group_create(term()) :: any()
```

# `after_lobby_create`

```elixir
@callback after_lobby_create(term()) :: any()
```

# `after_lobby_delete`

```elixir
@callback after_lobby_delete(term()) :: any()
```

# `after_lobby_host_change`

```elixir
@callback after_lobby_host_change(term(), term()) :: any()
```

# `after_lobby_join`

```elixir
@callback after_lobby_join(GameServer.Accounts.User.t(), term()) :: any()
```

# `after_lobby_leave`

```elixir
@callback after_lobby_leave(GameServer.Accounts.User.t(), term()) :: any()
```

# `after_lobby_update`

```elixir
@callback after_lobby_update(term()) :: any()
```

# `after_startup`

```elixir
@callback after_startup() :: any()
```

# `after_user_kicked`

```elixir
@callback after_user_kicked(
  GameServer.Accounts.User.t(),
  GameServer.Accounts.User.t(),
  term()
) :: any()
```

# `after_user_login`

```elixir
@callback after_user_login(GameServer.Accounts.User.t()) :: any()
```

# `after_user_register`

```elixir
@callback after_user_register(GameServer.Accounts.User.t()) :: any()
```

# `after_user_updated`

```elixir
@callback after_user_updated(GameServer.Accounts.User.t()) :: any()
```

# `before_group_create`

```elixir
@callback before_group_create(GameServer.Accounts.User.t(), map()) :: hook_result(map())
```

# `before_group_join`

```elixir
@callback before_group_join(GameServer.Accounts.User.t(), term(), map()) ::
  hook_result({GameServer.Accounts.User.t(), term(), map()})
```

# `before_kv_get`

```elixir
@callback before_kv_get(String.t(), kv_opts()) :: hook_result(:public | :private)
```

Called before a KV `get/2` is performed. Implementations should return
`:public` if the key may be read publicly, or `:private` to restrict access.

Receives the `key` and an `opts` map/keyword (see `t:kv_opts/0`). Return
either the bare atom (e.g. `:public`) or `{:ok, :public}`; return `{:error, reason}`
to block the read.

# `before_lobby_create`

```elixir
@callback before_lobby_create(map()) :: hook_result(map())
```

# `before_lobby_delete`

```elixir
@callback before_lobby_delete(term()) :: hook_result(term())
```

# `before_lobby_join`

```elixir
@callback before_lobby_join(GameServer.Accounts.User.t(), term(), term()) ::
  hook_result({GameServer.Accounts.User.t(), term(), term()})
```

# `before_lobby_leave`

```elixir
@callback before_lobby_leave(GameServer.Accounts.User.t(), term()) ::
  hook_result({GameServer.Accounts.User.t(), term()})
```

# `before_lobby_update`

```elixir
@callback before_lobby_update(term(), map()) :: hook_result(map())
```

# `before_stop`

```elixir
@callback before_stop() :: any()
```

# `before_user_kicked`

```elixir
@callback before_user_kicked(
  GameServer.Accounts.User.t(),
  GameServer.Accounts.User.t(),
  term()
) ::
  hook_result(
    {GameServer.Accounts.User.t(), GameServer.Accounts.User.t(), term()}
  )
```

# `on_custom_hook`

```elixir
@callback on_custom_hook(String.t(), list()) :: any()
```

Handle a dynamically-exported RPC function.

This callback is used for function names that were registered at runtime (eg.
via a plugin's `after_startup/0` return value) and therefore may not exist as
exported Elixir functions on the hooks module.

Receives the function name and the argument list.

# `call`

Call an arbitrary function exported by the configured hooks module.

This is a safe wrapper that checks function existence, enforces an allow-list
if configured and runs the call inside a short Task with a configurable
timeout to avoid long-running user code.

Returns {:ok, result} | {:error, reason}

# `caller`

```elixir
@spec caller() :: any() | nil
```

When a hooks function is executed via `call/3` or `internal_call/3`, an
optional `:caller` can be provided in the options. The caller will be
injected into the spawned task's process dictionary and is accessible via
`GameServer.Hooks.caller/0` (the raw value) or `caller_id/0` (the numeric id
when the value is a user struct or map containing `:id`).

# `caller_id`

```elixir
@spec caller_id() :: integer() | nil
```

# `caller_user`

```elixir
@spec caller_user() :: GameServer.Accounts.User.t() | nil
```

Return the user struct for the current caller when available. This will
  attempt to resolve the caller via GameServer.Accounts.get_user!/1 when the
  caller is an integer id or a map containing an `:id` key. Returns nil when
  no caller or user is found.

# `exported_functions`

Return a list of exported functions on the currently registered hooks module.

The result is a list of maps like: [%{name: "start_game", arities: [2,3]}, ...]
This is useful for tooling and admin UI to display what RPCs are available.

# `internal_call`

Call an internal lifecycle callback. When a callback is missing this
  returns a sensible default (eg. {:ok, attrs} for before callbacks) so
  domain code doesn't need to handle missing hooks specially in most cases.

# `invoke`

Invoke a dynamic hook function by name.

This is used by `GameServer.Schedule` to call scheduled job callbacks.
Unlike `internal_call/3`, this is designed for user-defined functions
that are not part of the core lifecycle callbacks.

Returns `:ok` on success, `{:error, reason}` on failure or if the
function doesn't exist.

# `module`

Return the configured module that implements the hooks behaviour.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
