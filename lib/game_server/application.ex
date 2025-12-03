defmodule GameServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Application.start(:os_mon)

    # OAuth session data is now DB backed (oauth_sessions table) - no
    # ETS table created here.

    # Initialize ETS table for Schedule callbacks (before Scheduler starts)
    GameServer.Schedule.start_link()

    children =
      [
        GameServerWeb.Telemetry,
        GameServer.Repo,
        {DNSCluster, query: Application.get_env(:game_server, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: GameServer.PubSub},
        GameServerWeb.Endpoint,
        # Quantum scheduler for cron-like jobs
        GameServer.Schedule.Scheduler,
        # optional hooks watcher - will be a no-op when :hooks_file_path isn't set
        GameServer.Hooks.Watcher
      ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GameServer.Supervisor]

    result = Supervisor.start_link(children, opts)

    # Log the number of Channel modules detected in the running application.
    # We use the application module list and a simple naming convention
    # (modules ending with "Channel") to detect channels.
    {:ok, modules} = :application.get_key(:game_server, :modules)

    channel_mods =
      modules
      |> Enum.filter(fn m ->
        case Atom.to_string(m) do
          "Elixir." <> rest ->
            String.ends_with?(rest, "Channel") and String.starts_with?(rest, "GameServerWeb.")

          _ ->
            false
        end
      end)

    require Logger
    Logger.info("detected #{length(channel_mods)} channel modules: #{inspect(channel_mods)}")

    result
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GameServerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
