defmodule Mix.Tasks.Host.Db.Setup do
  use Mix.Task

  @moduledoc false

  @shortdoc "Creates the database, runs migrations, then seeds when present"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("ecto.create", ["-r", "GameServer.Repo"] ++ args)
    Mix.Task.run("host.migrate", ["-r", "GameServer.Repo"])
    Mix.Task.run("host.seed")
  end
end
