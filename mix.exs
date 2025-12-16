defmodule GameServerUmbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      start_permanent: Mix.env() == :prod,
      listeners: [Phoenix.CodeReloader],
      aliases: aliases()
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
end
