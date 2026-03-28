# `GameServer.Theme.JSONConfig`

JSON-backed Theme provider. Reads a locale-specific JSON file specified by the
THEME_CONFIG environment variable — e.g. THEME_CONFIG=modules/example_config.json

Only locale-suffixed files are loaded (e.g. `example_config.en.json`,
`example_config.es.json`). The base path itself (without a locale suffix) is
never loaded directly — it serves only as a naming template to derive
locale-specific paths.

When THEME_CONFIG is not set, an empty map is returned. There is no implicit
fallback to packaged defaults — the UI will display blanks until you configure
a THEME_CONFIG path.

Theme configs are cached in `:persistent_term` after the first read so
subsequent requests never hit the filesystem. Call `reload/0` to clear the
cache (e.g. after editing the JSON file at runtime).

# `get_theme`

```elixir
@spec get_theme(String.t() | nil) :: map()
```

Variant of `get_theme/0` that prefers a locale-specific THEME_CONFIG file when present.

Given a base config like `modules/example_config.json` and locale `"es"`, we will
try `modules/example_config.es.json` first, then fall back to `.en.json`.
The base file itself is never loaded.

# `packaged_default`

Return the packaged default theme config found under
`priv/static/theme/default_config.en.json` as a map (or an empty map when
missing/invalid). This is a convenience wrapper for programmatic access
(e.g. admin dashboards showing reference values). It is NOT merged into
runtime themes.

# `runtime_path`

Returns the runtime THEME_CONFIG path if present and non-blank, otherwise nil.
This function intentionally treats blank env values as unset.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
