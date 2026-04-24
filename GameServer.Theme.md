# `GameServer.Theme`

Behaviour for pluggable site theming providers.

Implementations should provide a map-like theme object that the UI
and templates can render from. We ship a small JSON-backed default
implementation that reads a JSON file (see GameServer.Theme.JSONConfig).

Recommended keys in the theme map:
  - "title" (string)
  - "tagline" (string)
  - "description" (string)
  - "theme_color" (string or map with light/dark keys)
  - "navigation" (map of nav link arrays)
  - "useful_links" (list)
  - "features" (list)
  - "metadata" (map)

# `get_setting`

```elixir
@callback get_setting(key :: atom() | String.t()) :: any()
```

# `get_theme`

```elixir
@callback get_theme() :: map()
```

# `reload`

```elixir
@callback reload() :: :ok | {:error, term()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
