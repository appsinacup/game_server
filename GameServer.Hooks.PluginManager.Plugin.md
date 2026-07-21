# `GameServer.Hooks.PluginManager.Plugin`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/hooks/plugin_manager.ex#L38)

A loaded plugin descriptor.

This is a runtime struct used by `GameServer.Hooks.PluginManager` to report which
plugins were discovered and whether they successfully loaded and started.

# `t`

```elixir
@type t() :: %GameServer.Hooks.PluginManager.Plugin{
  app: atom(),
  ebin_paths: [String.t()],
  hooks_module: module() | nil,
  loaded_at: DateTime.t() | nil,
  modules: [module()],
  name: String.t(),
  status: :ok | {:error, term()},
  vsn: String.t() | nil
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
