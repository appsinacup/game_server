# `GameServer.Schedule`
[🔗](https://github.com/appsinacup/game_server/blob/v1.0.7/lib/game_server/schedule.ex#L1)

Dynamic cron-like job scheduling for hooks.

Use this module in your `after_startup/0` hook to register scheduled jobs
that will call your hook functions at specified intervals.

Jobs are durable and safe for distributed deployments: they run through the
background job queue (`GameServer.Jobs`, backed by Oban), so exactly one
instance executes each job per period and a crash mid-run is retried.

Scheduled callbacks are automatically protected from user RPC calls.

## Examples

    def after_startup do
      # Simple intervals
      Schedule.every_minutes(5, :on_every_5m)
      Schedule.hourly(:on_hourly)
      Schedule.daily(:on_daily)

      # With options
      Schedule.daily(:on_morning_report, hour: 9)
      Schedule.weekly(:on_monday, day: :monday, hour: 10)

      # Full cron syntax
      Schedule.cron(:my_job, "0 */6 * * *", :on_every_6h)

      :ok
    end

    # Callback receives a context map (public function, but protected from RPC)
    def on_hourly(context) do
      IO.puts("Triggered at #{context["triggered_at"]}")
      :ok
    end

## Context

Callbacks run as background jobs, so the context is a **JSON map with string
keys** (`triggered_at` is an ISO8601 string):

    %{
      "triggered_at" => "2026-07-22T14:00:00Z",
      "job_name" => "on_hourly",
      "schedule" => "0 * * * *"
    }

## Distributed Safety

A single per-minute tick (`GameServer.Schedule.TickWorker`, driven by Oban's
leader-elected Cron plugin) enqueues each due callback as a **unique** job.
Oban's uniqueness guarantees a callback runs at most once per period across
the whole cluster — no application-level locks required.

# `cancel`

```elixir
@spec cancel(atom()) :: :ok
```

Cancel a scheduled job.

## Examples

    Schedule.cancel(:my_job)

# `cron`

```elixir
@spec cron(atom(), String.t(), atom()) :: :ok | {:error, term()}
```

Register a job with full cron syntax.

## Examples

    Schedule.cron(:my_job, "*/15 * * * *", :on_every_15m)
    Schedule.cron(:weekdays, "0 9 * * 1-5", :on_weekday_morning)

# `daily`

```elixir
@spec daily(atom(), hour: 0..23, minute: 0..59) :: :ok | {:error, term()}
```

Run a job every day.

## Options

  * `:hour` - hour of the day (0-23), default: 0
  * `:minute` - minute of the hour (0-59), default: 0

## Examples

    Schedule.daily(:on_midnight)
    Schedule.daily(:on_morning, hour: 9)
    Schedule.daily(:on_evening, hour: 18, minute: 30)

# `every_minutes`

```elixir
@spec every_minutes(pos_integer(), atom()) :: :ok | {:error, term()}
```

Run a job every N minutes.

## Examples

    Schedule.every_minutes(5, :on_5m)
    Schedule.every_minutes(15, :on_15m)

# `hourly`

```elixir
@spec hourly(atom(), [{:minute, 0..59}]) :: :ok | {:error, term()}
```

Run a job every hour.

## Options

  * `:minute` - minute of the hour (0-59), default: 0

## Examples

    Schedule.hourly(:on_hourly)
    Schedule.hourly(:on_half_hour, minute: 30)

# `list`

```elixir
@spec list() :: [%{name: atom(), schedule: String.t(), hook: atom(), state: atom()}]
```

List all scheduled jobs.

Returns a list of job info maps.

# `registered_callbacks`

```elixir
@spec registered_callbacks() :: MapSet.t(atom())
```

Returns the set of callback function names registered for background jobs.

The union of hook functions bound to an active schedule and any hook enqueued
via `GameServer.Jobs`. These are protected from user RPC calls via
`Hooks.call/3`. Cancelling a schedule drops its callback from the set unless
another schedule (or a `Jobs` enqueue) still references it.

# `weekly`

```elixir
@spec weekly(atom(), day: atom(), hour: 0..23, minute: 0..59) ::
  :ok | {:error, term()}
```

Run a job every week.

## Options

  * `:day` - day of week (`:sunday`, `:monday`, etc.), default: `:sunday`
  * `:hour` - hour of the day (0-23), default: 0
  * `:minute` - minute of the hour (0-59), default: 0

## Examples

    Schedule.weekly(:on_sunday)
    Schedule.weekly(:on_monday_morning, day: :monday, hour: 9)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
