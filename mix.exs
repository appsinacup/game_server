defmodule GameServerUmbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      start_permanent: Mix.env() == :prod,
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
      setup: ["do --app game_server_web setup"],
      test: ["do --app game_server_web test"],
      lint: ["do --app game_server_web lint"],
      precommit: ["do --app game_server_web precommit"],
      "assets.setup": ["do --app game_server_web assets.setup"],
      "assets.build": ["do --app game_server_web assets.build"],
      "assets.deploy": ["do --app game_server_web assets.deploy"],
      "ecto.setup": ["do --app game_server_web ecto.setup"],
      "ecto.reset": ["do --app game_server_web ecto.reset"],
      "ecto.migrate": ["do --app game_server_web ecto.migrate"],
      "ecto.rollback": ["do --app game_server_web ecto.rollback"],
      "phx.server": ["do --app game_server_web phx.server"],
      "phx.routes": ["do --app game_server_web phx.routes"],
      "phx.gen.secret": ["do --app game_server_web phx.gen.secret"]
    ]
  end
end
