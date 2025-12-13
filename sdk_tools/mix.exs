defmodule GameServerPluginTools.MixProject do
  use Mix.Project

  def project do
    [
      app: :game_server_plugin_tools,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: []
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end
end
