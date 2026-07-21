# `GameServer.Matchmaking`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/matchmaking.ex#L1)

Public API for the built-in matchmaking system.

Matchmaking is ticket-based. Each call to `join/4` creates a ticket in the
database. The periodic `GameServer.Matchmaking.Worker` groups queued tickets
that share the same `match_params` and creates a hidden lobby for each match.

Tickets are the source of truth; there is no cached queue. The sweep reads
them directly through the `(status, queued_at)` index, and the worker
serializes the sweep cluster-wide so only one instance forms matches at a
time.

## Liveness

A queued ticket only means something while its owner can still be pulled
into a lobby. Two things keep the queue honest:

  * `UserChannel.terminate/2` cancels the user's tickets when their socket
    closes, and
  * `prune_offline/0` sweeps tickets whose owner the database no longer
    considers online — the safety net for tickets created over HTTP by a
    client that never opened a socket.

# `assign_lobby`

```elixir
@spec assign_lobby([GameServer.Matchmaking.Ticket.t()], Ecto.UUID.t()) :: :ok
```

Associates already-claimed tickets with their created lobby.

# `cancel`

```elixir
@spec cancel(Ecto.UUID.t()) :: non_neg_integer()
```

Cancels the user's queued tickets. Returns how many were cancelled.

A party queues as a unit, so it leaves as one: cancelling any member's ticket
cancels the whole party's. Any member may do this — only the leader can queue,
but nobody should be stuck in a queue they cannot leave.

# `cancel_ticket`

```elixir
@spec cancel_ticket(Ecto.UUID.t()) ::
  {:ok, GameServer.Matchmaking.Ticket.t()} | {:error, :not_found}
```

Cancels one ticket by id, whoever owns it — for admins clearing a stuck
ticket. Returns `{:error, :not_found}` for an unknown, malformed or
already-resolved id.

# `claim`

```elixir
@spec claim([GameServer.Matchmaking.Ticket.t()]) :: :ok | :conflict
```

Atomically claims a formed match: flips its tickets from queued to matched.

Runs inside the sweep's cluster lock, before any lobby exists (the lobby is
created outside the lock because `Lobbies` fires hooks and broadcasts, which
must not run inside a transaction). The `status == queued` guard makes the
claim atomic: if any ticket was cancelled since it was read, nothing is
claimed and `:conflict` is returned.

# `count_tickets`

```elixir
@spec count_tickets(keyword()) :: non_neg_integer()
```

Counts tickets matching the same filters as `list_tickets/1`.

# `current_ticket`

```elixir
@spec current_ticket(Ecto.UUID.t()) :: GameServer.Matchmaking.Ticket.t() | nil
```

The user's current queued ticket, or nil.

# `discard`

```elixir
@spec discard([GameServer.Matchmaking.Ticket.t()]) :: :ok
```

Cancels claimed tickets whose owner could not be seated in the lobby.
Unlike `requeue/1` these do not go back in the queue — a user who cannot
join a lobby (banned, already in one) would fail again on every tick.

# `get_ticket`

```elixir
@spec get_ticket(Ecto.UUID.t()) :: GameServer.Matchmaking.Ticket.t() | nil
```

Fetches a ticket by id, or nil when the id is unknown or malformed.

# `join`

```elixir
@spec join(
  GameServer.Accounts.User.t(),
  map(),
  pos_integer() | nil,
  pos_integer() | nil
) ::
  {:ok, GameServer.Matchmaking.Ticket.t()}
  | {:error, Ecto.Changeset.t() | atom()}
```

Adds a user — or their whole party — to the matchmaking queue.

`match_params` is a map of arbitrary string keys and values, for example
`%{"mode" => "deathmatch", "map" => "dust2"}`. Only tickets with exactly the
same parameters are matched together.

`min_players` and `max_players` can be passed to override the defaults.

## Parties

A user in a party cannot queue alone: only the leader may queue, and doing so
creates one ticket per member sharing the party's id. Those tickets are
matched as an indivisible unit. Because only the leader queues, every member's
ticket carries the same limits by construction — there is no way for members
to disagree about `min_players`/`max_players`.

Returns the caller's own ticket. Fails with:

  * `{:error, :not_party_leader}` — a member tried to queue
  * `{:error, :party_too_large}` — the party cannot fit in `max_players`
  * `{:error, :party_has_blocked_pair}` — two members have blocked each other
  * `{:error, :already_queued}` — the caller or a party member is queued

# `list_queued_by_params`

```elixir
@spec list_queued_by_params() :: %{
  required(map()) =&gt; [GameServer.Matchmaking.Ticket.t()]
}
```

All queued tickets grouped by `match_params`, oldest first within a group.

Read straight from the database: the queue changes on every join and the
sweep runs seconds apart, so caching here would only ever serve stale rows.

# `list_tickets`

```elixir
@spec list_tickets(keyword()) :: [GameServer.Matchmaking.Ticket.t()]
```

Lists tickets for the admin views, newest first.

Options: `:status`, `:user_id`, `:page`, `:page_size`.

# `prune_offline`

```elixir
@spec prune_offline() :: non_neg_integer()
```

Cancels queued tickets whose owner has been offline past the grace period.

Reads `users.is_online` — the flag the user channel maintains — instead of
taking a caller-supplied id list, so it stays correct on any node. Going
offline is not enough on its own: the player must have been gone longer than
`matchmaking_offline_grace_ms`, so a brief disconnect does not cost a queue
position. A player who queued over HTTP and never opened a socket has no
`last_seen_at`, so their `queued_at` starts the same grace period.

A party is matched as a unit, so it is pruned as one: if any member times
out, the whole party leaves the queue. Returns how many tickets were
cancelled.

# `requeue`

```elixir
@spec requeue([GameServer.Matchmaking.Ticket.t()]) :: :ok
```

Returns claimed tickets to the queue (lobby creation failed).

# `stats`

```elixir
@spec stats() :: %{
  queued: non_neg_integer(),
  matched: non_neg_integer(),
  cancelled: non_neg_integer(),
  queues: [%{params: map(), waiting: non_neg_integer()}]
}
```

Queue statistics for the admin dashboard and the public stats endpoint:
counts by status, plus the depth of each distinct queued `match_params`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
