defmodule GameServerWeb.Api.V1.Admin.KvEntryController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.KV
  alias GameServerWeb.Pagination
  alias OpenApiSpex.Schema

  tags(["Admin KV"])

  @error_schema %Schema{type: :object, properties: %{error: %Schema{type: :string}}}

  @kv_entry_schema %Schema{
    type: :object,
    properties: %{
      id: %Schema{type: :integer},
      key: %Schema{type: :string},
      user_id: %Schema{type: :integer, nullable: true},
      value: %Schema{type: :object},
      metadata: %Schema{type: :object},
      inserted_at: %Schema{type: :string, format: "date-time"},
      updated_at: %Schema{type: :string, format: "date-time"}
    }
  }

  @meta_schema %Schema{
    type: :object,
    properties: %{
      page: %Schema{type: :integer},
      page_size: %Schema{type: :integer},
      count: %Schema{type: :integer},
      total_count: %Schema{type: :integer},
      total_pages: %Schema{type: :integer},
      has_more: %Schema{type: :boolean}
    }
  }

  operation(:index,
    operation_id: "admin_list_kv_entries",
    summary: "List KV entries (admin)",
    security: [%{"authorization" => []}],
    parameters: [
      page: [in: :query, schema: %Schema{type: :integer}, required: false],
      page_size: [in: :query, schema: %Schema{type: :integer}, required: false],
      key: [in: :query, schema: %Schema{type: :string}, required: false],
      user_id: [in: :query, schema: %Schema{type: :integer}, required: false],
      global_only: [
        in: :query,
        schema: %Schema{type: :string, enum: ["true", "false"]},
        required: false
      ]
    ],
    responses: [
      ok:
        {"KV entries (paginated)", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Schema{type: :array, items: @kv_entry_schema},
             meta: @meta_schema
           }
         }},
      unauthorized: {"Not authenticated", "application/json", @error_schema},
      forbidden: {"Admin required", "application/json", @error_schema}
    ]
  )

  def index(conn, params) do
    {page, page_size} = parse_page_params(params)

    opts =
      []
      |> Keyword.put(:page, page)
      |> Keyword.put(:page_size, page_size)
      |> maybe_put_int_opt(:user_id, params["user_id"])
      |> maybe_put_string_opt(:key, params["key"])
      |> maybe_put_bool_opt(:global_only, params["global_only"])

    entries = KV.list_entries(opts)
    total_count = KV.count_entries(Keyword.drop(opts, [:page, :page_size]))

    json(conn, %{
      data: Enum.map(entries, &serialize_entry/1),
      meta: Pagination.meta(page, page_size, length(entries), total_count)
    })
  end

  operation(:create,
    operation_id: "admin_create_kv_entry",
    summary: "Create KV entry (admin)",
    security: [%{"authorization" => []}],
    request_body: {
      "KV entry",
      "application/json",
      %Schema{
        type: :object,
        properties: %{
          key: %Schema{type: :string},
          user_id: %Schema{type: :integer, nullable: true},
          value: %Schema{type: :object},
          metadata: %Schema{type: :object}
        },
        required: [:key, :value]
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

  def create(conn, params) do
    attrs = normalize_entry_attrs(params)

    case KV.create_entry(attrs) do
      {:ok, entry} ->
        json(conn, %{data: serialize_entry(entry)})

      {:error, %Ecto.Changeset{} = cs} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "validation_failed", errors: Ecto.Changeset.traverse_errors(cs, & &1)})
    end
  end

  operation(:update,
    operation_id: "admin_update_kv_entry",
    summary: "Update KV entry by id (admin)",
    security: [%{"authorization" => []}],
    parameters: [
      id: [in: :path, schema: %Schema{type: :integer}, required: true]
    ],
    request_body: {
      "KV entry patch",
      "application/json",
      %Schema{
        type: :object,
        properties: %{
          key: %Schema{type: :string},
          user_id: %Schema{type: :integer, nullable: true},
          value: %Schema{type: :object},
          metadata: %Schema{type: :object}
        }
      }
    },
    responses: [
      ok:
        {"KV entry", "application/json",
         %Schema{type: :object, properties: %{data: @kv_entry_schema}}},
      unauthorized: {"Not authenticated", "application/json", @error_schema},
      forbidden: {"Admin required", "application/json", @error_schema},
      not_found: {"Not found", "application/json", @error_schema},
      unprocessable_entity: {"Validation failed", "application/json", %Schema{type: :object}}
    ]
  )

  def update(conn, %{"id" => id} = params) do
    id = String.to_integer(to_string(id))
    attrs = normalize_entry_attrs(Map.delete(params, "id"))

    case KV.update_entry(id, attrs) do
      {:ok, entry} ->
        json(conn, %{data: serialize_entry(entry)})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})

      {:error, %Ecto.Changeset{} = cs} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "validation_failed", errors: Ecto.Changeset.traverse_errors(cs, & &1)})
    end
  end

  operation(:delete,
    operation_id: "admin_delete_kv_entry",
    summary: "Delete KV entry by id (admin)",
    security: [%{"authorization" => []}],
    parameters: [
      id: [in: :path, schema: %Schema{type: :integer}, required: true]
    ],
    responses: [
      ok: {"Deleted", "application/json", %Schema{type: :object}},
      unauthorized: {"Not authenticated", "application/json", @error_schema},
      forbidden: {"Admin required", "application/json", @error_schema}
    ]
  )

  def delete(conn, %{"id" => id}) do
    id = String.to_integer(to_string(id))
    :ok = KV.delete_entry(id)
    json(conn, %{})
  end

  defp serialize_entry(entry) do
    %{
      id: entry.id,
      key: entry.key,
      user_id: entry.user_id,
      value: entry.value,
      metadata: entry.metadata,
      inserted_at: entry.inserted_at,
      updated_at: entry.updated_at
    }
  end

  defp parse_page_params(params) do
    page = params["page"] || params[:page]
    page_size = params["page_size"] || params[:page_size]

    page =
      case page do
        p when is_binary(p) -> String.to_integer(p)
        p when is_integer(p) -> p
        _ -> 1
      end

    page_size =
      case page_size do
        p when is_binary(p) -> String.to_integer(p)
        p when is_integer(p) -> p
        _ -> 25
      end

    {page, page_size}
  end

  defp maybe_put_int_opt(opts, _key, nil), do: opts

  defp maybe_put_int_opt(opts, key, v) when is_binary(v) do
    case Integer.parse(v) do
      {i, _} -> Keyword.put(opts, key, i)
      _ -> opts
    end
  end

  defp maybe_put_int_opt(opts, key, v) when is_integer(v), do: Keyword.put(opts, key, v)
  defp maybe_put_int_opt(opts, _key, _v), do: opts

  defp maybe_put_string_opt(opts, _key, nil), do: opts
  defp maybe_put_string_opt(opts, _key, ""), do: opts
  defp maybe_put_string_opt(opts, key, v) when is_binary(v), do: Keyword.put(opts, key, v)
  defp maybe_put_string_opt(opts, _key, _v), do: opts

  defp maybe_put_bool_opt(opts, _key, nil), do: opts
  defp maybe_put_bool_opt(opts, key, true), do: Keyword.put(opts, key, true)
  defp maybe_put_bool_opt(opts, key, false), do: Keyword.put(opts, key, false)

  defp maybe_put_bool_opt(opts, key, v) when is_binary(v) do
    case String.downcase(v) do
      "true" -> Keyword.put(opts, key, true)
      "false" -> Keyword.put(opts, key, false)
      _ -> opts
    end
  end

  defp maybe_put_bool_opt(opts, _key, _v), do: opts

  defp normalize_entry_attrs(params) when is_map(params) do
    params
    |> Map.take(["key", "user_id", "value", "metadata", :key, :user_id, :value, :metadata])
    |> normalize_user_id()
  end

  defp normalize_user_id(attrs) do
    user_id = Map.get(attrs, "user_id") || Map.get(attrs, :user_id)

    normalized =
      case user_id do
        nil ->
          :no_change

        "" ->
          nil

        v when is_integer(v) ->
          v

        v when is_binary(v) ->
          case Integer.parse(v) do
            {i, _} -> i
            _ -> :no_change
          end

        _ ->
          :no_change
      end

    cond do
      normalized == :no_change -> attrs
      Map.has_key?(attrs, "user_id") -> Map.put(attrs, "user_id", normalized)
      Map.has_key?(attrs, :user_id) -> Map.put(attrs, :user_id, normalized)
      true -> Map.put(attrs, :user_id, normalized)
    end
  end
end
