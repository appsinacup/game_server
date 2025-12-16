defmodule GameServerWeb.Api.V1.MeController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias OpenApiSpex.Schema

  tags(["Users"])

  operation(:show,
    operation_id: "get_current_user",
    summary: "Return current user info",
    description: "Returns the current authenticated user's basic information.",
    security: [%{"authorization" => []}],
    responses: [
      ok: {
        "User info",
        "application/json",
        %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :integer},
            email: %Schema{type: :string},
            profile_url: %Schema{type: :string},
            display_name: %Schema{type: :string},
            metadata: %Schema{type: :object},
            lobby_id: %Schema{
              type: :integer,
              nullable: true,
              description: "Lobby ID when user is currently in a lobby"
            },
            linked_providers: %Schema{
              type: :object,
              description: "Shows which OAuth providers are linked to this account",
              properties: %{
                google: %Schema{type: :boolean},
                facebook: %Schema{type: :boolean},
                discord: %Schema{type: :boolean},
                apple: %Schema{type: :boolean},
                steam: %Schema{type: :boolean},
                device: %Schema{type: :boolean}
              }
            },
            has_password: %Schema{
              type: :boolean,
              description: "Whether the user has a password set"
            }
          }
        }
      },
      unauthorized: {"Not authenticated", "application/json", nil}
    ]
  )

  def show(conn, _params) do
    # Guardian pipeline has already authenticated and loaded the user
    # into current_scope via AssignCurrentScope plug
    case conn.assigns.current_scope do
      %{user: user} when user != nil ->
        json(conn, %{
          id: user.id,
          email: user.email || "",
          profile_url: user.profile_url || "",
          metadata: user.metadata || %{},
          display_name: user.display_name || "",
          lobby_id: user.lobby_id,
          linked_providers: GameServer.Accounts.get_linked_providers(user),
          has_password: GameServer.Accounts.has_password?(user)
        })

      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Not authenticated"})
    end
  end

  operation(:update_password,
    operation_id: "update_current_user_password",
    summary: "Update current user password",
    request_body: {
      "New password payload",
      "application/json",
      %Schema{
        type: :object,
        properties: %{
          password: %Schema{type: :string}
        },
        required: [:password]
      }
    },
    security: [%{"authorization" => []}],
    responses: [
      ok: {"Password updated", "application/json", nil},
      bad_request: {"Invalid data", "application/json", nil},
      unauthorized: {"Not authenticated", "application/json", nil}
    ]
  )

  def update_password(conn, %{"password" => _} = params) do
    user = conn.assigns.current_scope.user

    case GameServer.Accounts.update_user_password(user, params) do
      {:ok, {user, _tokens}} ->
        json(conn, %{ok: true, id: user.id})

      {:error, changeset} ->
        conn
        |> put_status(:bad_request)
        |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)})
    end
  end

  operation(:update_display_name,
    operation_id: "update_current_user_display_name",
    summary: "Update current user's display name",
    request_body: {
      "Display name payload",
      "application/json",
      %Schema{
        type: :object,
        properties: %{
          display_name: %Schema{type: :string}
        },
        required: [:display_name]
      }
    },
    security: [%{"authorization" => []}],
    responses: [
      ok: {"Display name updated", "application/json", nil},
      bad_request: {"Invalid data", "application/json", nil},
      unauthorized: {"Not authenticated", "application/json", nil}
    ]
  )

  def update_display_name(conn, %{"display_name" => _} = params) do
    user = conn.assigns.current_scope.user

    case GameServer.Accounts.update_user_display_name(user, params) do
      {:ok, user} ->
        json(conn, %{ok: true, id: user.id, display_name: user.display_name || ""})

      {:error, changeset} ->
        conn
        |> put_status(:bad_request)
        |> json(%{errors: Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)})
    end
  end

  operation(:delete,
    operation_id: "delete_current_user",
    summary: "Delete current user",
    description: "Deletes the authenticated user's account",
    security: [%{"authorization" => []}],
    responses: [
      ok: {"Account deleted", "application/json", %Schema{type: :object}},
      bad_request: {"Failed to delete account", "application/json", nil},
      unauthorized: {"Not authenticated", "application/json", nil}
    ]
  )

  def delete(conn, _params) do
    user = conn.assigns.current_scope.user

    case GameServer.Accounts.delete_user(user) do
      {:ok, _} ->
        json(conn, %{})

      {:error, _} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Failed to delete account"})
    end
  end
end
