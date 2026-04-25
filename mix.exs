defmodule GameServerUmbrella.MixProject do
  use Mix.Project

  def project do
    [
      app: :game_server,
      name: "GameServer",
      version: System.get_env("APP_VERSION") || "1.0.0",
      elixir: "~> 1.19",
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
      "deps.get": [host_cmd("deps.get")],
      "deps.audit": [host_cmd("deps.audit")],
      setup: [host_cmd("setup")],
      compile: [host_cmd("compile")],
      test: [host_cmd("test"), web_cmd("test")],
      lint: [host_cmd("lint"), web_cmd("lint")],
      precommit: [
        host_test_cmd("precommit"),
        web_cmd("format"),
        web_test_cmd("compile --warning-as-errors"),
        web_test_cmd("test"),
        web_cmd("credo --strict")
      ],
      "assets.setup": [host_cmd("assets.setup")],
      "assets.build": [host_cmd("assets.build")],
      "assets.deploy": [host_cmd("assets.deploy")],
      "ecto.setup": [host_cmd("ecto.setup")],
      "ecto.reset": [host_cmd("ecto.reset")],
      "ecto.migrate": [host_cmd("ecto.migrate")],
      "ecto.rollback": [host_cmd("ecto.rollback")],
      "phx.server": [host_cmd("phx.server")],
      "phx.routes": [host_cmd("phx.routes")],
      "phx.gen.secret": [host_cmd("phx.gen.secret")]
    ]
  end

  defp host_cmd(task), do: "cmd --cd apps/game_server_host mix #{task}"
  defp web_cmd(task), do: "cmd --cd apps/game_server_web mix #{task}"
  defp host_test_cmd(task), do: "cmd --cd apps/game_server_host env MIX_ENV=test mix #{task}"
  defp web_test_cmd(task), do: "cmd --cd apps/game_server_web env MIX_ENV=test mix #{task}"
end
