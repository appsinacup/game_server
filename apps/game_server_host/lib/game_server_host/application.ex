defmodule GameServerHost.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Application.start(:os_mon)

    # Host-owned extension point:
    # tell the endpoint which router to dispatch to at runtime.
    Application.put_env(:game_server_web, :router, GameServerHost.Router, persistent: true)

    # Initialize ETS table for Schedule callbacks (before Scheduler starts)
    GameServer.Schedule.start_link()

    children = [
      GameServerWeb.Telemetry,
      GameServer.Repo,
      {GameServer.Cache, []},
      {Task.Supervisor, name: GameServer.TaskSupervisor},
      {DNSCluster, query: Application.get_env(:game_server_web, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: GameServer.PubSub},
      GameServerWeb.AdminLogBuffer,
      GameServerWeb.Endpoint,
      # Load hook plugins (OTP apps) shipped under modules/plugins/*
      GameServer.Hooks.PluginManager,
      # Quantum scheduler for cron-like jobs
      GameServer.Schedule.Scheduler
    ]

    opts = [strategy: :one_for_one, name: GameServerHost.Supervisor]

    result = Supervisor.start_link(children, opts)

    {:ok, modules} = :application.get_key(:game_server_web, :modules)

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

  @impl true
  def config_change(changed, _new, removed) do
    GameServerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
