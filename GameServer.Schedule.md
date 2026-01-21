# `GameServer.Schedule`

Dynamic cron-like job scheduling for hooks.

Use this module in your `after_startup/0` hook to register scheduled jobs
that will call your hook functions at specified intervals.

This module is safe for distributed deployments - only one instance will
execute each job per period using database locks.

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

    # Callback receives context map (public function, but protected from RPC)
    def on_hourly(context) do
      IO.puts("Triggered at #{context.triggered_at}")
      :ok
    end

## Context

All callbacks receive a context map:

    %{
      triggered_at: ~U[2025-12-03 14:00:00Z],
      job_name: :on_hourly,
      schedule: "0 * * * *"
    }

## Distributed Safety

When running multiple instances, only one will execute each job per period.
This is achieved via database locks in the `schedule_locks` table.
Old locks are automatically cleaned up after 7 days.

# `cancel`

```elixir
@spec cancel(atom()) :: :ok
```

Cancel a scheduled job.

## Examples

    Schedule.cancel(:my_job)

# `cleanup_old_locks`

```elixir
@spec cleanup_old_locks(keyword()) :: {:ok, non_neg_integer()}
```

Clean up old schedule locks older than the specified number of days.

This is called automatically during job execution, but can also be
called manually if needed. Default is 7 days.

## Examples

    Schedule.cleanup_old_locks()
    Schedule.cleanup_old_locks(days: 30)

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
@spec list() :: [%{name: atom(), schedule: String.t(), state: term()}]
```

List all scheduled jobs.

Returns a list of job info maps.

# `registered_callbacks`

```elixir
@spec registered_callbacks() :: MapSet.t(atom())
```

Returns the set of callback function names registered for scheduled jobs.

These are protected from user RPC calls via `Hooks.call/3`.

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
