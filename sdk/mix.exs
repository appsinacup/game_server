defmodule GameServerSdk.MixProject do
  use Mix.Project

  @version "1.0.8"
  @source_url "https://github.com/appsinacup/game_server"

  def project do
    [
      app: :game_server_sdk,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    SDK for GameServer hooks development. Provides type specs, documentation,
    and IDE autocomplete for GameServer modules without requiring the full server.
    """
  end

  defp package do
    [
      name: "game_server_sdk",
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
