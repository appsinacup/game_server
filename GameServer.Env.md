# `GameServer.Env`

Helpers for reading and parsing environment variables.

Safe to use from `config/runtime.exs` (runs at runtime after compilation).

# `bool_default`

```elixir
@type bool_default() :: boolean()
```

# `atom_existing`

```elixir
@spec atom_existing(String.t(), atom() | nil) :: atom() | nil
```

# `bool`

```elixir
@spec bool(String.t(), bool_default()) :: boolean()
```

# `integer`

```elixir
@spec integer(String.t(), integer() | nil) :: integer() | nil
```

# `log_level`

```elixir
@spec log_level(String.t(), Logger.level() | false) :: Logger.level() | false
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
