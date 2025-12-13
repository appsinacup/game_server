defmodule ExampleHook.MixProject do
  use Mix.Project

  def project do
    [
      app: :example_hook,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      env: [hooks_module: GameServer.Modules.ExampleHook]
    ]
  end

  # NOTE: This example lives inside the main server repo, so we depend on the
  # in-repo SDK via a path dependency.
  defp deps do
    [
      {:game_server_sdk, path: "../../../sdk"},
      {:bunt, "~> 1.0"}
    ]
  end
end
