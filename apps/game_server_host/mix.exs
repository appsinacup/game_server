defmodule GameServerHost.MixProject do
  use Mix.Project

  def project do
    [
      app: :game_server_host,
      version: System.get_env("APP_VERSION") || "1.0.0",
      elixir: "~> 1.19",
      elixirc_paths: ["lib"],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # Share build artifacts and config with the umbrella root.
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock"
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:game_server_core, in_umbrella: true},
      {:game_server_web, in_umbrella: true}
    ]
  end
end
