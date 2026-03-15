defmodule GameServerWeb.Api.V1.AchievementController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.Achievements
  alias OpenApiSpex.Schema

  tags(["Achievements"])

  @achievement_schema %Schema{
    type: :object,
    properties: %{
      id: %Schema{type: :integer, description: "Achievement ID"},
      slug: %Schema{type: :string, description: "Unique identifier"},
      title: %Schema{type: :string, description: "Display title"},
      description: %Schema{type: :string, description: "Description"},
      icon_url: %Schema{type: :string, description: "Icon URL"},
      points: %Schema{type: :integer, description: "Point value"},
      sort_order: %Schema{type: :integer, description: "Display order"},
      hidden: %Schema{type: :boolean, description: "Whether hidden until unlocked"},
      progress_target: %Schema{type: :integer, description: "Steps to complete (1 = one-shot)"},
      progress: %Schema{
        type: :integer,
        description: "Current user progress (0 if unauthenticated)"
      },
      unlocked_at: %Schema{
        type: :string,
        format: "date-time",
        nullable: true,
        description: "When the user unlocked this (null if not unlocked)"
      },
      metadata: %Schema{type: :object, description: "Arbitrary metadata"}
    },
    example: %{
      id: 1,
      slug: "first_lobby",
      title: "Welcome!",
      description: "Join your first lobby",
      icon_url: "",
      points: 10,
      sort_order: 0,
      hidden: false,
      progress_target: 1,
      progress: 1,
      unlocked_at: "2026-01-15T10:30:00Z",
      metadata: %{}
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

  # ---------------------------------------------------------------------------
  # GET /api/v1/achievements
  # ---------------------------------------------------------------------------

  operation(:index,
    operation_id: "list_achievements",
    summary: "List achievements",
    description:
      "List all achievements. If authenticated, includes user progress. Hidden achievements are only shown if unlocked.",
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
             meta: @meta_schema
           }
         }}
    }
  )

  def index(conn, params) do
    page = parse_int(params["page"], 1)
    page_size = parse_int(params["page_size"], 25)

    user_id =
      case conn.assigns[:current_scope] do
        %{user: %{id: id}} -> id
        _ -> nil
      end

    achievements =
      Achievements.list_achievements(
        user_id: user_id,
        page: page,
        page_size: page_size
      )

    total_count = Achievements.count_achievements()
    total_pages = max(ceil(total_count / page_size), 1)
    count = length(achievements)

    json(conn, %{
      data: Enum.map(achievements, &serialize_achievement/1),
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
  # GET /api/v1/achievements/:slug
  # ---------------------------------------------------------------------------

  operation(:show,
    operation_id: "get_achievement",
    summary: "Get achievement details",
    description: "Get a specific achievement by slug. If authenticated, includes user progress.",
    parameters: [
      slug: [in: :path, schema: %Schema{type: :string}, required: true]
    ],
    responses: %{
      200 => {"Achievement", "application/json", @achievement_schema},
      404 => {"Not found", "application/json", %Schema{type: :object}}
    }
  )

  def show(conn, %{"slug" => slug}) do
    case Achievements.get_achievement_by_slug(slug) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "not_found"})

      achievement ->
        user_id =
          case conn.assigns[:current_scope] do
            %{user: %{id: id}} -> id
            _ -> nil
          end

        ua =
          if user_id do
            Achievements.get_user_achievement(user_id, achievement.id)
          end

        json(conn, %{
          data:
            serialize_achievement(%{
              achievement: achievement,
              progress: (ua && ua.progress) || 0,
              unlocked_at: ua && ua.unlocked_at
            })
        })
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/achievements/me
  # ---------------------------------------------------------------------------

  operation(:me,
    operation_id: "my_achievements",
    summary: "List my unlocked achievements",
    description: "List all achievements unlocked by the authenticated user.",
    parameters: [
      page: [in: :query, schema: %Schema{type: :integer}, required: false],
      page_size: [in: :query, schema: %Schema{type: :integer}, required: false]
    ],
    responses: %{
      200 =>
        {"User achievements", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Schema{type: :array, items: @achievement_schema},
             meta: @meta_schema,
             total_points: %Schema{type: :integer, description: "Total achievement points earned"}
           }
         }},
      401 => {"Unauthorized", "application/json", %Schema{type: :object}}
    }
  )

  def me(conn, params) do
    case conn.assigns[:current_scope] do
      %{user: %{id: user_id}} ->
        page = parse_int(params["page"], 1)
        page_size = parse_int(params["page_size"], 25)

        user_achievements =
          Achievements.list_user_achievements(user_id, page: page, page_size: page_size)

        total_count = Achievements.count_user_achievements(user_id)
        total_points = Achievements.get_user_points(user_id)
        total_pages = max(ceil(total_count / page_size), 1)
        count = length(user_achievements)

        json(conn, %{
          data:
            Enum.map(user_achievements, fn ua ->
              serialize_achievement(%{
                achievement: ua.achievement,
                progress: ua.progress,
                unlocked_at: ua.unlocked_at
              })
            end),
          meta: %{
            page: page,
            page_size: page_size,
            count: count,
            total_count: total_count,
            total_pages: total_pages,
            has_more: count == page_size
          },
          total_points: total_points
        })

      _ ->
        conn |> put_status(:unauthorized) |> json(%{error: "Not authenticated"})
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/v1/achievements/user/:user_id
  # ---------------------------------------------------------------------------

  operation(:user_achievements,
    operation_id: "user_achievements",
    summary: "List a user's unlocked achievements",
    description: "List achievements unlocked by a specific user.",
    parameters: [
      user_id: [in: :path, schema: %Schema{type: :integer}, required: true],
      page: [in: :query, schema: %Schema{type: :integer}, required: false],
      page_size: [in: :query, schema: %Schema{type: :integer}, required: false]
    ],
    responses: %{
      200 =>
        {"User achievements", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Schema{type: :array, items: @achievement_schema},
             meta: @meta_schema,
             total_points: %Schema{type: :integer}
           }
         }}
    }
  )

  def user_achievements(conn, %{"user_id" => user_id_str} = params) do
    case Integer.parse(user_id_str) do
      {user_id, ""} ->
        page = parse_int(params["page"], 1)
        page_size = parse_int(params["page_size"], 25)

        user_achievements =
          Achievements.list_user_achievements(user_id, page: page, page_size: page_size)

        total_count = Achievements.count_user_achievements(user_id)
        total_points = Achievements.get_user_points(user_id)
        total_pages = max(ceil(total_count / page_size), 1)
        count = length(user_achievements)

        json(conn, %{
          data:
            Enum.map(user_achievements, fn ua ->
              serialize_achievement(%{
                achievement: ua.achievement,
                progress: ua.progress,
                unlocked_at: ua.unlocked_at
              })
            end),
          meta: %{
            page: page,
            page_size: page_size,
            count: count,
            total_count: total_count,
            total_pages: total_pages,
            has_more: count == page_size
          },
          total_points: total_points
        })

      _ ->
        conn |> put_status(:bad_request) |> json(%{error: "invalid_user_id"})
    end
  end

  # ---------------------------------------------------------------------------
  # Serialization
  # ---------------------------------------------------------------------------

  defp serialize_achievement(%{achievement: a, progress: progress, unlocked_at: unlocked_at}) do
    %{
      id: a.id,
      slug: a.slug,
      title: a.title,
      description: a.description || "",
      icon_url: a.icon_url || "",
      points: a.points,
      sort_order: a.sort_order,
      hidden: a.hidden,
      progress_target: a.progress_target,
      progress: progress,
      unlocked_at: unlocked_at,
      metadata: a.metadata || %{}
    }
  end

  defp parse_int(nil, default), do: default

  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {int, ""} -> max(int, 1)
      _ -> default
    end
  end

  defp parse_int(val, _default) when is_integer(val), do: max(val, 1)
  defp parse_int(_, default), do: default
end
