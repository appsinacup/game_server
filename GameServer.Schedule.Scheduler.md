# `GameServer.Schedule.Scheduler`

Defines a quantum Scheduler.

When used, the quantum scheduler expects the `:otp_app` as option.
The `:otp_app` should point to an OTP application that has
the quantum runner configuration. For example, the quantum scheduler:

    defmodule GameServer.Schedule.Scheduler do
      use Quantum, otp_app: :game_server_core
    end

Could be configured with:

    config :game_server_core, GameServer.Schedule.Scheduler,
      jobs: [
        {"@daily", {Backup, :backup, []}},
      ]

## Configuration:

  * `:clock_broadcaster_name` - GenServer name of clock broadcaster \
    *(unstable, may break without major release until declared stable)*

  * `:execution_broadcaster_name` - GenServer name of execution broadcaster \
    *(unstable, may break without major release until declared stable)*

  * `:executor_supervisor_name` - GenServer name of execution supervisor \
    *(unstable, may break without major release until declared stable)*

  * `:debug_logging` - Turn on debug logging

  * `:jobs` - list of cron jobs to execute

  * `:job_broadcaster_name` - GenServer name of job broadcaster \
    *(unstable, may break without major release until declared stable)*

  * `:name` - GenServer name of scheduler \
    *(unstable, may break without major release until declared stable)*

  * `:node_selector_broadcaster_name` - GenServer name of node selector broadcaster \
    *(unstable, may break without major release until declared stable)*

  * `:overlap` - Default overlap of new Job

  * `:otp_app` - Application where scheduler runs

  * `:run_strategy` - Default Run Strategy of new Job

  * `:schedule` - Default schedule of new Job

  * `:storage` - Storage to use for persistence

  * `:storage_name` - GenServer name of storage \
    *(unstable, may break without major release until declared stable)*

  * `:supervisor_module` - Module to supervise scheduler \
    Can be overwritten to supervise processes differently (for example for clustering) \
    *(unstable, may break without major release until declared stable)*

  * `:task_registry_name` - GenServer name of task registry \
    *(unstable, may break without major release until declared stable)*

  * `:task_supervisor_name` - GenServer name of task supervisor \
    *(unstable, may break without major release until declared stable)*

  * `:timeout` - Sometimes, you may come across GenServer timeout errors
    esp. when you have too many jobs or high load. The default `GenServer.call/3`
    timeout is `5_000`.

  * `:timezone` - Default timezone of new Job

## Telemetry

* `[:quantum, :job, :add]`
  * Description: dispatched when a job is added
  * Measurements: `%{}`
  * Metadata: `%{job: Quantum.Job.t(), scheduler: atom()}`

* `[:quantum, :job, :update]`
  * Description: dispatched when a job is updated
  * Measurements: `%{}`
  * Metadata: `%{job: Quantum.Job.t(), scheduler: atom()}`

* `[:quantum, :job, :delete]`
  * Description: dispatched when a job is deleted
  * Measurements: `%{}`
  * Metadata: `%{job: Quantum.Job.t(), scheduler: atom()}`

* `[:quantum, :job, :start]`
  * Description: dispatched on job execution start
  * Measurements: `%{system_time: integer()}`
  * Metadata: `%{telemetry_span_context: term(), job: Quantum.Job.t(), node: Node.t(), scheduler: atom()}`

* `[:quantum, :job, :stop]`
  * Description: dispatched on job execution end
  * Measurements: `%{duration: integer()}`
  * Metadata: `%{telemetry_span_context: term(), job: Quantum.Job.t(), node: Node.t(), scheduler: atom(), result: term()}`

* `[:quantum, :job, :exception]`
  * Description: dispatched on job execution fail
  * Measurements: `%{duration: integer()}`
  * Metadata: `%{telemetry_span_context: term(), job: Quantum.Job.t(), node: Node.t(), scheduler: atom(), kind: :throw | :error | :exit, reason: term(), stacktrace: list()}`

### Examples

    iex(1)> :telemetry_registry.discover_all(:quantum)
    :ok
    iex(2)> :telemetry_registry.spannable_events()
    [{[:quantum, :job], [:start, :stop, :exception]}]
    iex(3)> :telemetry_registry.list_events
    [
      {[:quantum, :job, :add], Quantum,
       %{
         description: "dispatched when a job is added",
         measurements: "%{}",
         metadata: "%{job: Quantum.Job.t(), scheduler: atom()}"
       }},
      {[:quantum, :job, :delete], Quantum,
       %{
         description: "dispatched when a job is deleted",
         measurements: "%{}",
         metadata: "%{job: Quantum.Job.t(), scheduler: atom()}"
       }},
      {[:quantum, :job, :exception], Quantum,
       %{
         description: "dispatched on job execution fail",
         measurements: "%{duration: integer()}",
         metadata: "%{telemetry_span_context: term(), job: Quantum.Job.t(), node: Node.t(), scheduler: atom(), kind: :throw | :error | :exit, reason: term(), stacktrace: list()}"
       }},
      {[:quantum, :job, :start], Quantum,
       %{
         description: "dispatched on job execution start",
         measurements: "%{system_time: integer()}",
         metadata: "%{telemetry_span_context: term(), job: Quantum.Job.t(), node: Node.t(), scheduler: atom()}"
       }},
      {[:quantum, :job, :stop], Quantum,
       %{
         description: "dispatched on job execution end",
         measurements: "%{duration: integer()}",
         metadata: "%{telemetry_span_context: term(), job: Quantum.Job.t(), node: Node.t(), scheduler: atom(), result: term()}"
       }},
      {[:quantum, :job, :update], Quantum,
       %{
         description: "dispatched when a job is updated",
         measurements: "%{}",
         metadata: "%{job: Quantum.Job.t(), scheduler: atom()}"
       }}
    ]

# `child_spec`

```elixir
@spec child_spec(Keyword.t()) :: Supervisor.child_spec()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
