# `GameServer.Async`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/async.ex#L1)

Utilities for running best-effort background work.

This is intentionally used for *non-critical* side effects (cache invalidation,
notifications, hooks) where we want the caller to return quickly.

Tasks are started under a `Task.Supervisor` bounded by `:max_children`
(see the host application supervision tree). When the supervisor is at
capacity, the work runs **inline in the caller** instead of spawning an
unsupervised process — under overload the system degrades to synchronous
execution, which applies natural back-pressure instead of growing an
unbounded process count. If the supervisor isn't running at all (e.g.
certain test setups), we fall back to `Task.start/1`.

Telemetry: `[:game_server, :async, :overload]` is emitted each time a task
is executed inline because the supervisor was full.

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
