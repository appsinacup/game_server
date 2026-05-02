defmodule GameServerWeb.MixProject do
  use Mix.Project

  @version "1.0.5"
  @source_url "https://github.com/appsinacup/game_server"

  def project do
    [
      app: :game_server_web,
      version: System.get_env("APP_VERSION") || @version,
      elixir: "~> 1.19",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      listeners: [Phoenix.CodeReloader],
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:game_server_core, path: "../game_server_core"},
      {:phoenix, "~> 1.8.3"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.6.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.21"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      # heroicons is intentionally NOT listed here.
      # It is a GitHub-only dep (not on Hex) so it cannot be declared in a
      # library that is published to Hex. The host/consumer app must declare
      # heroicons in its own mix.exs and run `assets.setup` to make the icon
      # CSS available to the shared tailwind plugin in apps/game_server_web/assets/vendor/heroicons.
      {:swoosh, "~> 1.20"},
      {:castore, "~> 1.0"},
      {:gen_smtp, "~> 1.0"},
      {:req, "~> 0.5"},
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
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:guardian, "~> 2.3"},
      {:ueberauth_steam_strategy, "~> 0.1"},
      {:quantum, "~> 3.5"},
      {:corsica, "~> 2.0"},
      {:hammer, "~> 7.2"},
      {:earmark, "~> 1.4"},
      {:ex_webrtc, "~> 0.16.0"},
      {:ex_sctp, "~> 0.1.2"},
      {:prom_ex, "~> 1.11"},
      {:geolix, "~> 2.0"},
      {:geolix_adapter_mmdb2, "~> 0.6"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": [
        "ecto.create",
        "ecto.migrate",
        "run priv/repo/seeds.exs"
      ],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: [
        "ecto.create --quiet",
        "ecto.migrate --quiet",
        "compile --force",
        "test"
      ],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind game_server_web", "esbuild game_server_web"],
      "assets.deploy": [
        "tailwind game_server_web --minify",
        "esbuild game_server_web --minify",
        "phx.digest"
      ],
      lint: ["format --check-formatted", "credo --strict"],
      precommit: [
        "compile --warning-as-errors",
        "format",
        "gen.sdk",
        "test",
        "credo --strict"
      ]
    ]
  end

  defp description do
    """
    Web interface for Gamend GameServer, built with Phoenix Framework. Provides APIs, authentication, and real-time features.
    """
  end

  defp package do
    [
      name: "game_server_web",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      files: ~w(lib priv/gettext priv/static/fonts .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: ["README.md"]
    ]
  end
end
