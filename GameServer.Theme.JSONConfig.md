# `GameServer.Theme.JSONConfig`

JSON-backed Theme provider. Reads a JSON file specified by the THEME_CONFIG
environment variable (single canonical runtime source) — e.g. THEME_CONFIG=theme/custom.json

The path may be relative to the project root (eg. "theme/default_config.json")
or an absolute path. When the file is missing we fall back to the built-in
default at `priv/static/theme/default_config.json`.

This implementation keeps things simple: every call will parse the JSON file
and return a map. There's also a `reload/0` API for callers who want to
force a re-read (not required for normal usage).

# `get_theme`

```elixir
@spec get_theme(String.t() | nil) :: map()
```

Variant of `get_theme/0` that prefers a locale-specific THEME_CONFIG file when present.

Given a base config like `modules/example_config.json` and locale `"en"`, we will
try `modules/example_config.en.json` first (and fall back to the base file).

# `packaged_default`

Return the packaged default theme config found under priv/static/theme/default_config.json
as a map (or an empty map when missing/invalid). This is a convenience wrapper so other
modules can rely on a single source of truth for the packaged defaults.

# `runtime_path`

Returns the runtime THEME_CONFIG path if present and non-blank, otherwise nil.
This function intentionally treats blank env values as unset.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
