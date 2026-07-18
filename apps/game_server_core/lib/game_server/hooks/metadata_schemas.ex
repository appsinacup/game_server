defmodule GameServer.Hooks.MetadataSchemas do
  @moduledoc """
  Registry of game-defined protobuf schemas for entity metadata.

  Metadata is stored and served as JSON (database, REST API, admin UI), but
  realtime pushes on protobuf-format connections can carry it as compact
  binary when the game registers a schema. Registration is convention-based:
  when a plugin loads, its modules are scanned for protobuf messages named
  `UserMeta`, `LobbyMeta`, `GroupMeta` or `PartyMeta` (any namespace), which
  are registered for the matching entity automatically. A plugin can override
  or disable the convention by exporting `metadata_schemas/0` returning e.g.
  `%{user: MyGame.Proto.Profile, lobby: nil}`.

  Entity metadata schemas are **global** (one per deployment): unlike hook
  schemas, which are namespaced per plugin, every plugin contributes to the
  same four entity slots. On conflict the precedence is well-defined:
  explicit `metadata_schemas/0` entries beat name conventions, and within
  the same priority the first plugin in name order wins; every losing
  registration is logged. An explicit `nil` disables the entity globally
  (sticky — conventions from other plugins cannot re-add it).

  Lookups run on every push, so the registry lives in `:persistent_term`
  (refreshed by `GameServer.Hooks.PluginManager` on every plugin reload).
  """

  require Logger

  @pt_key {__MODULE__, :schemas}

  @conventional_names %{
    "UserMeta" => :user,
    "LobbyMeta" => :lobby,
    "GroupMeta" => :group,
    "PartyMeta" => :party
  }

  @entities Map.values(@conventional_names)

  @doc "Returns the registered protobuf module for an entity, or nil."
  @spec module_for(atom()) :: module() | nil
  def module_for(entity), do: Map.get(all(), entity)

  @doc "Returns the full entity -> module registry (for the admin overview)."
  @spec all() :: %{atom() => module()}
  def all, do: :persistent_term.get(@pt_key, %{})

  @doc "The entities that can carry a game metadata schema."
  @spec entities() :: [atom()]
  def entities, do: @entities

  @doc "Rebuilds the registry from the loaded plugin list."
  @spec refresh([struct()]) :: :ok
  def refresh(plugins) do
    schemas =
      plugins
      |> Enum.filter(&(&1.status == :ok))
      |> Enum.flat_map(&collect_candidates/1)
      |> resolve()

    :persistent_term.put(@pt_key, schemas)

    if schemas != %{} do
      Logger.info("metadata schemas registered: #{inspect(schemas)}")
    end

    :ok
  end

  # Candidates are collected from every plugin, then resolved per entity:
  # explicit beats convention; ties go to the first plugin in name order
  # (the plugin list arrives sorted). Losers are logged.
  defp collect_candidates(plugin) do
    conventional =
      for mod <- plugin.modules || [],
          entity =
            @conventional_names[mod |> Atom.to_string() |> String.split(".") |> List.last()],
          not is_nil(entity),
          do: %{entity: entity, schema: mod, plugin: plugin.name, priority: :convention}

    explicit =
      for {entity, schema} <- explicit_schemas(plugin) do
        %{entity: entity, schema: schema, plugin: plugin.name, priority: :explicit}
      end

    conventional ++ explicit
  end

  defp explicit_schemas(%{hooks_module: mod} = plugin) when is_atom(mod) and not is_nil(mod) do
    if Code.ensure_loaded?(mod) and function_exported?(mod, :metadata_schemas, 0) do
      for {entity, schema} <- mod.metadata_schemas() do
        unless entity in @entities do
          Logger.warning(
            "plugin=#{plugin.name} metadata_schemas: unknown entity #{inspect(entity)}"
          )
        end

        {entity, schema}
      end
      |> Enum.filter(fn {entity, _} -> entity in @entities end)
    else
      []
    end
  end

  defp explicit_schemas(_plugin), do: []

  defp resolve(candidates) do
    candidates
    |> Enum.group_by(& &1.entity)
    |> Enum.reduce(%{}, fn {entity, cands}, acc ->
      [winner | losers] = Enum.sort_by(cands, &{priority_rank(&1.priority), &1.plugin})

      for loser <- losers do
        Logger.warning(
          "#{entity} metadata schema #{inspect(loser.schema)} from plugin=#{loser.plugin} " <>
            "ignored (#{describe(winner)} wins)"
        )
      end

      cond do
        is_nil(winner.schema) ->
          # Explicit disable is sticky for the whole deployment.
          acc

        message_module?(winner.schema) ->
          Map.put(acc, entity, winner.schema)

        true ->
          Logger.warning(
            "plugin=#{winner.plugin} #{inspect(winner.schema)} is not a protobuf message module, " <>
              "ignoring for #{entity} metadata"
          )

          acc
      end
    end)
  end

  defp priority_rank(:explicit), do: 0
  defp priority_rank(:convention), do: 1

  defp describe(%{schema: nil, plugin: plugin}), do: "explicit disable from plugin=#{plugin}"
  defp describe(%{schema: schema, plugin: plugin}), do: "#{inspect(schema)} from plugin=#{plugin}"

  defp message_module?(mod) do
    is_atom(mod) and Code.ensure_loaded?(mod) and
      function_exported?(mod, :__message_props__, 0) and
      function_exported?(mod, :encode, 1)
  end
end
