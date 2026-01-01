defmodule GameServer.Async do
  @moduledoc """
  Utilities for running best-effort background work.

  This is intentionally used for *non-critical* side effects (cache invalidation,
  notifications, hooks) where we want the caller to return quickly.

  Tasks are started under a `Task.Supervisor` when available (recommended in the
  host app). If the supervisor isn't running (e.g. certain test setups), we
  fall back to `Task.start/1`.
  """

  require Logger

  @supervisor GameServer.TaskSupervisor

  @type zero_arity_fun :: (-> any())

  @spec run(zero_arity_fun()) :: :ok
  def run(fun) when is_function(fun, 0) do
    _ = start_task(fun)
    :ok
  end

  defp start_task(fun) do
    wrapped = fn ->
      try do
        fun.()
      rescue
        e ->
          Logger.error("async task crashed: " <> Exception.format(:error, e, __STACKTRACE__))
      catch
        kind, reason ->
          Logger.error("async task crashed: #{inspect({kind, reason})}")
      end
    end

    case Process.whereis(@supervisor) do
      nil ->
        Task.start(wrapped)

      _pid ->
        case Task.Supervisor.start_child(@supervisor, wrapped) do
          {:ok, pid} ->
            {:ok, pid}

          {:error, _} = err ->
            # If the supervisor is overloaded or unavailable, don't block the caller.
            _ = Task.start(wrapped)
            err
        end
    end
  end
end
