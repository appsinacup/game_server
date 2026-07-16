defmodule GameServer.Hooks.KvSchemas do
  @moduledoc """
  Registry of game-defined protobuf schemas for KV entry data.

  KV keys are open-ended, so unlike metadata entities there is no naming
  convention — a plugin registers schemas explicitly by exporting
  `kv_schemas/0`, mapping exact keys or `*`-suffixed prefixes to protobuf
  message modules:

      def kv_schemas do
        %{
          "loadout" => MyGame.V1.Loadout,
          "match:*" => MyGame.V1.MatchState
        }
      end

  On protobuf sockets, `kv_updated` data for a matching key is pushed as
  compact binary (`data_pb`) instead of JSON bytes; storage and REST stay
  JSON, and data that does not fit the schema falls back to JSON so it is
  never dropped. Exact keys win over prefixes; the longest prefix wins.
  KV entry metadata always stays JSON.

  The KV keyspace is **global**: when two plugins register the same key or
  prefix pattern, the first plugin in name order wins and the losing
  registration is logged.
  """

  require Logger

  @pt_key {__MODULE__, :schemas}

  @doc "Returns the registered schema module for a KV key, or nil."
  @spec module_for(String.t()) :: module() | nil
  def module_for(key) when is_binary(key) do
    %{exact: exact, prefixes: prefixes} = all()

    case Map.fetch(exact, key) do
      {:ok, mod} ->
        mod

      :error ->
        Enum.find_value(prefixes, fn {prefix, mod} ->
          if String.starts_with?(key, prefix), do: mod
        end)
    end
  end

  @doc "Returns the full registry (for the admin overview)."
  @spec all() :: %{exact: %{String.t() => module()}, prefixes: [{String.t(), module()}]}
  def all, do: :persistent_term.get(@pt_key, %{exact: %{}, prefixes: []})

  @doc "Rebuilds the registry from the loaded plugin list."
  @spec refresh([struct()]) :: :ok
  def refresh(plugins) do
    # Plugins arrive sorted by name; the first registration of a pattern
    # wins and later duplicates are logged.
    {exact, prefixes, _seen} =
      plugins
      |> Enum.filter(&(&1.status == :ok))
      |> Enum.flat_map(fn plugin ->
        Enum.map(plugin_schemas(plugin), fn {pattern, mod} -> {pattern, mod, plugin.name} end)
      end)
      |> Enum.reduce({%{}, [], MapSet.new()}, fn {pattern, mod, plugin},
                                                 {exact, prefixes, seen} ->
        cond do
          MapSet.member?(seen, pattern) ->
            Logger.warning(
              "kv schema #{inspect(mod)} for #{inspect(pattern)} from plugin=#{plugin} " <>
                "ignored (pattern already registered)"
            )

            {exact, prefixes, seen}

          String.ends_with?(pattern, "*") ->
            prefix = String.slice(pattern, 0..-2//1)
            {exact, [{prefix, mod} | prefixes], MapSet.put(seen, pattern)}

          true ->
            {Map.put(exact, pattern, mod), prefixes, MapSet.put(seen, pattern)}
        end
      end)

    # Longest prefix wins on overlap.
    prefixes = Enum.sort_by(prefixes, fn {prefix, _} -> -String.length(prefix) end)

    :persistent_term.put(@pt_key, %{exact: exact, prefixes: prefixes})

    if exact != %{} or prefixes != [] do
      Logger.info(
        "kv schemas registered: #{inspect(Map.keys(exact) ++ Enum.map(prefixes, &(elem(&1, 0) <> "*")))}"
      )
    end

    :ok
  end

  defp plugin_schemas(%{hooks_module: mod} = plugin) when is_atom(mod) and not is_nil(mod) do
    if Code.ensure_loaded?(mod) and function_exported?(mod, :kv_schemas, 0) do
      for {pattern, schema} <- mod.kv_schemas(), valid?(pattern, schema, plugin) do
        {pattern, schema}
      end
    else
      []
    end
  end

  defp plugin_schemas(_plugin), do: []

  defp valid?(pattern, schema, plugin) do
    cond do
      not is_binary(pattern) or pattern == "" or pattern == "*" ->
        Logger.warning("plugin=#{plugin.name} kv_schemas: invalid pattern #{inspect(pattern)}")
        false

      not message_module?(schema) ->
        Logger.warning(
          "plugin=#{plugin.name} kv_schemas: #{inspect(schema)} is not a protobuf message module"
        )

        false

      true ->
        true
    end
  end

  defp message_module?(mod) do
    is_atom(mod) and Code.ensure_loaded?(mod) and
      function_exported?(mod, :__message_props__, 0) and
      function_exported?(mod, :encode, 1)
  end
end
