# `GameServer.Config`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/config.ex#L1)

Typed reads of environment variables a plugin declared via `env_vars/0`.

`System.get_env/1` always returns a string, so every caller ends up writing
its own `== "true"` or `String.to_integer/1` — and each one invents its own
answer for a missing or malformed value. Declaring the variable once gives
the coercion a single home:

    def env_vars do
      [%{name: "MYGAME_DIFFICULTY", default: "normal", description: "..."},
       %{name: "MYGAME_MAX_BOTS", default: 8, description: "..."},
       %{name: "MYGAME_TUTORIAL", default: true, description: "..."}]
    end

    Config.get("MYGAME_MAX_BOTS")   #=> 8      (integer, from the default)
    Config.get("MYGAME_TUTORIAL")   #=> true   (boolean)

The type is inferred from the declared default, so `default: 8` reads as an
integer without a separate `:type` key. Declare `:type` explicitly only when
the default cannot carry it — typically a secret with `default: nil`.

A value that does not parse falls back to the default and logs, because a
typo in an env var should not take the server down at read time.

# `value`

```elixir
@type value() :: String.t() | integer() | float() | boolean() | nil
```

# `get`

```elixir
@spec get(String.t()) :: value()
```

Reads a declared variable, coerced to its declared type.

Returns the declared default when unset, and raises for a name no plugin
declared — an undeclared read is a bug, not a runtime condition.

# `get`

```elixir
@spec get(String.t(), value()) :: value()
```

Reads a variable, coerced to match `default`, whether declared or not.

For core and host code, which has no plugin declaration to hang types on.

# `infer_type`

```elixir
@spec infer_type(value()) :: :string | :integer | :float | :boolean
```

The inferred or declared type of a value: `:string`, `:integer`, `:float`, `:boolean`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
