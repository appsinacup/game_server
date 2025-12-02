defmodule GameServerWeb.Api.V1.LeaderboardController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.Leaderboards
  alias GameServer.Leaderboards.Leaderboard
  alias OpenApiSpex.Schema

  tags(["Leaderboards"])

  # Shared schema for leaderboard response
  @leaderboard_schema %Schema{
    type: :object,
    properties: %{
      id: %Schema{type: :string, description: "Leaderboard ID"},
      title: %Schema{type: :string, description: "Display title"},
      description: %Schema{type: :string, description: "Description", nullable: true},
      sort_order: %Schema{
        type: :string,
        enum: ["desc", "asc"],
        description: "Sort order - desc (higher is better) or asc (lower is better)"
      },
      operator: %Schema{
        type: :string,
        enum: ["set", "best", "incr", "decr"],
        description: "Score operator"
      },
      starts_at: %Schema{type: :string, format: "date-time", nullable: true},
      ends_at: %Schema{type: :string, format: "date-time", nullable: true},
      is_active: %Schema{type: :boolean, description: "Whether the leaderboard is still active"},
      metadata: %Schema{type: :object, description: "Arbitrary metadata"},
      inserted_at: %Schema{type: :string, format: "date-time"},
      updated_at: %Schema{type: :string, format: "date-time"}
    },
    example: %{
      id: "weekly_kills_w49",
      title: "Weekly Kills - Week 49",
      description: "Get the most kills this week!",
      sort_order: "desc",
      operator: "incr",
      starts_at: "2025-12-02T00:00:00Z",
      ends_at: nil,
      is_active: true,
      metadata: %{},
      inserted_at: "2025-12-02T10:00:00Z",
      updated_at: "2025-12-02T10:00:00Z"
    }
  }

  @record_schema %Schema{
    type: :object,
    properties: %{
      rank: %Schema{type: :integer, description: "Player's rank on this leaderboard"},
      user_id: %Schema{type: :integer, description: "User ID"},
      display_name: %Schema{type: :string, description: "User's display name", nullable: true},
      score: %Schema{type: :integer, description: "Score value"},
      metadata: %Schema{type: :object, description: "Per-record metadata"},
      updated_at: %Schema{type: :string, format: "date-time"}
    },
    example: %{
      rank: 1,
      user_id: 123,
      display_name: "ProGamer123",
      score: 5000,
      metadata: %{weapon: "sword"},
      updated_at: "2025-12-02T10:00:00Z"
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
  # List Leaderboards
  # ---------------------------------------------------------------------------

  operation(:index,
    operation_id: "list_leaderboards",
    summary: "List leaderboards",
    description: "Return all leaderboards, optionally filtered by active status.",
    parameters: [
      active: [
        in: :query,
        schema: %Schema{type: :string, enum: ["true", "false"]},
        description: "Filter by active status - 'true' or 'false' (omit for all)"
      ],
      page: [
        in: :query,
        schema: %Schema{type: :integer, default: 1},
        description: "Page number"
      ],
      page_size: [
        in: :query,
        schema: %Schema{type: :integer, default: 25},
        description: "Page size (max 100)"
      ]
    ],
    responses: [
      ok:
        {"List of leaderboards", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Schema{type: :array, items: @leaderboard_schema},
             meta: @meta_schema
           }
         }}
    ]
  )

  def index(conn, params) do
    page = parse_int(params["page"], 1)
    page_size = min(parse_int(params["page_size"], 25), 100)

    opts =
      [page: page, page_size: page_size]
      |> maybe_add_active_filter(params["active"])

    leaderboards = Leaderboards.list_leaderboards(opts)
    total_count = Leaderboards.count_leaderboards(Keyword.take(opts, [:active]))
    total_pages = ceil_div(total_count, page_size)

    json(conn, %{
      data: Enum.map(leaderboards, &serialize_leaderboard/1),
      meta: %{
        page: page,
        page_size: page_size,
        count: length(leaderboards),
        total_count: total_count,
        total_pages: total_pages,
        has_more: page < total_pages
      }
    })
  end

  # ---------------------------------------------------------------------------
  # Get Leaderboard
  # ---------------------------------------------------------------------------

  operation(:show,
    operation_id: "get_leaderboard",
    summary: "Get a leaderboard",
    description: "Return details for a specific leaderboard.",
    parameters: [
      id: [
        in: :path,
        schema: %Schema{type: :string},
        description: "Leaderboard ID",
        required: true
      ]
    ],
    responses: [
      ok: {"Leaderboard details", "application/json", @leaderboard_schema},
      not_found: {"Leaderboard not found", "application/json", %Schema{type: :object}}
    ]
  )

  def show(conn, %{"id" => id}) do
    case Leaderboards.get_leaderboard(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Leaderboard not found"})

      leaderboard ->
        json(conn, %{data: serialize_leaderboard(leaderboard)})
    end
  end

  # ---------------------------------------------------------------------------
  # List Records
  # ---------------------------------------------------------------------------

  operation(:records,
    operation_id: "list_leaderboard_records",
    summary: "List leaderboard records",
    description: "Return ranked records for a leaderboard.",
    parameters: [
      id: [
        in: :path,
        schema: %Schema{type: :string},
        description: "Leaderboard ID",
        required: true
      ],
      page: [
        in: :query,
        schema: %Schema{type: :integer, default: 1},
        description: "Page number"
      ],
      page_size: [
        in: :query,
        schema: %Schema{type: :integer, default: 25},
        description: "Page size (max 100)"
      ]
    ],
    responses: [
      ok:
        {"List of records", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Schema{type: :array, items: @record_schema},
             meta: @meta_schema
           }
         }},
      not_found: {"Leaderboard not found", "application/json", %Schema{type: :object}}
    ]
  )

  def records(conn, %{"id" => id} = params) do
    case Leaderboards.get_leaderboard(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Leaderboard not found"})

      _leaderboard ->
        page = parse_int(params["page"], 1)
        page_size = min(parse_int(params["page_size"], 25), 100)

        records = Leaderboards.list_records(id, page: page, page_size: page_size)
        total_count = Leaderboards.count_records(id)
        total_pages = ceil_div(total_count, page_size)

        json(conn, %{
          data: Enum.map(records, &serialize_record/1),
          meta: %{
            page: page,
            page_size: page_size,
            count: length(records),
            total_count: total_count,
            total_pages: total_pages,
            has_more: page < total_pages
          }
        })
    end
  end

  # ---------------------------------------------------------------------------
  # Records Around User
  # ---------------------------------------------------------------------------

  operation(:around,
    operation_id: "list_records_around_user",
    summary: "List records around a user",
    description: "Return records centered around a specific user's rank.",
    parameters: [
      id: [
        in: :path,
        schema: %Schema{type: :string},
        description: "Leaderboard ID",
        required: true
      ],
      user_id: [
        in: :path,
        schema: %Schema{type: :integer},
        description: "User ID to center around",
        required: true
      ],
      limit: [
        in: :query,
        schema: %Schema{type: :integer, default: 11},
        description: "Total number of records to return"
      ]
    ],
    responses: [
      ok:
        {"List of records around user", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Schema{type: :array, items: @record_schema}
           }
         }},
      not_found: {"Leaderboard or user not found", "application/json", %Schema{type: :object}}
    ],
    security: [%{"bearer" => []}]
  )

  def around(conn, %{"id" => id, "user_id" => user_id_str} = params) do
    user_id = parse_int(user_id_str, 0)
    limit = parse_int(params["limit"], 11)

    case Leaderboards.get_leaderboard(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Leaderboard not found"})

      _leaderboard ->
        records = Leaderboards.list_records_around_user(id, user_id, limit: limit)

        json(conn, %{
          data: Enum.map(records, &serialize_record/1)
        })
    end
  end

  # ---------------------------------------------------------------------------
  # Current User's Record
  # ---------------------------------------------------------------------------

  operation(:me,
    operation_id: "get_my_record",
    summary: "Get current user's record",
    description: "Return the authenticated user's record and rank on this leaderboard.",
    parameters: [
      id: [
        in: :path,
        schema: %Schema{type: :string},
        description: "Leaderboard ID",
        required: true
      ]
    ],
    responses: [
      ok: {"User's record with rank", "application/json", @record_schema},
      not_found: {"Leaderboard or record not found", "application/json", %Schema{type: :object}}
    ],
    security: [%{"bearer" => []}]
  )

  def me(conn, %{"id" => id}) do
    user_id = conn.assigns.current_scope.user.id

    case Leaderboards.get_leaderboard(id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Leaderboard not found"})

      _leaderboard ->
        case Leaderboards.get_user_record(id, user_id) do
          {:ok, record} ->
            json(conn, %{data: serialize_record(record)})

          {:error, :not_found} ->
            conn
            |> put_status(:not_found)
            |> json(%{error: "No record found for this user"})
        end
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp serialize_leaderboard(lb) do
    %{
      id: lb.id,
      title: lb.title,
      description: lb.description,
      sort_order: to_string(lb.sort_order),
      operator: to_string(lb.operator),
      starts_at: lb.starts_at,
      ends_at: lb.ends_at,
      is_active: Leaderboard.active?(lb),
      metadata: lb.metadata,
      inserted_at: lb.inserted_at,
      updated_at: lb.updated_at
    }
  end

  defp serialize_record(record) do
    %{
      rank: record.rank,
      user_id: record.user_id,
      display_name: record.user && record.user.display_name,
      profile_url: record.user && record.user.profile_url,
      score: record.score,
      metadata: record.metadata,
      updated_at: record.updated_at
    }
  end

  defp parse_int(nil, default), do: default

  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> default
    end
  end

  defp parse_int(val, _default) when is_integer(val), do: val

  defp maybe_add_active_filter(opts, "true"), do: Keyword.put(opts, :active, true)
  defp maybe_add_active_filter(opts, "false"), do: Keyword.put(opts, :active, false)
  defp maybe_add_active_filter(opts, _), do: opts

  defp ceil_div(_num, 0), do: 0
  defp ceil_div(num, denom), do: div(num + denom - 1, denom)
end
