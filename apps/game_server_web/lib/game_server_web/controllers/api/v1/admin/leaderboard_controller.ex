defmodule GameServerWeb.Api.V1.Admin.LeaderboardController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.Leaderboards
  alias OpenApiSpex.Schema

  tags(["Admin Leaderboards"])

  @error_schema %Schema{type: :object, properties: %{error: %Schema{type: :string}}}

  @leaderboard_schema %Schema{
    type: :object,
    properties: %{
      id: %Schema{type: :integer},
      slug: %Schema{type: :string},
      title: %Schema{type: :string},
      description: %Schema{type: :string, nullable: true},
      sort_order: %Schema{type: :string, enum: ["desc", "asc"]},
      operator: %Schema{type: :string, enum: ["set", "best", "incr", "decr"]},
      starts_at: %Schema{type: :string, format: "date-time", nullable: true},
      ends_at: %Schema{type: :string, format: "date-time", nullable: true},
      metadata: %Schema{type: :object},
      inserted_at: %Schema{type: :string, format: "date-time"},
      updated_at: %Schema{type: :string, format: "date-time"}
    }
  }

  operation(:create,
    operation_id: "admin_create_leaderboard",
    summary: "Create leaderboard (admin)",
    security: [%{"authorization" => []}],
    request_body: {
      "Leaderboard",
      "application/json",
      %Schema{
        type: :object,
        properties: %{
          slug: %Schema{type: :string},
          title: %Schema{type: :string},
          description: %Schema{type: :string},
          sort_order: %Schema{type: :string, enum: ["desc", "asc"]},
          operator: %Schema{type: :string, enum: ["set", "best", "incr", "decr"]},
          starts_at: %Schema{type: :string, format: "date-time"},
          ends_at: %Schema{type: :string, format: "date-time"},
          metadata: %Schema{type: :object}
        },
        required: [:slug, :title]
      }
    },
    responses: [
      ok:
        {"Leaderboard", "application/json",
         %Schema{type: :object, properties: %{data: @leaderboard_schema}}},
      unauthorized: {"Not authenticated", "application/json", @error_schema},
      forbidden: {"Admin required", "application/json", @error_schema},
      unprocessable_entity: {"Validation failed", "application/json", %Schema{type: :object}}
    ]
  )

  def create(conn, params) do
    case Leaderboards.create_leaderboard(params) do
      {:ok, lb} ->
        json(conn, %{data: lb})

      {:error, %Ecto.Changeset{} = cs} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "validation_failed", errors: Ecto.Changeset.traverse_errors(cs, & &1)})
    end
  end

  operation(:update,
    operation_id: "admin_update_leaderboard",
    summary: "Update leaderboard (admin)",
    security: [%{"authorization" => []}],
    parameters: [
      id: [in: :path, schema: %Schema{type: :integer}, required: true]
    ],
    request_body: {
      "Leaderboard patch",
      "application/json",
      %Schema{
        type: :object,
        properties: %{
          title: %Schema{type: :string},
          description: %Schema{type: :string},
          starts_at: %Schema{type: :string, format: "date-time"},
          ends_at: %Schema{type: :string, format: "date-time"},
          metadata: %Schema{type: :object}
        }
      }
    },
    responses: [
      ok:
        {"Leaderboard", "application/json",
         %Schema{type: :object, properties: %{data: @leaderboard_schema}}},
      unauthorized: {"Not authenticated", "application/json", @error_schema},
      forbidden: {"Admin required", "application/json", @error_schema},
      not_found: {"Not found", "application/json", @error_schema},
      unprocessable_entity: {"Validation failed", "application/json", %Schema{type: :object}}
    ]
  )

  def update(conn, %{"id" => id} = params) do
    id = String.to_integer(to_string(id))

    case Leaderboards.get_leaderboard(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})

      leaderboard ->
        attrs = Map.delete(params, "id")

        case Leaderboards.update_leaderboard(leaderboard, attrs) do
          {:ok, lb} ->
            json(conn, %{data: lb})

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

  operation(:end_leaderboard,
    operation_id: "admin_end_leaderboard",
    summary: "End leaderboard (admin)",
    security: [%{"authorization" => []}],
    parameters: [
      id: [in: :path, schema: %Schema{type: :integer}, required: true]
    ],
    responses: [
      ok:
        {"Leaderboard", "application/json",
         %Schema{type: :object, properties: %{data: @leaderboard_schema}}},
      unauthorized: {"Not authenticated", "application/json", @error_schema},
      forbidden: {"Admin required", "application/json", @error_schema},
      not_found: {"Not found", "application/json", @error_schema},
      unprocessable_entity: {"Validation failed", "application/json", %Schema{type: :object}}
    ]
  )

  def end_leaderboard(conn, %{"id" => id}) do
    id = String.to_integer(to_string(id))

    case Leaderboards.end_leaderboard(id) do
      {:ok, lb} ->
        json(conn, %{data: lb})

      {:error, :not_found} ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})

      {:error, %Ecto.Changeset{} = cs} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "validation_failed", errors: Ecto.Changeset.traverse_errors(cs, & &1)})
    end
  end

  operation(:delete,
    operation_id: "admin_delete_leaderboard",
    summary: "Delete leaderboard (admin)",
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

    case Leaderboards.get_leaderboard(id) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})

      leaderboard ->
        case Leaderboards.delete_leaderboard(leaderboard) do
          {:ok, _lb} ->
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
end
