defmodule GameServerWeb.Api.V1.UserController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.Accounts
  alias OpenApiSpex.Schema

  @error_schema %Schema{type: :object, properties: %{error: %Schema{type: :string}}}

  tags(["Users"])

  operation(:index,
    operation_id: "search_users",
    summary: "Search users by id/email/display_name",
    parameters: [
      q: [in: :query, schema: %Schema{type: :string}],
      page: [in: :query, schema: %Schema{type: :integer}],
      page_size: [in: :query, schema: %Schema{type: :integer}]
    ],
    responses: [
      ok:
        {"Users (paginated)", "application/json",
         %Schema{
           type: :object,
           properties: %{
             data: %Schema{
               type: :array,
               items: %Schema{
                 type: :object,
                 properties: %{
                   id: %Schema{type: :integer},
                   email: %Schema{type: :string},
                   display_name: %Schema{type: :string},
                   profile_url: %Schema{type: :string},
                   lobby_id: %Schema{
                     type: :integer,
                     nullable: false,
                     description:
                       "Lobby ID when user is currently in a lobby. -1 means not currently in a lobby."
                   },
                   is_online: %Schema{type: :boolean},
                   last_seen_at: %Schema{type: :string, format: :date_time, nullable: true}
                 }
               }
             },
             meta: %Schema{
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
           }
         }}
    ]
  )

  operation(:show,
    operation_id: "get_user",
    summary: "Get a user by id",
    parameters: [id: [in: :path, schema: %Schema{type: :integer}, required: true]],
    responses: [
      ok:
        {"User", "application/json",
         %Schema{
           type: :object,
           properties: %{
             id: %Schema{type: :integer},
             email: %Schema{type: :string},
             display_name: %Schema{type: :string},
             profile_url: %Schema{type: :string},
             lobby_id: %Schema{
               type: :integer,
               nullable: false,
               description:
                 "Lobby ID when user is currently in a lobby. -1 means not currently in a lobby."
             },
             is_online: %Schema{type: :boolean},
             last_seen_at: %Schema{type: :string, format: :date_time, nullable: true}
           }
         }},
      not_found: {"Not found", "application/json", @error_schema}
    ]
  )

  def index(conn, params) do
    q = Map.get(params, "q", "")
    page = (params["page"] && String.to_integer(params["page"])) || 1
    page_size = (params["page_size"] && String.to_integer(params["page_size"])) || 25

    users = if q == "", do: [], else: Accounts.search_users(q, page: page, page_size: page_size)
    serialized = Enum.map(users, &serialize_user/1)
    count = length(serialized)

    total_count = if q == "", do: 0, else: Accounts.count_search_users(q)
    total_pages = if page_size > 0, do: div(total_count + page_size - 1, page_size), else: 0

    json(conn, %{
      data: serialized,
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

  def show(conn, %{"id" => id}) do
    case Accounts.get_user!(String.to_integer(id)) do
      %{} = user -> json(conn, serialize_user(user))
      _ -> conn |> put_status(:not_found) |> json(%{error: "not_found"})
    end
  rescue
    Ecto.NoResultsError -> conn |> put_status(:not_found) |> json(%{error: "not_found"})
  end

  defp serialize_user(user) do
    %{
      id: user.id,
      email: user.email || "",
      display_name: user.display_name || "",
      profile_url: user.profile_url || "",
      lobby_id: user.lobby_id || -1,
      is_online: user.is_online || false,
      last_seen_at: user.last_seen_at
    }
  end
end
