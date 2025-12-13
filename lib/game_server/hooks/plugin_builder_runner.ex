defmodule GameServer.Hooks.PluginBuilderRunner do
  @moduledoc """
  Runs plugin builds in the background on startup so bundles exist before the plugin loader runs.
  """

  use GenServer

  require Logger

  alias GameServer.Hooks.{PluginBuilder, PluginManager}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    if PluginBuilder.enabled?() do
      Logger.info("PluginBuilderRunner: scheduling plugin builds")
      Process.send_after(self(), :run_builds, 0)
    else
      Logger.info("PluginBuilderRunner: disabled")
    end

    {:ok, %{running?: false}}
  end

  @impl true
  def handle_info(:run_builds, state) do
    Task.start(fn ->
      try do
        execute_builds()
      rescue
        error ->
          stack = __STACKTRACE__

          Logger.error(
            "PluginBuilderRunner crashed: #{inspect(error)}\n#{Exception.format(:error, error, stack)}"
          )
      end
    end)

    {:noreply, %{state | running?: true}}
  end

  defp execute_builds do
    case PluginBuilder.sources_dir() do
      nil ->
        Logger.warning("PluginBuilderRunner: plugin sources directory is unset, skipping builds")

      dir ->
        Logger.info("PluginBuilderRunner: building plugins from #{dir}")

        PluginBuilder.list_buildable_plugins()
        |> Enum.each(&build_plugin/1)

        PluginManager.reload()
    end
  end

  defp build_plugin(name) do
    Logger.info("PluginBuilderRunner: building #{name}")

    case PluginBuilder.build(name) do
      {:ok, result} ->
        Logger.info(
          "PluginBuilderRunner: built #{name} (steps=#{Enum.map_join(result.steps, ",", & &1.cmd)})"
        )

      {:error, reason} ->
        Logger.warning("PluginBuilderRunner: build for #{name} failed: #{inspect(reason)}")
    end
  end
end
