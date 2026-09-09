# `Gamend.ClientLogs`
[🔗](https://github.com/appsinacup/gamend/blob/v1.0.7/lib/gamend/client_logs.ex#L1)

Logs from the game client, put where the server's own logs already are.

A client uploads batches of entries; each one is re-emitted through `Logger`
and leaves by whatever path the host already uses — stdout, the rotating file
(`GamendWeb.FileLogHandler`), the admin ring buffer, and from there whatever
aggregator scrapes them. `client_sessions` holds one row per run as the index
over that: who, which build, which lobbies, how many errors.

## Why not a table of log lines

Because the interesting question is never "show me this client's logs" — it
is "show me what the client and the server were both doing at 14:03". Putting
the lines in a second store means answering that with a join across two
systems, forever. Putting them in the same stream means answering it with one
query, and a log aggregator indexes and compresses them for a fraction of
what a Postgres row each would cost.

So the only durable rows here are per *session*, which is a few per player
per day rather than a few hundred.

## The correlation key

Every emitted line carries a logfmt prefix naming its session, user, lobby
and screen:

    [client] session=0f1e… user=9ab3… level=info cat=game lobby=77c1… screen=boat seq=42 | Game starting

In the *message*, deliberately, not only in `Logger` metadata. Metadata reaches
stdout only for the keys a host lists in its `:default_formatter` config, and
a feature that silently stops correlating because a host never copied a config
line is worse than a slightly longer line. Metadata is set as well, for the
structured filters on the admin page.

A grep for `session=<id>` therefore returns client *and* server lines
interleaved, in any log store, with no configuration. The same id reaches
server-side lines through `GamendWeb.Plugs.ClientSession`, which stamps it
from the `x-gamend-session` header.

## Levels

Client levels are carried as `level=` in the line, not as the `Logger` level.
The two mean different things: the `Logger` level governs how chatty the
*server* is, and hosts routinely purge `debug` at compile time in production
(`compile_time_purge_matching`). Routing a client `debug` entry through
`Logger.debug/1` would mean asking a client for verbose capture and then
dropping it on arrival, in exactly the builds where it is hardest to
reproduce. Client `warn` and `error` map to their `Logger` equivalents so
existing alerting sees them; everything below maps to `Logger.info`.

One consequence worth knowing before wondering where the logs went: a host
running `Logger` at `:warning` drops every client line below `warn`, because
the primary level filter runs before any handler. Collecting client `info`
requires the server's own level to be `:info` or lower. The admin page says so
rather than showing an empty list — see `logger_level_blocks_collection?/0`.

Disabled by default; see `enabled?/0`.

# `capture_policy`

```elixir
@spec capture_policy() :: map()
```

The capture policy a client should apply, served to it at startup.

Clients gate their own uploads on this: the floor level, plus per-category
overrides so a noisy category can be silenced (or a quiet one opened up)
without shipping a build. `"off"` for a category drops it entirely.

    %{enabled: true, level: "info", categories: %{"perf" => "off"}, batch_max: 200}

# `count_sessions`

```elixir
@spec count_sessions(keyword()) :: non_neg_integer()
```

How many sessions match `opts`, for the pager.

# `enabled?`

```elixir
@spec enabled?() :: boolean()
```

Whether ingest is currently accepting batches.

Checked before any work, so the endpoint costs one config read when off.

# `get_session`

```elixir
@spec get_session(String.t()) :: Gamend.ClientLogs.Session.t() | nil
```

One session by its client-generated id.

# `ingest`

```elixir
@spec ingest(map(), keyword()) :: {:ok, map()} | {:error, atom()}
```

Accept one batch from a client.

`attrs` is the decoded request body: a `"session"` map describing the run and
an `"entries"` list. `opts` carries what the server knows and the client does
not get to assert — `:user_id` from the bearer token.

Returns `{:ok, summary}`, or `{:error, reason}` where reason is one of
`:disabled`, `:invalid`, or `:forbidden` (the session id belongs to someone
else — see `bind_owner/2`).

Emitting never fails the caller: an entry that cannot be normalized is
dropped and counted, because a malformed line in a diagnostic batch is not
worth a 500 to a client that is probably already having a bad time.

# `list_sessions`

```elixir
@spec list_sessions(keyword()) :: [Gamend.ClientLogs.Session.t()]
```

Sessions, newest activity first.

Options: `:user_id`, `:platform`, `:build`, `:app_version`, `:lobby_id`,
`:errors_only`, `:query` (matches session id or device id), `:since`,
`:until`, `:limit`, `:offset`.

# `logger_level_blocks_collection?`

```elixir
@spec logger_level_blocks_collection?() :: boolean()
```

Whether the host's own `Logger` level is discarding client entries before
they reach any handler.

Collection is configured in two places that know nothing about each other —
`level` here, and the server's `Logger` level — and the failure mode when
they disagree is an empty page rather than an error. Worth answering rather
than leaving to be rediscovered.

# `resolved_config`

```elixir
@spec resolved_config(atom()) :: term()
```

The resolved value of a config key, for tests and diagnostics.

Exposed so resolution can be asserted against the real code path rather than
a copy of it.

# `session_lobby_ids`

```elixir
@spec session_lobby_ids(String.t()) :: [String.t()]
```

Lobbies this session was in, oldest first.

The link back to the server's own view of the same runs: each id addresses a
`lobby_snapshots` timeline, so a client-side symptom and the server-side
state that produced it are one click apart.

# `set_flagged`

```elixir
@spec set_flagged(String.t(), boolean()) :: :ok
```

Mark a session as worth keeping (or not), exempting it from the ordinary
retention window.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
