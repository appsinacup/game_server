defmodule GameServerSdk.MixProject do
  use Mix.Project

  @version "1.0.26"
  @source_url "https://github.com/appsinacup/game_server"

  def project do
    [
      app: :game_server_sdk,
      version: System.get_env("APP_VERSION") || @version,
      elixir: "~> 1.20",
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
      {:ex_doc, "~> 0.40", only: :dev, runtime: false}
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
      extras: ["README.md"],
      # Group the GameServer.Hooks callbacks by entity so the docs read grouped
      # (User / Lobby / Group / …) instead of one long alphabetical list. Keyed
      # by name via the same classifier the admin runtime page uses.
      groups_for_docs: hook_doc_groups()
    ]
  end

  @hook_groups ~w(Lifecycle User Lobby Group Party Chat Achievement Leaderboard Tournament Matchmaking Payments KV)

  defp hook_doc_groups do
    for group <- @hook_groups do
      {:"#{group} hooks",
       fn meta -> meta[:kind] == :callback and hook_group(to_string(meta[:name])) == group end}
    end
  end

  # Mirror of GameServerWeb.RuntimeIntrospection.hook_group/1 (kept in sync by
  # hand — both are tiny and this one runs at doc-build time with no app loaded).
  defp hook_group(name) do
    cond do
      name in ~w(after_startup before_stop on_custom_hook) -> "Lifecycle"
      String.contains?(name, "kv") -> "KV"
      String.contains?(name, "chat") -> "Chat"
      String.contains?(name, "achievement") -> "Achievement"
      String.contains?(name, "score") -> "Leaderboard"
      String.contains?(name, "matchmaking") -> "Matchmaking"
      String.contains?(name, "tournament") -> "Tournament"
      String.contains?(name, "purchase") or String.contains?(name, "entitlement") -> "Payments"
      String.contains?(name, "party") -> "Party"
      String.contains?(name, "group") -> "Group"
      String.contains?(name, "lobby") -> "Lobby"
      String.contains?(name, "user") -> "User"
      true -> "Other"
    end
  end
end
