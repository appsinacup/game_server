defmodule Mix.Tasks.Host.Seed do
  use Mix.Task

  @moduledoc false

  @shortdoc "Runs the host's priv/repo/seeds.exs when it exists"

  @impl Mix.Task
  def run(_args) do
    seeds_path = Path.expand("priv/repo/seeds.exs")

    if File.exists?(seeds_path) do
      Mix.Task.run("run", [seeds_path])
    else
      Mix.shell().info("No seeds file at #{seeds_path}, skipping")
    end
  end
end
