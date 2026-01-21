# `GameServer.Hooks.PluginManager`

Loads and manages hook plugins shipped as OTP applications under `modules/plugins/*`.

Each plugin is expected to be a directory named after the OTP app name (e.g. `polyglot_hook`)
containing:

    modules/plugins/polyglot_hook/
      ebin/polyglot_hook.app
      ebin/Elixir.GameServer.Modules.PolyglotHook.beam
      deps/*/ebin/*.beam

The plugin's `.app` env must include the key `:hooks_module`, whose value is either a
charlist or string module name like `'Elixir.GameServer.Modules.PolyglotHook'`.

This manager is intentionally dependency-free: it only adds `ebin` directories to the code
path and uses `Application.load/1` + `Application.ensure_all_started/1`.

# `plugin_app`

```elixir
@type plugin_app() :: atom()
```

# `plugin_name`

```elixir
@type plugin_name() :: String.t()
```

# `call_rpc`

```elixir
@spec call_rpc(plugin_name(), String.t(), list(), keyword()) ::
  {:ok, any()} | {:error, term()}
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `hook_modules`

```elixir
@spec hook_modules() :: [{plugin_name(), module()}]
```

# `list`

```elixir
@spec list() :: [GameServer.Hooks.PluginManager.Plugin.t()]
```

# `lookup`

```elixir
@spec lookup(plugin_name()) ::
  {:ok, GameServer.Hooks.PluginManager.Plugin.t()} | {:error, term()}
```

# `plugins_dir`

```elixir
@spec plugins_dir() :: String.t()
```

# `reload`

```elixir
@spec reload() :: [GameServer.Hooks.PluginManager.Plugin.t()]
```

# `reload_and_after_startup`

```elixir
@spec reload_and_after_startup() :: %{
  plugins: [GameServer.Hooks.PluginManager.Plugin.t()],
  after_startup: map()
}
```

# `start_link`

```elixir
@spec start_link(keyword()) :: GenServer.on_start()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
