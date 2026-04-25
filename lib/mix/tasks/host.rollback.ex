defmodule Mix.Tasks.Host.Rollback do
  use Mix.Task

  @moduledoc false

  @shortdoc "Rolls back core and host migrations"

  alias Mix.Tasks.Ecto.Rollback

  @migration_args [
    "--migrations-path",
    "apps/game_server_core/priv/repo/migrations",
    "--migrations-path",
    "priv/repo/migrations"
  ]

  @impl Mix.Task
  def run(args) do
    Rollback.run(@migration_args ++ args)
  end
end
