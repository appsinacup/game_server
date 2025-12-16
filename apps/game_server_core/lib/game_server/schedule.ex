defmodule GameServer.Schedule do
  @moduledoc """
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
        IO.puts("Triggered at \#{context.triggered_at}")
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
  """

  import Ecto.Query
  alias Crontab.CronExpression.Composer
  alias Crontab.CronExpression.Parser
  alias GameServer.Repo
  alias GameServer.Schedule.Lock
  alias GameServer.Schedule.Scheduler
  require Logger

  # ETS table to track registered scheduled callbacks
  @callbacks_table :schedule_callbacks

  @doc false
  @spec start_link() :: :ignore
  def start_link do
    # Create ETS table to track registered callbacks
    # Format: {job_name, hook_fn}
    :ets.new(@callbacks_table, [:set, :public, :named_table])
    :ignore
  end

  @doc """
  Returns the set of callback function names registered for scheduled jobs.

  These are protected from user RPC calls via `Hooks.call/3`.
  """
  @spec registered_callbacks() :: MapSet.t(atom())
  def registered_callbacks do
    if :ets.whereis(@callbacks_table) != :undefined do
      @callbacks_table
      |> :ets.tab2list()
      |> Enum.map(fn {_name, hook_fn} -> hook_fn end)
      |> MapSet.new()
    else
      MapSet.new()
    end
  end

  defp register_callback(name, hook_fn) do
    if :ets.whereis(@callbacks_table) != :undefined do
      :ets.insert(@callbacks_table, {name, hook_fn})
    end
  end

  defp unregister_callback(name) do
    if :ets.whereis(@callbacks_table) != :undefined do
      :ets.delete(@callbacks_table, name)
    end
  end

  @day_map %{
    sunday: 0,
    monday: 1,
    tuesday: 2,
    wednesday: 3,
    thursday: 4,
    friday: 5,
    saturday: 6
  }

  @doc """
  Register a job with full cron syntax.

  ## Examples

      Schedule.cron(:my_job, "*/15 * * * *", :on_every_15m)
      Schedule.cron(:weekdays, "0 9 * * 1-5", :on_weekday_morning)
  """
  @spec cron(atom(), String.t(), atom()) :: :ok | {:error, term()}
  def cron(name, cron_expr, hook_fn) when is_atom(name) and is_atom(hook_fn) do
    case Parser.parse(cron_expr) do
      {:ok, schedule} ->
        Scheduler.new_job()
        |> Quantum.Job.set_name(name)
        |> Quantum.Job.set_schedule(schedule)
        |> Quantum.Job.set_task(fn -> invoke_hook(name, cron_expr, hook_fn) end)
        |> Scheduler.add_job()

        # Register callback so it's blocked from RPC
        register_callback(name, hook_fn)

        Logger.info("[Schedule] Registered job #{name} with schedule #{cron_expr}")
        :ok

      {:error, reason} ->
        Logger.error(
          "[Schedule] Failed to parse cron expression '#{cron_expr}': #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Run a job every N minutes.

  ## Examples

      Schedule.every_minutes(5, :on_5m)
      Schedule.every_minutes(15, :on_15m)
  """
  @spec every_minutes(pos_integer(), atom()) :: :ok | {:error, term()}
  def every_minutes(n, hook_fn) when is_integer(n) and n > 0 and is_atom(hook_fn) do
    cron(hook_fn, "*/#{n} * * * *", hook_fn)
  end

  @doc """
  Run a job every hour.

  ## Options

    * `:minute` - minute of the hour (0-59), default: 0

  ## Examples

      Schedule.hourly(:on_hourly)
      Schedule.hourly(:on_half_hour, minute: 30)
  """
  @spec hourly(atom()) :: :ok | {:error, term()}
  @spec hourly(atom(), minute: 0..59) :: :ok | {:error, term()}
  def hourly(hook_fn, opts \\ []) when is_atom(hook_fn) do
    minute = Keyword.get(opts, :minute, 0)
    cron(hook_fn, "#{minute} * * * *", hook_fn)
  end

  @doc """
  Run a job every day.

  ## Options

    * `:hour` - hour of the day (0-23), default: 0
    * `:minute` - minute of the hour (0-59), default: 0

  ## Examples

      Schedule.daily(:on_midnight)
      Schedule.daily(:on_morning, hour: 9)
      Schedule.daily(:on_evening, hour: 18, minute: 30)
  """
  @spec daily(atom()) :: :ok | {:error, term()}
  @spec daily(atom(), hour: 0..23, minute: 0..59) :: :ok | {:error, term()}
  def daily(hook_fn, opts \\ []) when is_atom(hook_fn) do
    hour = Keyword.get(opts, :hour, 0)
    minute = Keyword.get(opts, :minute, 0)
    cron(hook_fn, "#{minute} #{hour} * * *", hook_fn)
  end

  @doc """
  Run a job every week.

  ## Options

    * `:day` - day of week (`:sunday`, `:monday`, etc.), default: `:sunday`
    * `:hour` - hour of the day (0-23), default: 0
    * `:minute` - minute of the hour (0-59), default: 0

  ## Examples

      Schedule.weekly(:on_sunday)
      Schedule.weekly(:on_monday_morning, day: :monday, hour: 9)
  """
  @spec weekly(atom()) :: :ok | {:error, term()}
  @spec weekly(atom(), day: atom(), hour: 0..23, minute: 0..59) :: :ok | {:error, term()}
  def weekly(hook_fn, opts \\ []) when is_atom(hook_fn) do
    day = Keyword.get(opts, :day, :sunday)
    hour = Keyword.get(opts, :hour, 0)
    minute = Keyword.get(opts, :minute, 0)
    day_num = Map.get(@day_map, day, 0)
    cron(hook_fn, "#{minute} #{hour} * * #{day_num}", hook_fn)
  end

  @doc """
  Cancel a scheduled job.

  ## Examples

      Schedule.cancel(:my_job)
  """
  @spec cancel(atom()) :: :ok
  def cancel(name) when is_atom(name) do
    Scheduler.delete_job(name)
    unregister_callback(name)
    Logger.info("[Schedule] Cancelled job #{name}")
    :ok
  end

  @doc """
  List all scheduled jobs.

  Returns a list of job info maps.
  """
  @spec list() :: [%{name: atom(), schedule: String.t(), state: term()}]
  def list do
    Scheduler.jobs()
    |> Enum.map(fn {name, job} ->
      %{
        name: name,
        schedule: Composer.compose(job.schedule),
        state: job.state
      }
    end)
  end

  @doc """
  Clean up old schedule locks older than the specified number of days.

  This is called automatically during job execution, but can also be
  called manually if needed. Default is 7 days.

  ## Examples

      Schedule.cleanup_old_locks()
      Schedule.cleanup_old_locks(days: 30)
  """
  @spec cleanup_old_locks() :: {:ok, non_neg_integer()}
  @spec cleanup_old_locks(keyword()) :: {:ok, non_neg_integer()}
  def cleanup_old_locks(opts \\ []) do
    days = Keyword.get(opts, :days, 7)
    cutoff = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)

    {deleted, _} =
      from(l in Lock, where: l.executed_at < ^cutoff)
      |> Repo.delete_all()

    if deleted > 0 do
      Logger.info("[Schedule] Cleaned up #{deleted} old schedule locks")
    end

    {:ok, deleted}
  end

  # Invoke the hook function with context, using DB lock for distributed safety
  defp invoke_hook(name, schedule, hook_fn) do
    period_key = calculate_period_key(schedule)

    # Occasionally clean up old locks (roughly once per day per instance)
    maybe_cleanup_old_locks()

    case acquire_lock(name, period_key) do
      {:ok, _lock} ->
        context = %{
          triggered_at: DateTime.utc_now(),
          job_name: name,
          schedule: schedule
        }

        Logger.debug("[Schedule] Acquired lock, invoking hook #{hook_fn} for job #{name}")

        try do
          GameServer.Hooks.invoke(hook_fn, [context])
        rescue
          e ->
            Logger.error(
              "[Schedule] Error invoking hook #{hook_fn}: #{Exception.format(:error, e, __STACKTRACE__)}"
            )
        end

      {:error, _} ->
        Logger.debug(
          "[Schedule] Skipping job #{name} - already executed for period #{period_key}"
        )

        :skipped
    end
  end

  # Run cleanup roughly once per day (based on random chance)
  defp maybe_cleanup_old_locks do
    # 1 in 1440 chance (once per day if jobs run every minute)
    if :rand.uniform(1440) == 1 do
      Task.start(fn -> cleanup_old_locks() end)
    end
  end

  # Try to acquire a lock for this job + period combination
  # Returns {:ok, lock} if we got the lock, {:error, changeset} if already taken
  defp acquire_lock(job_name, period_key) do
    %Lock{}
    |> Lock.changeset(%{
      job_name: to_string(job_name),
      period_key: period_key,
      executed_at: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  # Calculate a period key based on the cron schedule
  # This determines the "bucket" for deduplication
  defp calculate_period_key(schedule) do
    now = DateTime.utc_now()

    cond do
      # Every N minutes (*/N * * * *)
      String.starts_with?(schedule, "*/") ->
        # Per-minute bucket
        Calendar.strftime(now, "%Y-%m-%d-%H-%M")

      # Hourly (N * * * *)
      match?([_, "*", "*", "*", "*"], String.split(schedule, " ")) ->
        Calendar.strftime(now, "%Y-%m-%d-%H")

      # Daily (N N * * *)
      match?([_, _, "*", "*", "*"], String.split(schedule, " ")) ->
        Calendar.strftime(now, "%Y-%m-%d")

      # Weekly or other patterns
      true ->
        # Default to daily bucket
        Calendar.strftime(now, "%Y-%m-%d")
    end
  end
end
