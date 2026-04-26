defmodule Mix.Tasks.Host.Rollback do
  use Mix.Task

  @moduledoc false

  @shortdoc "Rolls back core and host migrations"

  alias Mix.Tasks.Ecto.Rollback

  @impl Mix.Task
  def run(args) do
    Rollback.run(migration_args() ++ args)
  end

  defp migration_args do
    # Ensure host-local migrations path always exists to avoid Ecto path errors.
    File.mkdir_p!("priv/repo/migrations")

    migration_paths()
    |> Enum.flat_map(&["--migrations-path", &1])
  end

  defp migration_paths do
    [
      core_migrations_path(),
      "apps/game_server_core/priv/repo/migrations",
      "deps/game_server_core/priv/repo/migrations",
      "deps/game_server_core/apps/game_server_core/priv/repo/migrations",
      "priv/repo/migrations"
    ]
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&Path.expand/1)
    |> Enum.filter(&File.dir?/1)
    |> Enum.uniq()
  end

  defp core_migrations_path do
    case Mix.Project.deps_paths()[:game_server_core] do
      nil -> nil
      dep_path -> Path.join(dep_path, "priv/repo/migrations")
    end
  end
end
