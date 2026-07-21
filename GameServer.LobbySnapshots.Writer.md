# `GameServer.LobbySnapshots.Writer`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/lobby_snapshots/writer.ex#L1)

Buffers snapshots and events and bulk-inserts them.

Buffering is the point: `record_event/4` is called from inside the serialized
game loop, where a synchronous DB round trip shows up as gameplay stutter. An
enqueue is a `cast` and returns immediately.

This is a plain per-node process, not a singleton. Ordering comes from
`(inserted_at, id)` with UUIDv7 ids, so nothing has to be centrally assigned
and two nodes writing for the same lobby interleave correctly on read.

Durability is best-effort, deliberately. A run bad enough to take the node
down is one worth keeping, so the buffer flushes on `terminate/2` and holds at
most 200ms of work. A failed flush discards its batch and counts it — that
is what keeps a DB outage from growing the buffer without bound, degrading
into lost history rather than an OOM that takes the server with it. `stats/0`
exposes the count so a silently-lossy writer stays visible.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `cluster_stats`

```elixir
@spec cluster_stats() :: %{
  buffered: non_neg_integer(),
  dropped: non_neg_integer(),
  nodes: pos_integer(),
  unreachable: non_neg_integer()
}
```

Writer stats summed across the cluster.

Each node buffers independently, so reading only the local process would
under-report dropped rows — and a silently-lossy writer is the one thing the
admin view most needs to show. Unreachable nodes are counted rather than
failing the call, so the number is never quietly wrong without saying so.

# `enqueue_event`

```elixir
@spec enqueue_event(map()) :: :ok
```

Buffer an event.

# `enqueue_snapshot`

```elixir
@spec enqueue_snapshot(map()) :: :ok
```

Buffer a gathered snapshot. Sections arrive pre-hashed as `%{name => {hash, content}}`.

# `flush`

```elixir
@spec flush() :: :ok
```

Flush synchronously. Used by tests and by callers that need the write visible.

# `start_link`

# `stats`

```elixir
@spec stats() :: %{buffered: non_neg_integer(), dropped: non_neg_integer()}
```

Buffer depth and dropped-row count for *this node's* writer.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
