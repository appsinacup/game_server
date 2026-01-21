# `GameServer.Hooks.PluginBuilder`

Builds an OTP plugin bundle from plugin source code on disk.

This is intended for admin-only workflows in development/self-hosted setups.
It runs `mix` commands on the server host/container.

# `build_result`

```elixir
@type build_result() :: %{
  ok?: boolean(),
  plugin: String.t(),
  source_dir: String.t(),
  started_at: DateTime.t(),
  finished_at: DateTime.t(),
  steps: [step_result()]
}
```

# `step_result`

```elixir
@type step_result() :: %{
  cmd: String.t(),
  status: non_neg_integer(),
  output: String.t()
}
```

# `build`

```elixir
@spec build(String.t()) :: {:ok, build_result()} | {:error, term()}
```

# `list_buildable_plugins`

```elixir
@spec list_buildable_plugins() :: [String.t()]
```

# `sources_dir`

```elixir
@spec sources_dir() :: String.t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
