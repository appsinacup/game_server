# `GameServer.Repo.MigrationPaths`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/repo/migration_paths.ex#L1)

Resolves every migration directory that belongs to a gamend deployment.

A host application (the umbrella's `game_server_host`, or a downstream game
such as gamend_polyglot) runs **core migrations plus its own**, and core can
be present either as an umbrella app or as a dependency. Anything that walks
migrations — the `host.*` mix tasks, the admin runtime page — must consider
the same set, so the list lives here rather than being copied per caller.

# `all`

```elixir
@spec all(keyword()) :: [String.t()]
```

Existing migration directories, absolute and de-duplicated.

Pass `ensure_host: true` (the mix tasks do) to create the host's own
`priv/repo/migrations` first, so Ecto does not fail on a missing path in a
project that has not written a migration yet.

# `as_args`

```elixir
@spec as_args(keyword()) :: [String.t()]
```

The paths as `--migrations-path <dir>` arguments for the Ecto mix tasks.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
