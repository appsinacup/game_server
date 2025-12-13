defmodule GameServer.Hooks.PluginBuilder do
  @moduledoc """
  Builds an OTP plugin bundle from plugin source code on disk.

  This is intended for admin-only workflows in development/self-hosted setups.
  It runs `mix` commands on the server host/container.
  """

  @type step_result :: %{
          cmd: String.t(),
          status: non_neg_integer(),
          output: String.t()
        }

  @type build_result :: %{
          ok?: boolean(),
          plugin: String.t(),
          source_dir: String.t(),
          started_at: DateTime.t(),
          finished_at: DateTime.t(),
          steps: [step_result()]
        }

  @spec enabled?() :: boolean()
  def enabled? do
    true
  end

  @spec sources_dir() :: String.t()
  def sources_dir do
    System.get_env("GAME_SERVER_PLUGINS_DIR")
  end

  @spec list_buildable_plugins() :: [String.t()]
  def list_buildable_plugins do
    dir = sources_dir()

    if dir && File.dir?(dir) do
      dir
      |> File.ls!()
      |> Enum.map(&Path.join(dir, &1))
      |> Enum.filter(fn p ->
        File.dir?(p) and File.exists?(Path.join(p, "mix.exs"))
      end)
      |> Enum.map(&Path.basename/1)
      |> Enum.sort()
    else
      []
    end
  end

  @spec build(String.t()) :: {:ok, build_result()} | {:error, term()}
  def build(plugin_name) when is_binary(plugin_name) do
    source_dir = sources_dir()
    plugin_dir = Path.join(source_dir, plugin_name)

    unless File.exists?(Path.join(plugin_dir, "mix.exs")) do
      return_error({:missing_mix_project, plugin_dir})
    end

    started_at = DateTime.utc_now()

    env =
      case System.get_env("MIX_ENV") do
        nil -> []
        mix_env -> [{"MIX_ENV", mix_env}]
      end

    steps =
      [
        {"mix deps.get", ["deps.get"]},
        {"mix compile", ["compile"]},
        {"mix plugin.bundle", ["plugin.bundle"]}
      ]
      |> Enum.map(fn {label, argv} ->
        {output, status} =
          System.cmd("mix", argv,
            cd: plugin_dir,
            env: env,
            stderr_to_stdout: true
          )

        %{cmd: label, status: status, output: output}
      end)

    finished_at = DateTime.utc_now()

    ok? = Enum.all?(steps, &(&1.status == 0))

    {:ok,
     %{
       ok?: ok?,
       plugin: plugin_name,
       source_dir: source_dir,
       started_at: started_at,
       finished_at: finished_at,
       steps: steps
     }}
  rescue
    e ->
      {:error, {:build_failed, Exception.message(e)}}
  end

  defp return_error(reason), do: {:error, reason}
end
