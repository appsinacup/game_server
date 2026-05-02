defmodule GameServerHost.MixProject do
  use Mix.Project

  def project do
    [
      app: :game_server_host,
      name: "GameServer",
      version: System.get_env("APP_VERSION") || "1.0.0",
      elixir: "~> 1.19",
      elixirc_paths: ["lib"],
      start_permanent: Mix.env() == :prod,
      listeners: [Phoenix.CodeReloader],
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {GameServerHost.Application, []},
      extra_applications:
        [:logger, :runtime_tools, :swoosh] ++
          if(Mix.env() == :prod, do: [:os_mon], else: [])
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  defp deps do
    [
      shared_dep(:game_server_core, "apps/game_server_core"),
      shared_dep(:game_server_web, "apps/game_server_web"),
      {:phoenix, "~> 1.8.3"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.6.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.21"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.20"},
      {:gen_smtp, "~> 1.0"},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:ueberauth_discord, "~> 0.7"},
      {:ueberauth_apple, "~> 0.2"},
      {:ueberauth_google, "~> 0.12"},
      {:ueberauth_facebook, "~> 0.10"},
      {:bandit, "~> 1.9"},
      {:ueberauth, "~> 0.10"},
      {:open_api_spex, "~> 3.22"},
      {:credo, ">= 1.7.16", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:guardian, "~> 2.3"},
      {:ueberauth_steam_strategy, "~> 0.1"},
      {:quantum, "~> 3.5"},
      {:corsica, "~> 2.0"},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "db.setup", "assets.setup", "assets.build"],
      "dev.start": [
        "ecto.create --quiet -r GameServer.Repo",
        "db.migrate",
        "assets.build",
        "phx.server"
      ],
      "prod.start": ["assets.deploy", "db.setup", "phx.server"],
      "db.migrate": ["host.migrate -r GameServer.Repo"],
      "db.rollback": ["host.rollback -r GameServer.Repo"],
      "db.setup": [
        "ecto.create -r GameServer.Repo",
        "db.migrate",
        "run --if-present priv/repo/seeds.exs"
      ],
      "db.reset": ["ecto.drop -r GameServer.Repo", "db.setup"],
      test:
        [
          "ecto.create --quiet -r GameServer.Repo",
          "host.migrate --quiet -r GameServer.Repo",
          "test"
        ] ++ local_web_commands([web_test_cmd("test")]),
      lint:
        ["format --check-formatted", "credo --strict"] ++
          local_web_commands([web_cmd("format --check-formatted"), web_cmd("credo --strict")]),
      precommit:
        [
          "compile --warning-as-errors",
          "format",
          "gen.sdk",
          "test",
          "credo --strict"
        ] ++
          local_web_commands([
            web_test_cmd("compile --warning-as-errors"),
            web_cmd("format"),
            web_cmd("credo --strict")
          ]),
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind game_server_web", "esbuild game_server_web"],
      "assets.deploy": [
        "tailwind game_server_web --minify",
        "esbuild game_server_web --minify",
        "phx.digest"
      ]
    ]
  end

  defp web_cmd(task), do: "cmd --cd #{web_app_path()} mix #{task}"
  defp web_test_cmd(task), do: "cmd --cd #{web_app_path()} env MIX_ENV=test mix #{task}"

  defp local_web_commands(commands) do
    if local_web_source?(), do: commands, else: []
  end

  defp local_web_source?, do: File.dir?("apps/game_server_web")

  defp web_app_path, do: shared_app_path(:game_server_web, "apps/game_server_web")

  defp shared_app_path(app, fallback) do
    dep_root = Mix.Project.deps_paths()[app]
    nested_dep_path = dep_root && Path.join(dep_root, fallback)

    cond do
      File.dir?(fallback) -> fallback
      nested_dep_path && File.dir?(nested_dep_path) -> nested_dep_path
      dep_root -> dep_root
      true -> fallback
    end
  end

  defp shared_dep(app, local_path) do
    if File.dir?(local_path) do
      {app, path: local_path}
    else
      {app, github: "appsinacup/game_server", sparse: local_path, override: true}
    end
  end
end
