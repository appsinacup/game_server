defmodule GameServer.Schedule.Scheduler do
  @moduledoc """
  Quantum scheduler for running scheduled jobs.

  This module is started by the application supervisor and provides
  the underlying cron-like scheduling infrastructure for `GameServer.Schedule`.
  """

  use Quantum, otp_app: :game_server_core
end
