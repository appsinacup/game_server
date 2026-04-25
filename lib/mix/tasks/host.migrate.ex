defmodule Mix.Tasks.Host.Migrate do
  use Mix.Task

  @moduledoc false

  @shortdoc "Runs core and host migrations"

  alias Mix.Tasks.Ecto.Migrate

  @migration_args [
    "--migrations-path",
    "apps/game_server_core/priv/repo/migrations",
    "--migrations-path",
    "priv/repo/migrations"
  ]

  @impl Mix.Task
  def run(args) do
    Migrate.run(@migration_args ++ args)
  end
end
