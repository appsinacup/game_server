# `GameServer.Hooks.DynamicRpcs`

Runtime registry for *dynamic* RPC function names exported by hook plugins.

## Goal

Allow hook plugins to expose additional callable function names without
defining them as exported Elixir functions (eg. without `def my_fn/1`).

The intended pattern is:

- Plugin implements `after_startup/0` and returns a list of maps describing
  which dynamic RPC names should be callable.
- Plugin implements `rpc/2` (or `rpc/3`) to handle these names at runtime.
- `GameServer.Hooks.PluginManager.call_rpc/4` falls back to the registry when
  the requested function is not exported.

## Export format

`after_startup/0` may return a list like:

    [
      %{hook: "my_dynamic_fn"},
      %{"hook" => "other_fn", "meta" => %{...}}
    ]

Required:
- `hook` (string): the callable function name.

Optional:
- `meta` (map): arbitrary metadata.

Names are validated to contain only letters, digits, and underscores.

Note: this registry is in-memory and is rebuilt on plugin reload.

# `export`

```elixir
@type export() :: %{hook: hook_name(), meta: map()}
```

# `hook_name`

```elixir
@type hook_name() :: String.t()
```

# `plugin_name`

```elixir
@type plugin_name() :: String.t()
```

# `allowed?`

```elixir
@spec allowed?(plugin_name(), hook_name()) :: boolean()
```

# `ensure_table!`

```elixir
@spec ensure_table!() :: :ok
```

# `list_all`

```elixir
@spec list_all() :: %{optional(plugin_name()) =&gt; [export()]}
```

# `lookup`

```elixir
@spec lookup(plugin_name(), hook_name()) :: {:ok, export()} | {:error, :not_found}
```

# `register_exports`

```elixir
@spec register_exports(plugin_name(), any()) ::
  {:ok, non_neg_integer()} | {:error, term()}
```

# `reset_all`

```elixir
@spec reset_all() :: :ok
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
