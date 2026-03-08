# `GameServer.Limits`

Central module for configurable validation limits.

All limits have sensible defaults and can be overridden at boot time via
`config :game_server_core, GameServer.Limits, key: value` or at runtime
via `Application.put_env(:game_server_core, GameServer.Limits, [...])`.

## Environment variables

Each limit can be set via an environment variable. The env var name maps to
the limit key with an uppercase `LIMIT_` prefix, e.g.:

    LIMIT_MAX_METADATA_SIZE=32768   -> :max_metadata_size
    LIMIT_MAX_PAGE_SIZE=100         -> :max_page_size

Env vars are read once at boot in `config/runtime.exs`.

## Usage in schemas

    import GameServer.Limits, only: [get: 1, validate_metadata_size: 2]

    changeset
    |> validate_length(:title, max: GameServer.Limits.get(:max_group_title))
    |> validate_metadata_size(:metadata)

## Usage in controllers

    page_size = GameServer.Limits.clamp_page_size(params["page_size"])

# `all`

```elixir
@spec all() :: map()
```

Returns a map of all limit keys and their current effective values.

# `clamp_page`

```elixir
@spec clamp_page(any()) :: pos_integer()
```

Clamps a raw page parameter to [1, ∞). Same parsing logic as page_size.

# `clamp_page_size`

```elixir
@spec clamp_page_size(any(), integer()) :: integer()
```

Clamps a raw page_size parameter to [1, max_page_size].
Accepts nil, string, or integer. Returns integer.

# `defaults`

```elixir
@spec defaults() :: map()
```

Returns the compiled defaults map. Useful for the admin UI to display
defaults vs. overrides.

# `get`

```elixir
@spec get(atom()) :: integer() | any()
```

Returns the current value for the given limit key.

Reads from `Application.get_env(:game_server_core, GameServer.Limits)` first,
falling back to the compiled default.

# `validate_metadata_size`

```elixir
@spec validate_metadata_size(Ecto.Changeset.t(), atom(), atom()) :: Ecto.Changeset.t()
```

Validates that a `:map` field, when serialized to JSON, does not exceed
`max_metadata_size` bytes. Add this to any changeset that casts a metadata
or arbitrary JSON map field.

    changeset
    |> validate_metadata_size(:metadata)
    |> validate_metadata_size(:value, :max_kv_value_size)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
