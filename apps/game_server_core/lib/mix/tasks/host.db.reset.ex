defmodule Mix.Tasks.Host.Db.Reset do
  use Mix.Task

  @moduledoc false

  @shortdoc "Drops the database and sets it up again"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("ecto.drop", ["-r", "GameServer.Repo"] ++ args)
    Mix.Task.run("host.db.setup")
  end
end
