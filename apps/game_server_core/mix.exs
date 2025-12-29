defmodule GameServerCore.MixProject do
  use Mix.Project

  @version "1.0.7"
  @source_url "https://github.com/appsinacup/game_server"

  def project do
    [
      app: :game_server_core,
      version: System.get_env("APP_VERSION") || @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # Share build artifacts and config with the umbrella root.
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      description: description(),
      package: package(),
      docs: docs(),
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:bcrypt_elixir, "~> 3.0"},
      {:nebulex, "~> 3.0.0-rc.2"},
      {:nebulex_local, "~> 3.0.0-rc.2"},
      {:nebulex_distributed, "~> 3.0.0-rc.2"},
      {:nebulex_redis_adapter, "~> 3.0.0-rc.2"},
      {:decorator, "~> 1.4"},
      {:phoenix, "~> 1.8.3"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13.3"},
      {:ecto_sqlite3, "~> 0.12"},
      {:postgrex, ">= 0.0.0"},
      {:swoosh, "~> 1.19.9"},
      {:gen_smtp, "~> 1.0"},
      {:req, "~> 0.5"},
      {:sentry, "~> 11.0"},
      {:hackney, "~> 1.18"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:ueberauth, "~> 0.10"},
      {:ueberauth_discord, "~> 0.7"},
      {:ueberauth_apple, "~> 0.2"},
      {:ueberauth_google, "~> 0.12"},
      {:ueberauth_facebook, "~> 0.10"},
      {:ueberauth_steam_strategy, "~> 0.1"},
      {:guardian, "~> 2.3"},
      {:quantum, "~> 3.5"},
      {:corsica, "~> 2.0"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Core functionality for Gamend GameServer, including user management, authentication, friends, matchmaking, and more.
    """
  end

  defp package do
    [
      name: "game_server_core",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md"
      },
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE)
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
