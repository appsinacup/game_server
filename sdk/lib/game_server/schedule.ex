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
  

  **Note:** This is an SDK stub. Calling these functions will raise an error.
  The actual implementation runs on the GameServer.
  """

  @doc """
    Cancel a scheduled job.
    
    ## Examples
    
        Schedule.cancel(:my_job)
    
  """
  def cancel(_name) do
    raise "GameServer.Schedule.cancel/1 is a stub - only available at runtime on GameServer"
  end


  @doc """
    Clean up old schedule locks older than the specified number of days.
    
    This is called automatically during job execution, but can also be
    called manually if needed. Default is 7 days.
    
    ## Examples
    
        Schedule.cleanup_old_locks()
        Schedule.cleanup_old_locks(days: 30)
    
  """
  def cleanup_old_locks() do
    raise "GameServer.Schedule.cleanup_old_locks/0 is a stub - only available at runtime on GameServer"
  end


  @doc """
    Clean up old schedule locks older than the specified number of days.
    
    This is called automatically during job execution, but can also be
    called manually if needed. Default is 7 days.
    
    ## Examples
    
        Schedule.cleanup_old_locks()
        Schedule.cleanup_old_locks(days: 30)
    
  """
  def cleanup_old_locks(_opts) do
    raise "GameServer.Schedule.cleanup_old_locks/1 is a stub - only available at runtime on GameServer"
  end


  @doc """
    Register a job with full cron syntax.
    
    ## Examples
    
        Schedule.cron(:my_job, "*/15 * * * *", :on_every_15m)
        Schedule.cron(:weekdays, "0 9 * * 1-5", :on_weekday_morning)
    
  """
  def cron(_name, _cron_expr, _hook_fn) do
    raise "GameServer.Schedule.cron/3 is a stub - only available at runtime on GameServer"
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
  def daily(_hook_fn) do
    raise "GameServer.Schedule.daily/1 is a stub - only available at runtime on GameServer"
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
  def daily(_hook_fn, _opts) do
    raise "GameServer.Schedule.daily/2 is a stub - only available at runtime on GameServer"
  end


  @doc """
    Run a job every N minutes.
    
    ## Examples
    
        Schedule.every_minutes(5, :on_5m)
        Schedule.every_minutes(15, :on_15m)
    
  """
  def every_minutes(_n, _hook_fn) do
    raise "GameServer.Schedule.every_minutes/2 is a stub - only available at runtime on GameServer"
  end


  @doc """
    Run a job every hour.
    
    ## Options
    
      * `:minute` - minute of the hour (0-59), default: 0
    
    ## Examples
    
        Schedule.hourly(:on_hourly)
        Schedule.hourly(:on_half_hour, minute: 30)
    
  """
  def hourly(_hook_fn) do
    raise "GameServer.Schedule.hourly/1 is a stub - only available at runtime on GameServer"
  end


  @doc """
    Run a job every hour.
    
    ## Options
    
      * `:minute` - minute of the hour (0-59), default: 0
    
    ## Examples
    
        Schedule.hourly(:on_hourly)
        Schedule.hourly(:on_half_hour, minute: 30)
    
  """
  def hourly(_hook_fn, _opts) do
    raise "GameServer.Schedule.hourly/2 is a stub - only available at runtime on GameServer"
  end


  @doc """
    List all scheduled jobs.
    
    Returns a list of job info maps.
    
  """
  def list() do
    raise "GameServer.Schedule.list/0 is a stub - only available at runtime on GameServer"
  end


  @doc """
    Returns the set of callback function names registered for scheduled jobs.
    
    These are protected from user RPC calls via `Hooks.call/3`.
    
  """
  @spec registered_callbacks() :: MapSet.t(atom())
  def registered_callbacks() do
    raise "GameServer.Schedule.registered_callbacks/0 is a stub - only available at runtime on GameServer"
  end


  @doc false
  def start_link() do
    raise "GameServer.Schedule.start_link/0 is a stub - only available at runtime on GameServer"
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
  def weekly(_hook_fn) do
    raise "GameServer.Schedule.weekly/1 is a stub - only available at runtime on GameServer"
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
  def weekly(_hook_fn, _opts) do
    raise "GameServer.Schedule.weekly/2 is a stub - only available at runtime on GameServer"
  end

end
