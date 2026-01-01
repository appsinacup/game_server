defmodule GameServerWeb.Api.V1.Admin.KvController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.KV
  alias OpenApiSpex.Schema

  tags(["Admin KV"])

  @error_schema %Schema{type: :object, properties: %{error: %Schema{type: :string}}}

  @kv_entry_schema %Schema{
    type: :object,
    properties: %{
      id: %Schema{type: :integer},
      key: %Schema{type: :string},
      user_id: %Schema{
        type: :integer,
        nullable: false,
        description: "Owner user id; -1 means global/unowned",
        example: -1,
        minimum: -1
      },
      data: %Schema{type: :object},
      metadata: %Schema{type: :object},
      inserted_at: %Schema{type: :string, format: "date-time"},
      updated_at: %Schema{type: :string, format: "date-time"}
    }
  }

  operation(:upsert,
    operation_id: "admin_upsert_kv",
    summary: "Upsert KV by key (admin)",
    security: [%{"authorization" => []}],
    request_body: {
      "KV upsert",
      "application/json",
      %Schema{
        type: :object,
        properties: %{
          key: %Schema{type: :string},
          user_id: %Schema{type: :integer, nullable: true},
          data: %Schema{type: :object},
          metadata: %Schema{type: :object}
        },
        required: [:key, :data]
      }
    },
    responses: [
      ok:
        {"KV entry", "application/json",
         %Schema{type: :object, properties: %{data: @kv_entry_schema}}},
      unauthorized: {"Not authenticated", "application/json", @error_schema},
      forbidden: {"Admin required", "application/json", @error_schema},
      unprocessable_entity: {"Validation failed", "application/json", %Schema{type: :object}}
    ]
  )

  def upsert(conn, %{"key" => key} = params) do
    data = Map.get(params, "data") || Map.get(params, "value")

    if is_nil(data) do
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{error: "validation_failed", errors: %{data: ["can't be blank"]}})
    else
      metadata = Map.get(params, "metadata") || %{}

      user_id =
        case Map.get(params, "user_id") do
          nil ->
            nil

          "" ->
            nil

          v when is_integer(v) ->
            v

          v when is_binary(v) ->
            case Integer.parse(v) do
              {i, _} -> i
              _ -> nil
            end

          _ ->
            nil
        end

      case KV.put(key, data, metadata, user_id: user_id) do
        {:ok, entry} ->
          json(conn, %{data: serialize_entry(entry)})

        {:error, %Ecto.Changeset{} = cs} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: "validation_failed", errors: Ecto.Changeset.traverse_errors(cs, & &1)})
      end
    end
  end

  operation(:delete,
    operation_id: "admin_delete_kv",
    summary: "Delete KV by key (admin)",
    security: [%{"authorization" => []}],
    parameters: [
      key: [in: :query, schema: %Schema{type: :string}, required: true],
      user_id: [in: :query, schema: %Schema{type: :integer}, required: false]
    ],
    responses: [
      ok: {"Deleted", "application/json", %Schema{type: :object}},
      unauthorized: {"Not authenticated", "application/json", @error_schema},
      forbidden: {"Admin required", "application/json", @error_schema}
    ]
  )

  def delete(conn, %{"key" => key} = params) do
    user_id =
      case Map.get(params, "user_id") do
        nil ->
          nil

        "" ->
          nil

        v when is_integer(v) ->
          v

        v when is_binary(v) ->
          case Integer.parse(v) do
            {i, _} -> i
            _ -> nil
          end

        _ ->
          nil
      end

    :ok = KV.delete(key, user_id: user_id)
    json(conn, %{})
  end

  defp serialize_entry(entry) do
    %{
      id: entry.id,
      key: entry.key,
      user_id: entry.user_id || -1,
      data: entry.value,
      metadata: entry.metadata,
      inserted_at: entry.inserted_at,
      updated_at: entry.updated_at
    }
  end
end
