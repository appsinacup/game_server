defmodule GameServerUmbrella.MixProject do
  use Mix.Project

  def project do
    [
      app: :game_server,
      name: "GameServer",
      version: System.get_env("APP_VERSION") || "1.0.0",
      elixir: "~> 1.19",
      apps_path: "apps",
      start_permanent: Mix.env() == :prod,
      listeners: [Phoenix.CodeReloader],
      docs: docs(),
      aliases: aliases(),
      deps: deps()
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  defp aliases do
    [
      setup: ["do --app game_server_host setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      lint: ["format --check-formatted", "credo --strict"],
      precommit: [
        "compile --warning-as-errors",
        "deps.unlock --unused",
        "format",
        "gen.sdk",
        "test",
        "credo --strict"
      ],
      "assets.setup": ["do --app game_server_host assets.setup"],
      "assets.build": ["do --app game_server_host assets.build"],
      "assets.deploy": ["do --app game_server_host assets.deploy"],
      "ecto.setup": ["do --app game_server_host ecto.setup"],
      "ecto.reset": ["do --app game_server_host ecto.reset"],
      "ecto.migrate": ["do --app game_server_host ecto.migrate"],
      "ecto.rollback": ["do --app game_server_host ecto.rollback"],
      "phx.server": ["do --app game_server_host phx.server"],
      "phx.routes": ["do --app game_server_host phx.routes"],
      "phx.gen.secret": ["do --app game_server_host phx.gen.secret"]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.39.3", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      ignore_apps: [:game_server_web, :game_server_host]
    ]
  end
end
