defmodule GameServerWeb.Api.V1.SessionController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.Accounts
  alias GameServerWeb.Auth.Guardian
  alias OpenApiSpex.Schema

  @error_schema %Schema{type: :object, properties: %{error: %Schema{type: :string}}}

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
                user_id: %Schema{type: :integer}
              }
            }
          },
          example: %{
            data: %{
              access_token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
              refresh_token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
              expires_in: 900,
              user_id: 123
            }
          }
        }
      },
      unauthorized: {"Invalid credentials", "application/json", @error_schema}
    ]
  )

  def create(conn, %{"email" => email, "password" => password}) do
    if user = Accounts.get_user_by_email_and_password(email, password) do
      # If device_id provided and not already attached, attempt to attach it
      case conn.body_params do
        %{"device_id" => device_id} when is_binary(device_id) and is_nil(user.device_id) ->
          # Attach only if device-based auth/attachment is enabled by config
          if Accounts.device_auth_enabled?() do
            # best-effort attach (ignore attach errors so standard login still succeeds)
            _ = Accounts.attach_device_to_user(user, device_id)
          end

        _ ->
          :ok
      end

      # Generate both access and refresh tokens
      {:ok, access_token, _access_claims} =
        Guardian.encode_and_sign(user, %{}, token_type: "access")

      {:ok, refresh_token, _refresh_claims} =
        Guardian.encode_and_sign(user, %{}, token_type: "refresh", ttl: {30, :days})

      # Track login activity
      Accounts.touch_last_seen(user)

      json(conn, %{
        data: %{
          access_token: access_token,
          refresh_token: refresh_token,
          expires_in: 900,
          user_id: user.id
        }
      })
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Invalid email or password"})
    end
  end

  operation(:create_device,
    operation_id: "device_login",
    summary: "Device login",
    description: "Authenticate or create a device-backed user using a device_id (no password).",
    request_body: {
      "Device login",
      "application/json",
      %Schema{
        type: :object,
        properties: %{
          device_id: %Schema{type: :string, description: "Device identifier string"}
        },
        required: [:device_id],
        example: %{device_id: "device:uuid-or-some-string"}
      }
    },
    responses: [
      ok:
        {"Login successful", "application/json",
         %Schema{type: :object, properties: %{data: GameServerWeb.Schemas.OAuthSessionData}}},
      bad_request: {"Unable to create device user", "application/json", @error_schema},
      forbidden: {"Device auth disabled", "application/json", @error_schema}
    ]
  )

  # Device-based login: create or find a user for a given device_id and
  # return JWTs. This enables SDKs to authenticate with a simple device_id.
  # Device-specific login endpoint. This route accepts only a device_id
  # and returns JWT tokens for the device's user.
  def create_device(conn, %{"device_id" => device_id}) when is_binary(device_id) do
    if Accounts.device_auth_enabled?() do
      case Accounts.find_or_create_from_device(device_id) do
        {:ok, user} ->
          {:ok, access_token, _} = Guardian.encode_and_sign(user, %{}, token_type: "access")

          {:ok, refresh_token, _} =
            Guardian.encode_and_sign(user, %{}, token_type: "refresh", ttl: {30, :days})

          Accounts.touch_last_seen(user)

          json(conn, %{
            data: %{
              access_token: access_token,
              refresh_token: refresh_token,
              expires_in: 900,
              user_id: user.id
            }
          })

        {:error, changeset} ->
          conn
          |> put_status(:bad_request)
          |> json(%{
            error: "unable to create device user",
            details: Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
          })
      end
    else
      conn
      |> put_status(:forbidden)
      |> json(%{error: "device-based authentication is disabled"})
    end
  end

  operation(:delete,
    operation_id: "logout",
    summary: "Logout",
    description: "Invalidate user session token",
    parameters: [],
    responses: [
      ok: {"Logout successful", "application/json", %Schema{type: :object}}
    ]
  )

  def delete(conn, _params) do
    json(conn, %{})
  end

  operation(:refresh,
    operation_id: "refresh_token",
    summary: "Refresh access token",
    security: [],
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
            data: %Schema{
              type: :object,
              properties: %{
                access_token: %Schema{type: :string, description: "New access token"},
                refresh_token: %Schema{
                  type: :string,
                  description: "Refresh token (same as input)"
                },
                user_id: %Schema{type: :integer, description: "User ID"},
                expires_in: %Schema{type: :integer, description: "Seconds until expiry"}
              }
            }
          },
          example: %{
            data: %{
              access_token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
              refresh_token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
              user_id: 1,
              expires_in: 900
            }
          }
        }
      },
      unauthorized: {"Invalid or expired refresh token", "application/json", @error_schema},
      bad_request: {"Bad request", "application/json", @error_schema}
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

            json(conn, %{
              data: %{
                access_token: new_access_token,
                refresh_token: refresh_token,
                user_id: user.id,
                expires_in: 900
              }
            })

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
