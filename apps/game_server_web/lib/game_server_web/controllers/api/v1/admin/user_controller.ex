defmodule GameServerWeb.Api.V1.Admin.UserController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.Accounts
  alias OpenApiSpex.Schema

  tags(["Admin Users"])

  @error_schema %Schema{type: :object, properties: %{error: %Schema{type: :string}}}

  @user_schema %Schema{
    type: :object,
    properties: %{
      id: %Schema{type: :integer},
      email: %Schema{type: :string, nullable: true},
      display_name: %Schema{type: :string, nullable: true},
      is_admin: %Schema{type: :boolean},
      metadata: %Schema{type: :object},
      lobby_id: %Schema{type: :integer, nullable: true},
      is_online: %Schema{type: :boolean},
      last_seen_at: %Schema{type: :string, format: "date-time", nullable: true},
      inserted_at: %Schema{type: :string, format: "date-time"},
      updated_at: %Schema{type: :string, format: "date-time"}
    }
  }

  operation(:update,
    operation_id: "admin_update_user",
    summary: "Update user (admin)",
    security: [%{"authorization" => []}],
    parameters: [
      id: [in: :path, schema: %Schema{type: :integer}, required: true]
    ],
    request_body: {
      "User patch",
      "application/json",
      %Schema{
        type: :object,
        properties: %{
          is_admin: %Schema{type: :boolean},
          display_name: %Schema{type: :string},
          metadata: %Schema{type: :object}
        }
      }
    },
    responses: [
      ok: {"User", "application/json", %Schema{type: :object, properties: %{data: @user_schema}}},
      unauthorized: {"Not authenticated", "application/json", @error_schema},
      forbidden: {"Admin required", "application/json", @error_schema},
      not_found: {"Not found", "application/json", @error_schema},
      unprocessable_entity: {"Validation failed", "application/json", %Schema{type: :object}}
    ]
  )

  def update(conn, %{"id" => id} = params) do
    id = String.to_integer(to_string(id))

    case Accounts.get_user(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})

      user ->
        attrs =
          params
          |> Map.delete("id")
          |> ensure_is_admin_present(user)

        case Accounts.update_user(user, attrs) do
          {:ok, updated} ->
            json(conn, %{data: serialize_user(updated)})

          {:error, %Ecto.Changeset{} = cs} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{
              error: "validation_failed",
              errors: Ecto.Changeset.traverse_errors(cs, & &1)
            })
        end
    end
  end

  operation(:delete,
    operation_id: "admin_delete_user",
    summary: "Delete user (admin)",
    security: [%{"authorization" => []}],
    parameters: [
      id: [in: :path, schema: %Schema{type: :integer}, required: true]
    ],
    responses: [
      ok: {"Deleted", "application/json", %Schema{type: :object}},
      unauthorized: {"Not authenticated", "application/json", @error_schema},
      forbidden: {"Admin required", "application/json", @error_schema},
      not_found: {"Not found", "application/json", @error_schema}
    ]
  )

  def delete(conn, %{"id" => id}) do
    id = String.to_integer(to_string(id))

    case Accounts.get_user(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})

      user ->
        case Accounts.delete_user(user) do
          {:ok, _} ->
            json(conn, %{})

          {:error, %Ecto.Changeset{} = cs} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{
              error: "validation_failed",
              errors: Ecto.Changeset.traverse_errors(cs, & &1)
            })
        end
    end
  end

  defp ensure_is_admin_present(attrs, user) when is_map(attrs) do
    cond do
      Map.has_key?(attrs, :is_admin) -> attrs
      Map.has_key?(attrs, "is_admin") -> attrs
      true -> Map.put(attrs, :is_admin, user.is_admin)
    end
  end

  defp serialize_user(user) do
    %{
      id: user.id,
      email: user.email,
      display_name: user.display_name,
      is_admin: user.is_admin,
      metadata: user.metadata || %{},
      lobby_id: user.lobby_id,
      is_online: user.is_online || false,
      last_seen_at: user.last_seen_at,
      inserted_at: user.inserted_at,
      updated_at: user.updated_at
    }
  end
end
