defmodule GameServerWeb.Api.V1.HookController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.Hooks.DynamicRpcs
  alias GameServer.Hooks.PluginManager

  operation(:index,
    operation_id: "list_hooks",
    summary: "List available hook functions",
    tags: ["Hooks"],
    security: [%{"authorization" => []}],
    responses: [
      ok: {"OK", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def index(conn, _params) do
    static_functions =
      PluginManager.hook_modules()
      |> Enum.flat_map(fn {plugin_name, mod} ->
        GameServer.Hooks.exported_functions(mod)
        |> Enum.map(&Map.merge(&1, %{plugin: plugin_name, dynamic: false}))
      end)

    static_keys =
      static_functions
      |> Enum.map(&{Map.get(&1, :plugin), Map.get(&1, :name)})
      |> MapSet.new()

    dynamic_functions =
      DynamicRpcs.list_all()
      |> Enum.flat_map(fn {plugin_name, exports} ->
        Enum.map(exports, fn export ->
          args = Map.get(export.meta || %{}, :args) || Map.get(export.meta || %{}, "args")
          args_list = List.wrap(args)

          arg_names =
            Enum.map(args_list, fn a ->
              Map.get(a, :name) || Map.get(a, "name") || "arg"
            end)

          arity = length(arg_names)

          doc =
            Map.get(export.meta || %{}, :description) ||
              Map.get(export.meta || %{}, "description")

          signature = to_string(export.hook) <> "(" <> Enum.join(arg_names, ", ") <> ")"

          %{
            plugin: plugin_name,
            name: export.hook,
            dynamic: true,
            meta: export.meta,
            arities: [arity],
            signatures: [
              %{
                arity: arity,
                signature: signature,
                doc: doc,
                example_args: Jason.encode!(arg_names)
              }
            ]
          }
        end)
      end)
      |> Enum.reject(fn f -> MapSet.member?(static_keys, {f.plugin, f.name}) end)

    functions =
      (static_functions ++ dynamic_functions)
      |> Enum.sort_by(&{&1.plugin, &1.name})

    json(conn, %{data: functions})
  end

  @json_schema %OpenApiSpex.Schema{
    description: "JSON object with arbitrary properties",
    type: :object,
    additionalProperties: true
  }

  @call_ok_schema %OpenApiSpex.Schema{
    type: :object,
    properties: %{
      data: @json_schema
    }
  }

  operation(:invoke,
    operation_id: "call_hook",
    summary: "Invoke a hook function",
    tags: ["Hooks"],
    security: [%{"authorization" => []}],
    request_body:
      {"Call hook", "application/json",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           plugin: %OpenApiSpex.Schema{type: :string},
           fn: %OpenApiSpex.Schema{type: :string},
           args: %OpenApiSpex.Schema{type: :array, items: @json_schema}
         },
         required: [:plugin, :fn]
       }},
    responses: [
      ok: {"OK", "application/json", @call_ok_schema},
      bad_request:
        {"Bad Request", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{error: %OpenApiSpex.Schema{type: :string}}
         }},
      unauthorized:
        {"Unauthorized", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{error: %OpenApiSpex.Schema{type: :string}}
         }}
    ]
  )

  def invoke(conn, %{"plugin" => plugin, "fn" => fn_name} = params)
      when is_binary(plugin) and is_binary(fn_name) do
    user = conn.assigns.current_scope.user
    args = Map.get(params, "args", [])

    args = if is_list(args), do: args, else: [args]

    cond do
      String.contains?(fn_name, ":") ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: :legacy_fn_format_not_supported})

      reserved_hook_name?(fn_name) ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: :reserved_hook_name})

      true ->
        case PluginManager.call_rpc(plugin, fn_name, args, caller: user) do
          {:ok, res} ->
            json(conn, %{data: res})

          {:error, :not_implemented} ->
            conn |> put_status(:bad_request) |> json(%{error: :not_implemented})

          {:error, :not_found} ->
            conn |> put_status(:bad_request) |> json(%{error: :plugin_not_found})

          {:error, :missing_hooks_module} ->
            conn |> put_status(:bad_request) |> json(%{error: :missing_hooks_module})

          {:error, :timeout} ->
            conn |> put_status(:bad_request) |> json(%{error: :timeout})

          {:error, other} ->
            conn |> put_status(:bad_request) |> json(%{error: inspect(other)})
        end
    end
  end

  def invoke(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{error: :invalid_request})
  end

  defp reserved_hook_name?(fn_name) when is_binary(fn_name) do
    fn_name in [
      "after_startup",
      "before_stop",
      "after_user_register",
      "after_user_login",
      "before_lobby_create",
      "after_lobby_create",
      "before_lobby_join",
      "after_lobby_join",
      "before_group_join",
      "before_lobby_leave",
      "after_lobby_leave",
      "before_lobby_update",
      "after_lobby_update",
      "before_lobby_delete",
      "after_lobby_delete",
      "before_user_kicked",
      "after_user_kicked",
      "after_lobby_host_change",
      "on_custom_hook",
      "before_kv_get"
    ]
  end
end
