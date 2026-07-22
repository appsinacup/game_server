# `GameServer.Jobs`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/jobs.ex#L1)

Durable background jobs, backed by Oban.

Use this from your hooks to run work that must survive a restart, retry on
failure, or happen later — things `GameServer.Async` (best-effort, in-memory)
cannot guarantee.

Jobs are persisted in the same database as the rest of your data (Postgres or
SQLite), executed with retries and backoff, and observable from the admin
panel.

## Enqueue a hook to run in the background

    # Run `on_welcome_email` now, retried on failure
    GameServer.Jobs.enqueue_hook(:on_welcome_email, %{"user_id" => user.id})

    # Run it in 24 hours (delayed job)
    GameServer.Jobs.enqueue_in(24 * 60 * 60, :on_trial_reminder, %{"user_id" => user.id})

The callback receives the args map you passed. **Args are stored as JSON**, so
keys come back as strings and values must be JSON-encodable:

    def on_welcome_email(%{"user_id" => user_id}) do
      # ...
      :ok
    end

Returning `{:error, reason}` from the callback makes the job retry with
backoff; `:ok`/`{:ok, _}` completes it.

## Recurring work

For cron-like recurring jobs use `GameServer.Schedule` (also durable, built on
top of this module).

## RPC safety

Any hook enqueued through `enqueue_hook/3` is automatically protected from
client RPC — a client cannot invoke a job callback directly.

# `args`

```elixir
@type args() :: map()
```

# `cancel`

```elixir
@spec cancel(integer()) :: :ok
```

Cancel a pending job by its id (from `enqueue_hook/3` or `enqueue_in/4`).

# `enqueue_hook`

```elixir
@spec enqueue_hook(atom(), args(), keyword()) :: {:ok, integer()} | {:error, term()}
```

Enqueue a hook function to run in the background.

Returns `{:ok, job_id}` — pass `job_id` to `cancel/1` to cancel it while it is
still pending. See the module doc for the callback contract.

# `enqueue_in`

```elixir
@spec enqueue_in(non_neg_integer(), atom(), args(), keyword()) ::
  {:ok, integer()} | {:error, term()}
```

Enqueue a hook function to run after `seconds`.

Returns `{:ok, job_id}`; cancel it with `cancel/1` before it runs.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
