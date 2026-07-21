# `GameServer.Theme.JSONConfig`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/theme/json_config.ex#L1)

JSON-backed Theme provider. Reads a locale-specific JSON file from either the
THEME_CONFIG environment variable override or the host-owned default path
configured by the runnable host application.

Only locale-suffixed files are loaded (e.g. `example_config.en.json`,
`example_config.es.json`). The base path itself (without a locale suffix) is
never loaded directly — it serves only as a naming template to derive
locale-specific paths.

When THEME_CONFIG is not set, the provider falls back to the host-owned
default path configured under `GameServer.Theme.JSONConfig`.

Theme configs are cached in `:persistent_term` after the first read so
subsequent requests never hit the filesystem. Call `reload/0` to clear the
cache (e.g. after editing the JSON file at runtime).

# `active_path`

Returns the effective theme config path, preferring THEME_CONFIG when set and
otherwise falling back to the host-owned default path.

# `get_theme`

```elixir
@spec get_theme(String.t() | nil) :: map()
```

Variant of `get_theme/0` that prefers a locale-specific THEME_CONFIG file when present.

Given a base config like `modules/example_config.json` and locale `"es"`, we will
try `modules/example_config.es.json` first, then fall back to `.en.json`.
The base file itself is never loaded.

# `runtime_path`

Returns the runtime THEME_CONFIG override if present and non-blank,
otherwise nil. This intentionally excludes the host default path so admin
diagnostics can distinguish explicit overrides from host defaults.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
