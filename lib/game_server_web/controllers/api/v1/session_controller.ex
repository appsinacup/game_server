defmodule GameServerWeb.Api.V1.SessionController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.Accounts
  alias OpenApiSpex.Schema

  tags(["Authentication"])

  operation(:create,
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
                token: %Schema{type: :string, description: "Session token"},
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
              token: "SFMyNTY.g2gDYQFuBgBboby...",
              user: %{id: 1, email: "user@example.com"}
            }
          }
        }
      },
      unauthorized: {"Invalid credentials", "application/json", nil}
    ]
  )

  def create(conn, %{"email" => email, "password" => password}) do
    if user = Accounts.get_user_by_email_and_password(email, password) do
      token = Accounts.generate_user_session_token(user)
      encoded_token = Base.url_encode64(token, padding: false)

      json(conn, %{
        data: %{
          token: encoded_token,
          user: %{id: user.id, email: user.email}
        }
      })
    else
      conn
      |> put_status(:unauthorized)
      |> json(%{error: "Invalid email or password"})
    end
  end

  operation(:delete,
    summary: "Logout",
    description: "Invalidate user session token",
    security: [%{"authorization" => []}],
    parameters: [
      authorization: [
        in: :header,
        name: "Authorization",
        schema: %Schema{type: :string},
        description: "Bearer token",
        required: true,
        example: "Bearer SFMyNTY.g2gDYQFuBgBboby..."
      ]
    ],
    responses: [
      ok: {
        "Logout successful",
        "application/json",
        %Schema{
          type: :object,
          properties: %{
            message: %Schema{type: :string}
          },
          example: %{message: "Logged out successfully"}
        }
      }
    ]
  )

  def delete(conn, _params) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        case Base.url_decode64(token, padding: false) do
          {:ok, decoded_token} ->
            Accounts.delete_user_session_token(decoded_token)

          _ ->
            nil
        end

      _ ->
        nil
    end

    json(conn, %{message: "Logged out successfully"})
  end
end
