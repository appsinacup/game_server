defmodule GameServerWeb.Api.V1.Admin.GroupController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.Groups
  alias GameServer.Groups.Group
  alias GameServer.Repo
  alias OpenApiSpex.Schema

  tags(["Admin – Groups"])

  @error_schema %Schema{
    type: :object,
    properties: %{error: %Schema{type: :string}}
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

  @group_schema %Schema{
    type: :object,
    properties: %{
      id: %Schema{type: :integer},
      name: %Schema{type: :string},
      title: %Schema{type: :string},
      description: %Schema{type: :string, nullable: true},
      type: %Schema{type: :string},
      max_members: %Schema{type: :integer},
      metadata: %Schema{type: :object},
      creator_id: %Schema{type: :integer, nullable: true},
      member_count: %Schema{type: :integer},
      inserted_at: %Schema{type: :string, format: :"date-time"},
      updated_at: %Schema{type: :string, format: :"date-time"}
    }
  }

  operation(:index,
    operation_id: "admin_list_groups",
    summary: "List all groups (admin)",
    description: "List all groups including hidden. Supports filters.",
    security: [%{"authorization" => []}],
    parameters: [
      title: [in: :query, schema: %Schema{type: :string}],
      name: [in: :query, schema: %Schema{type: :string}],
      type: [
        in: :query,
        schema: %Schema{type: :string, enum: ["public", "private", "hidden"]}
      ],
      min_members: [in: :query, schema: %Schema{type: :integer}],
      max_members: [in: :query, schema: %Schema{type: :integer}],
      sort_by: [
        in: :query,
        schema: %Schema{
          type: :string,
          enum: [
            "updated_at",
            "updated_at_asc",
            "inserted_at",
            "inserted_at_asc",
            "name",
            "name_desc",
            "max_members",
            "max_members_asc"
          ]
        }
      ],
      page: [in: :query, schema: %Schema{type: :integer}],
      page_size: [in: :query, schema: %Schema{type: :integer}]
    ],
    responses: [
      ok:
        {"Groups list", "application/json",
         %Schema{
           type: :object,
           properties: %{data: %Schema{type: :array, items: @group_schema}, meta: @meta_schema}
         }}
    ]
  )

  operation(:update,
    operation_id: "admin_update_group",
    summary: "Update a group (admin)",
    description: "Admin-level group update. No membership check.",
    security: [%{"authorization" => []}],
    parameters: [
      id: [in: :path, schema: %Schema{type: :integer}, required: true]
    ],
    request_body: {
      "Update parameters",
      "application/json",
      %Schema{
        type: :object,
        properties: %{
          title: %Schema{type: :string},
          description: %Schema{type: :string},
          type: %Schema{type: :string},
          max_members: %Schema{type: :integer},
          metadata: %Schema{type: :object}
        }
      }
    },
    responses: [
      ok: {"Updated", "application/json", @group_schema},
      not_found: {"Not found", "application/json", @error_schema},
      unprocessable_entity: {"Validation error", "application/json", @error_schema}
    ]
  )

  operation(:delete,
    operation_id: "admin_delete_group",
    summary: "Delete a group (admin)",
    description: "Admin-level group deletion.",
    security: [%{"authorization" => []}],
    parameters: [
      id: [in: :path, schema: %Schema{type: :integer}, required: true]
    ],
    responses: [
      ok: {"Deleted", "application/json", %Schema{type: :object}},
      not_found: {"Not found", "application/json", @error_schema}
    ]
  )

  # ---------------------------------------------------------------------------
  # Actions
  # ---------------------------------------------------------------------------

  def index(conn, params) do
    filters =
      %{}
      |> maybe_put(:title, params)
      |> maybe_put(:name, params)
      |> maybe_put(:type, params)
      |> maybe_put(:min_members, params)
      |> maybe_put(:max_members, params)

    {page, page_size} = parse_page_params(params)
    sort_by = Map.get(params, "sort_by")

    groups =
      Groups.list_all_groups(filters,
        page: page,
        page_size: page_size,
        sort_by: sort_by
      )

    serialized = Enum.map(groups, &serialize_group/1)
    count = length(serialized)
    total_count = Groups.count_all_groups(filters)

    json(conn, %{
      data: serialized,
      meta: GameServerWeb.Pagination.meta(page, page_size, count, total_count)
    })
  end

  def update(conn, %{"id" => id} = params) do
    case parse_id(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})

      group_id ->
        group = Groups.get_group(group_id)

        if is_nil(group) do
          conn |> put_status(:not_found) |> json(%{error: "not_found"})
        else
          attrs = Map.drop(params, ["id"])

          case group |> Group.changeset(attrs) |> Repo.update() do
            {:ok, updated} ->
              _ = Groups.invalidate_group_cache_public(updated.id)
              json(conn, serialize_group(updated))

            {:error, changeset} ->
              conn
              |> put_status(:unprocessable_entity)
              |> json(%{
                error: Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
              })
          end
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case parse_id(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})

      group_id ->
        case Groups.admin_delete_group(group_id) do
          {:ok, _} -> json(conn, %{})
          {:error, _} -> conn |> put_status(:not_found) |> json(%{error: "not_found"})
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp serialize_group(group) do
    member_count = Groups.count_group_members(group.id)

    %{
      id: group.id,
      name: group.name,
      title: group.title,
      description: group.description,
      type: group.type,
      max_members: group.max_members,
      metadata: group.metadata || %{},
      creator_id: group.creator_id,
      member_count: member_count,
      inserted_at: group.inserted_at,
      updated_at: group.updated_at
    }
  end

  defp parse_id(nil), do: nil
  defp parse_id(id) when is_integer(id), do: id

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {i, ""} -> i
      _ -> nil
    end
  end

  defp parse_page_params(params) do
    page =
      case params["page"] || params[:page] do
        p when is_binary(p) -> String.to_integer(p)
        p when is_integer(p) -> p
        _ -> 1
      end

    page_size =
      case params["page_size"] || params[:page_size] do
        p when is_binary(p) -> String.to_integer(p)
        p when is_integer(p) -> p
        _ -> 25
      end

    {page, page_size}
  end

  defp maybe_put(filters, key, params) do
    string_key = Atom.to_string(key)

    case Map.get(params, string_key) || Map.get(params, key) do
      nil -> filters
      "" -> filters
      v -> Map.put(filters, key, v)
    end
  end
end
