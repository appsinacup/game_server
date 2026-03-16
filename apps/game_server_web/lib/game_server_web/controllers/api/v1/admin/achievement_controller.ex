defmodule GameServerWeb.Api.V1.Admin.AchievementController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.Achievements
  alias OpenApiSpex.Schema

  tags(["Admin – Achievements"])

  @error_schema %Schema{type: :object, properties: %{error: %Schema{type: :string}}}

  @achievement_schema %Schema{
    type: :object,
    properties: %{
      id: %Schema{type: :integer},
      slug: %Schema{type: :string},
      title: %Schema{type: :string},
      description: %Schema{type: :string},
      icon_url: %Schema{type: :string},
      sort_order: %Schema{type: :integer},
      hidden: %Schema{type: :boolean},
      progress_target: %Schema{type: :integer},
      metadata: %Schema{type: :object},
      inserted_at: %Schema{type: :string, format: "date-time"},
      updated_at: %Schema{type: :string, format: "date-time"}
    }
  }

  # ---------------------------------------------------------------------------
  # INDEX (admin list – includes hidden)
  # ---------------------------------------------------------------------------

  operation(:index,
    operation_id: "admin_list_achievements",
    summary: "List all achievements (admin, includes hidden)",
    security: [%{"authorization" => []}],
    parameters: [
      page: [in: :query, schema: %Schema{type: :integer}, required: false],
      page_size: [in: :query, schema: %Schema{type: :integer}, required: false]
    ],
    responses: %{
      200 =>
        {"Achievements list", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Schema{type: :array, items: @achievement_schema},
             meta: %Schema{type: :object}
           }
         }}
    }
  )

  def index(conn, params) do
    page = parse_int(params["page"], 1)
    page_size = parse_int(params["page_size"], 25)

    achievements =
      Achievements.list_achievements(page: page, page_size: page_size, include_hidden: true)

    total_count = Achievements.count_all_achievements()
    total_pages = max(ceil(total_count / page_size), 1)
    count = length(achievements)

    json(conn, %{
      data: Enum.map(achievements, &serialize/1),
      meta: %{
        page: page,
        page_size: page_size,
        count: count,
        total_count: total_count,
        total_pages: total_pages,
        has_more: count == page_size
      }
    })
  end

  # ---------------------------------------------------------------------------
  # CREATE
  # ---------------------------------------------------------------------------

  operation(:create,
    operation_id: "admin_create_achievement",
    summary: "Create achievement (admin)",
    security: [%{"authorization" => []}],
    request_body:
      {"Achievement", "application/json",
       %Schema{
         type: :object,
         properties: %{
           slug: %Schema{type: :string},
           title: %Schema{type: :string},
           description: %Schema{type: :string},
           icon_url: %Schema{type: :string},
           sort_order: %Schema{type: :integer},
           hidden: %Schema{type: :boolean},
           progress_target: %Schema{type: :integer},
           metadata: %Schema{type: :object}
         },
         required: [:slug, :title]
       }},
    responses: %{
      201 => {"Created", "application/json", @achievement_schema},
      422 => {"Validation error", "application/json", @error_schema}
    }
  )

  def create(conn, params) do
    case Achievements.create_achievement(params) do
      {:ok, achievement} ->
        conn |> put_status(:created) |> json(%{data: serialize(achievement)})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: changeset_errors(changeset)})
    end
  end

  # ---------------------------------------------------------------------------
  # UPDATE
  # ---------------------------------------------------------------------------

  operation(:update,
    operation_id: "admin_update_achievement",
    summary: "Update achievement (admin)",
    security: [%{"authorization" => []}],
    parameters: [
      id: [in: :path, schema: %Schema{type: :integer}, required: true]
    ],
    request_body:
      {"Achievement", "application/json",
       %Schema{
         type: :object,
         properties: %{
           title: %Schema{type: :string},
           description: %Schema{type: :string},
           icon_url: %Schema{type: :string},
           sort_order: %Schema{type: :integer},
           hidden: %Schema{type: :boolean},
           progress_target: %Schema{type: :integer},
           metadata: %Schema{type: :object}
         }
       }},
    responses: %{
      200 => {"Updated", "application/json", @achievement_schema},
      404 => {"Not found", "application/json", @error_schema},
      422 => {"Validation error", "application/json", @error_schema}
    }
  )

  def update(conn, %{"id" => id} = params) do
    case parse_id(id) do
      nil ->
        conn |> put_status(:bad_request) |> json(%{error: "invalid_id"})

      achievement_id ->
        case Achievements.get_achievement(achievement_id) do
          nil ->
            conn |> put_status(:not_found) |> json(%{error: "not_found"})

          achievement ->
            attrs = Map.drop(params, ["id"])

            case Achievements.update_achievement(achievement, attrs) do
              {:ok, updated} ->
                json(conn, %{data: serialize(updated)})

              {:error, %Ecto.Changeset{} = changeset} ->
                conn
                |> put_status(:unprocessable_entity)
                |> json(%{error: changeset_errors(changeset)})
            end
        end
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE
  # ---------------------------------------------------------------------------

  operation(:delete,
    operation_id: "admin_delete_achievement",
    summary: "Delete achievement (admin)",
    security: [%{"authorization" => []}],
    parameters: [
      id: [in: :path, schema: %Schema{type: :integer}, required: true]
    ],
    responses: %{
      200 => {"Deleted", "application/json", %Schema{type: :object}},
      404 => {"Not found", "application/json", @error_schema}
    }
  )

  def delete(conn, %{"id" => id}) do
    case parse_id(id) do
      nil ->
        conn |> put_status(:bad_request) |> json(%{error: "invalid_id"})

      achievement_id ->
        case Achievements.get_achievement(achievement_id) do
          nil ->
            conn |> put_status(:not_found) |> json(%{error: "not_found"})

          achievement ->
            {:ok, _} = Achievements.delete_achievement(achievement)
            json(conn, %{message: "achievement deleted"})
        end
    end
  end

  # ---------------------------------------------------------------------------
  # GRANT (unlock for user)
  # ---------------------------------------------------------------------------

  operation(:grant,
    operation_id: "admin_grant_achievement",
    summary: "Grant achievement to user (admin)",
    security: [%{"authorization" => []}],
    request_body:
      {"Grant", "application/json",
       %Schema{
         type: :object,
         properties: %{
           user_id: %Schema{type: :integer},
           slug: %Schema{type: :string}
         },
         required: [:user_id, :slug]
       }},
    responses: %{
      200 => {"Granted", "application/json", %Schema{type: :object}},
      404 => {"Not found", "application/json", @error_schema},
      409 => {"Already unlocked", "application/json", @error_schema}
    }
  )

  def grant(conn, %{"user_id" => user_id, "slug" => slug}) do
    case parse_id(user_id) do
      nil ->
        conn |> put_status(:bad_request) |> json(%{error: "invalid_user_id"})

      uid ->
        case Achievements.grant_achievement(uid, slug) do
          {:ok, ua} ->
            json(conn, %{
              data: %{
                user_id: ua.user_id,
                achievement_id: ua.achievement_id,
                progress: ua.progress,
                unlocked_at: ua.unlocked_at
              }
            })

          {:error, :achievement_not_found} ->
            conn |> put_status(:not_found) |> json(%{error: "achievement_not_found"})

          {:error, :already_unlocked} ->
            conn |> put_status(:conflict) |> json(%{error: "already_unlocked"})
        end
    end
  end

  # ---------------------------------------------------------------------------
  # REVOKE
  # ---------------------------------------------------------------------------

  operation(:revoke,
    operation_id: "admin_revoke_achievement",
    summary: "Revoke achievement from user (admin)",
    security: [%{"authorization" => []}],
    request_body:
      {"Revoke", "application/json",
       %Schema{
         type: :object,
         properties: %{
           user_id: %Schema{type: :integer},
           achievement_id: %Schema{type: :integer}
         },
         required: [:user_id, :achievement_id]
       }},
    responses: %{
      200 => {"Revoked", "application/json", %Schema{type: :object}},
      404 => {"Not found", "application/json", @error_schema}
    }
  )

  def revoke(conn, %{"user_id" => user_id, "achievement_id" => achievement_id}) do
    with uid when uid != nil <- parse_id(user_id),
         aid when aid != nil <- parse_id(achievement_id) do
      case Achievements.revoke_achievement(uid, aid) do
        {:ok, _} -> json(conn, %{message: "achievement revoked"})
        {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "not_found"})
      end
    else
      nil -> conn |> put_status(:bad_request) |> json(%{error: "invalid_id"})
    end
  end

  # ---------------------------------------------------------------------------
  # UNLOCK (instant unlock by slug)
  # ---------------------------------------------------------------------------

  operation(:unlock,
    operation_id: "admin_unlock_achievement",
    summary: "Unlock achievement for user (admin)",
    security: [%{"authorization" => []}],
    request_body:
      {"Unlock", "application/json",
       %Schema{
         type: :object,
         properties: %{
           user_id: %Schema{type: :integer},
           slug: %Schema{type: :string}
         },
         required: [:user_id, :slug]
       }},
    responses: %{
      200 => {"Unlocked", "application/json", %Schema{type: :object}},
      404 => {"Not found", "application/json", @error_schema},
      409 => {"Already unlocked", "application/json", @error_schema}
    }
  )

  def unlock(conn, %{"user_id" => user_id, "slug" => slug}) do
    case parse_id(user_id) do
      nil ->
        conn |> put_status(:bad_request) |> json(%{error: "invalid_user_id"})

      uid ->
        case Achievements.unlock_achievement(uid, slug) do
          {:ok, ua} ->
            json(conn, %{
              data: %{
                user_id: ua.user_id,
                achievement_id: ua.achievement_id,
                progress: ua.progress,
                unlocked_at: ua.unlocked_at
              }
            })

          {:error, :achievement_not_found} ->
            conn |> put_status(:not_found) |> json(%{error: "achievement_not_found"})

          {:error, :already_unlocked} ->
            conn |> put_status(:conflict) |> json(%{error: "already_unlocked"})
        end
    end
  end

  # ---------------------------------------------------------------------------
  # INCREMENT PROGRESS
  # ---------------------------------------------------------------------------

  operation(:increment,
    operation_id: "admin_increment_achievement",
    summary: "Increment achievement progress for user (admin)",
    security: [%{"authorization" => []}],
    request_body:
      {"Increment", "application/json",
       %Schema{
         type: :object,
         properties: %{
           user_id: %Schema{type: :integer},
           slug: %Schema{type: :string},
           amount: %Schema{type: :integer, minimum: 1}
         },
         required: [:user_id, :slug]
       }},
    responses: %{
      200 => {"Progress updated", "application/json", %Schema{type: :object}},
      404 => {"Not found", "application/json", @error_schema}
    }
  )

  def increment(conn, %{"user_id" => user_id, "slug" => slug} = params) do
    amount = parse_int(params["amount"], 1)

    case parse_id(user_id) do
      nil ->
        conn |> put_status(:bad_request) |> json(%{error: "invalid_user_id"})

      uid ->
        case Achievements.increment_progress(uid, slug, amount) do
          {:ok, ua} ->
            json(conn, %{
              data: %{
                user_id: ua.user_id,
                achievement_id: ua.achievement_id,
                progress: ua.progress,
                unlocked_at: ua.unlocked_at
              }
            })

          {:error, :achievement_not_found} ->
            conn |> put_status(:not_found) |> json(%{error: "achievement_not_found"})
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp serialize(achievement) do
    %{
      id: achievement.id,
      slug: achievement.slug,
      title: achievement.title,
      description: achievement.description || "",
      icon_url: achievement.icon_url || "",
      sort_order: achievement.sort_order,
      hidden: achievement.hidden,
      progress_target: achievement.progress_target,
      metadata: achievement.metadata || %{},
      inserted_at: achievement.inserted_at,
      updated_at: achievement.updated_at
    }
  end

  defp changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end

  defp parse_id(val) when is_integer(val), do: val

  defp parse_id(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp parse_id(_), do: nil

  defp parse_int(nil, default), do: default
  defp parse_int(val, _default) when is_integer(val), do: val

  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {int, ""} -> int
      _ -> default
    end
  end

  defp parse_int(_, default), do: default
end
