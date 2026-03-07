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
      GameServer.Lobbies.SpectatorTracker,
      GameServerWeb.AdminLogBuffer,
      # Load hook plugins (OTP apps) shipped under modules/plugins/*
      GameServer.Hooks.PluginManager,
      GameServerWeb.Endpoint,
      # Auto-create notifications for friend events (must start after PubSub)
      GameServer.Notifications.FriendNotifier,
      # Quantum scheduler for cron-like jobs
      GameServer.Schedule.Scheduler
    ]

    opts = [strategy: :one_for_one, name: GameServerHost.Supervisor]

    result = Supervisor.start_link(children, opts)

    log_startup_resources()

    result
  end

  @impl true
  def config_change(changed, _new, removed) do
    GameServerWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp log_startup_resources do
    require Logger

    lines = [
      "=== GameServer startup resources ===",
      database_info(),
      cache_info(),
      mailer_info(),
      jwt_info(),
      oauth_info(),
      clustering_info(),
      sentry_info(),
      plugins_info(),
      channels_info(),
      endpoint_info()
    ]

    Logger.info(Enum.join(lines, "\n  "))
  end

  defp database_info do
    repo_config = GameServer.Repo.config()

    adapter_name = GameServer.Repo.__adapter__() |> inspect() |> String.split(".") |> List.last()

    mismatch =
      if GameServer.Repo.AdvisoryLock.postgres?() == false &&
           (System.get_env("DATABASE_URL") ||
              (System.get_env("POSTGRES_HOST") && System.get_env("POSTGRES_USER"))) do
        " [WARNING: Postgres env vars set but compiled with SQLite — rebuild with DATABASE_ADAPTER=postgres]"
      else
        ""
      end

    db =
      cond do
        repo_config[:url] -> "(url configured)"
        repo_config[:database] -> repo_config[:database]
        true -> "(default)"
      end

    pool = repo_config[:pool_size] || "default"
    "Database: #{adapter_name} #{db} (pool: #{pool})#{mismatch}"
  end

  defp cache_info do
    cache_config = Application.get_env(:game_server_core, GameServer.Cache, [])
    bypass? = Keyword.get(cache_config, :bypass_mode, false)

    if bypass? do
      "Cache: disabled (bypass mode)"
    else
      l2_config = Keyword.get(cache_config, :l2, [])
      l2_adapter = Keyword.get(l2_config, :adapter)

      l2_name =
        case l2_adapter do
          NebulexRedisAdapter -> "Redis"
          Nebulex.Adapters.Partitioned -> "Partitioned"
          nil -> "L1 only"
          other -> inspect(other)
        end

      "Cache: enabled (L2: #{l2_name})"
    end
  end

  defp mailer_info do
    mailer_config = Application.get_env(:game_server_core, GameServer.Mailer, [])
    adapter = mailer_config[:adapter]

    case adapter do
      Swoosh.Adapters.SMTP ->
        relay = mailer_config[:relay] || "?"
        "Mailer: SMTP (#{relay})"

      Swoosh.Adapters.Local ->
        "Mailer: Local (in-memory, /dev/mailbox)"

      Swoosh.Adapters.Test ->
        "Mailer: Test adapter"

      nil ->
        "Mailer: not configured"

      other ->
        "Mailer: #{inspect(other)}"
    end
  end

  defp jwt_info do
    guardian_config =
      Application.get_env(:game_server_web, GameServerWeb.Auth.Guardian, [])

    ttl = guardian_config[:ttl]
    ttl_str = if ttl, do: "#{elem(ttl, 0)} #{elem(ttl, 1)}", else: "default"
    "JWT: Guardian (TTL: #{ttl_str})"
  end

  defp oauth_info do
    providers =
      [
        {"Discord", "DISCORD_CLIENT_ID"},
        {"Apple", "APPLE_WEB_CLIENT_ID"},
        {"Google", "GOOGLE_CLIENT_ID"},
        {"Facebook", "FACEBOOK_CLIENT_ID"},
        {"Steam", "STEAM_API_KEY"}
      ]
      |> Enum.filter(fn {_name, env} -> System.get_env(env) not in [nil, ""] end)
      |> Enum.map(fn {name, _} -> name end)

    if providers == [] do
      "OAuth: none configured"
    else
      "OAuth: #{Enum.join(providers, ", ")}"
    end
  end

  defp clustering_info do
    query = Application.get_env(:game_server_web, :dns_cluster_query)

    if query && query != :ignore do
      "Clustering: DNS (#{query})"
    else
      node = Node.self()

      if node == :nonode@nohost do
        "Clustering: standalone (no distribution)"
      else
        "Clustering: node #{node}"
      end
    end
  end

  defp sentry_info do
    sentry_config = Application.get_env(:sentry, :dsn)

    if sentry_config do
      "Sentry: enabled"
    else
      "Sentry: disabled"
    end
  end

  alias GameServer.Hooks.PluginManager

  defp plugins_info do
    plugins = PluginManager.list()
    count = length(plugins)
    names = Enum.map(plugins, fn p -> p.name end)

    if count == 0 do
      "Plugins: none loaded"
    else
      "Plugins: #{count} loaded (#{Enum.join(names, ", ")})"
    end
  end

  defp channels_info do
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

    "Channels: #{length(channel_mods)} (#{Enum.map_join(channel_mods, ", ", &inspect/1)})"
  end

  defp endpoint_info do
    endpoint_config = Application.get_env(:game_server_web, GameServerWeb.Endpoint, [])
    url_config = endpoint_config[:url] || []
    host = url_config[:host] || "localhost"
    port = endpoint_config[:http][:port] || 4000
    "Endpoint: #{host}:#{port}"
  end
end
