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
        [:logger, :runtime_tools, :swoosh, :sentry] ++
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
      {:game_server_core, path: "apps/game_server_core"},
      {:game_server_web, path: "apps/game_server_web"},
      {:phoenix, "~> 1.8.3"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.6.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.21"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.20"},
      {:castore, "~> 1.0"},
      {:gen_smtp, "~> 1.0"},
      {:req, "~> 0.5"},
      {:sentry, "~> 11.0"},
      {:hackney, "~> 1.18"},
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
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": [
        "ecto.create",
        "ecto.migrate",
        "cmd --cd apps/game_server_web mix run priv/repo/seeds.exs"
      ],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "ecto.migrate": ["host.migrate"],
      "ecto.rollback": ["host.rollback"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test", web_test_cmd("test")],
      lint: [
        "format --check-formatted",
        "credo --strict",
        web_cmd("format --check-formatted"),
        web_cmd("credo --strict")
      ],
      precommit: [
        "compile --warning-as-errors",
        "format",
        "gen.sdk",
        "test",
        "credo --strict",
        web_test_cmd("compile --warning-as-errors"),
        web_cmd("format"),
        web_cmd("credo --strict"),
        "deps.audit"
      ],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind game_server_web", "esbuild game_server_web"],
      "assets.deploy": [
        "tailwind game_server_web --minify",
        "esbuild game_server_web --minify",
        "phx.digest",
        "cmd --cd apps/game_server_web mix phx.digest"
      ]
    ]
  end

  defp web_cmd(task), do: "cmd --cd apps/game_server_web mix #{task}"
  defp web_test_cmd(task), do: "cmd --cd apps/game_server_web env MIX_ENV=test mix #{task}"
end
