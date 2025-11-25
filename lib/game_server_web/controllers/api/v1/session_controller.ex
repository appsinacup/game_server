defmodule GameServerWeb.Api.V1.SessionController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.Accounts
  alias GameServerWeb.Auth.Guardian
  alias OpenApiSpex.Schema

  tags(["Authentication"])

  operation(:create,
    operation_id: "login",
    summary: "Login",
    description: "Authenticate user with email and password",
    request_body: {
      "Login credentials",
      "application/json",
      %Schema{
        type: :object,
        properties: %{
          email: %Schema{type: :string, format: :email, description: "User email"},
          password: %Schema{type: :string, format: :password, description: "User password"}
        },
        required: [:email, :password],
        example: %{
          email: "user@example.com",
          password: "securepassword123"
        }
      }
    },
    responses: [
      ok: {
        "Login successful",
        "application/json",
        %Schema{
          type: :object,
          properties: %{
            data: %Schema{
              type: :object,
              properties: %{
                access_token: %Schema{type: :string, description: "JWT access token (15 min)"},
                refresh_token: %Schema{type: :string, description: "JWT refresh token (30 days)"},
                expires_in: %Schema{
                  type: :integer,
                  description: "Seconds until access token expires"
                },
                user: %Schema{
                  type: :object,
                  properties: %{
                    id: %Schema{type: :integer},
                    email: %Schema{type: :string}
                  }
                }
              }
            }
          },
          example: %{
            data: %{
              access_token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
              refresh_token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
              expires_in: 900
            }
          }
        }
      },
      unauthorized: {"Invalid credentials", "application/json", nil}
    ]
  )

  def create(conn, %{"email" => email, "password" => password}) do
    if user = Accounts.get_user_by_email_and_password(email, password) do
      # Generate both access and refresh tokens
      {:ok, access_token, _access_claims} =
        Guardian.encode_and_sign(user, %{}, token_type: "access")

      {:ok, refresh_token, _refresh_claims} =
        Guardian.encode_and_sign(user, %{}, token_type: "refresh", ttl: {30, :days})

      # Refresh tokens are stateless JWTs; do not persist on server side.

      json(conn, %{
        data: %{
          access_token: access_token,
          refresh_token: refresh_token,
          expires_in: 900
        }
      })
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Invalid email or password"})
    end
  end

  operation(:delete,
    operation_id: "logout",
    summary: "Logout",
    description: "Invalidate user session token",
    security: [%{"authorization" => []}],
    parameters: [],
    responses: [
      no_content: {"Logout successful", "application/json", nil}
    ]
  )

  def delete(conn, _params) do
    send_resp(conn, :no_content, "")
  end

  operation(:refresh,
    operation_id: "refresh_token",
    summary: "Refresh access token",
    security: [%{"authorization" => []}],
    description: "Exchange a valid refresh token for a new access token",
    request_body: {
      "Refresh token",
      "application/json",
      %Schema{
        type: :object,
        properties: %{
          refresh_token: %Schema{type: :string, description: "Valid refresh token"}
        },
        required: [:refresh_token],
        example: %{
          refresh_token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
        }
      }
    },
    responses: [
      ok: {
        "Token refreshed successfully",
        "application/json",
        %Schema{
          type: :object,
          properties: %{
            access_token: %Schema{type: :string, description: "New access token"},
            expires_in: %Schema{type: :integer, description: "Seconds until expiry"}
          },
          example: %{
            access_token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
            expires_in: 900
          }
        }
      },
      unauthorized: {"Invalid or expired refresh token", "application/json", nil}
    ]
  )

  def refresh(conn, %{"refresh_token" => refresh_token}) do
    # Verify the refresh token and check it's actually a refresh token type
    case Guardian.decode_and_verify(refresh_token, %{"typ" => "refresh"}) do
      {:ok, claims} ->
        case Guardian.resource_from_claims(claims) do
          {:ok, user} ->
            # Issue a new access token
            {:ok, new_access_token, _claims} =
              Guardian.encode_and_sign(user, %{}, token_type: "access")

            json(conn, %{access_token: new_access_token, expires_in: 900})

          {:error, _reason} ->
            conn
            |> put_status(:unauthorized)
            |> json(%{error: "Invalid refresh token"})
        end

      {:error, _reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid or expired refresh token"})
    end
  end

  def refresh(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "refresh_token is required"})
  end
end
