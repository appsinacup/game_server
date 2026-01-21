# `GameServer.Async`

Utilities for running best-effort background work.

This is intentionally used for *non-critical* side effects (cache invalidation,
notifications, hooks) where we want the caller to return quickly.

Tasks are started under a `Task.Supervisor` when available (recommended in the
host app). If the supervisor isn't running (e.g. certain test setups), we
fall back to `Task.start/1`.

# `zero_arity_fun`

```elixir
@type zero_arity_fun() :: (-&gt; any())
```

# `run`

```elixir
@spec run(zero_arity_fun()) :: :ok
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
