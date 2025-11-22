defmodule GameServerWeb.AuthController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs
  plug Ueberauth

  alias GameServer.Accounts
  alias GameServerWeb.UserAuth

  # Browser OAuth operations (not included in API spec)
  def request(conn, _params) do
    # This is handled by Ueberauth
    conn
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate with Discord.")
    |> redirect(to: ~p"/users/log-in")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    user_params = %{
      email: auth.info.email,
      discord_id: auth.uid,
      discord_username: auth.info.nickname || auth.info.name,
      discord_avatar: auth.info.image
    }

    require Logger
    Logger.info("Discord OAuth user params: #{inspect(user_params)}")

    case Accounts.find_or_create_from_discord(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Successfully authenticated with Discord.")
        |> UserAuth.log_in_user(user)

      {:error, changeset} ->
        Logger.error("Failed to create user from Discord: #{inspect(changeset.errors)}")

        conn
        |> put_flash(:error, "Failed to create or update user account.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "You have been logged out!")
    |> UserAuth.log_out_user()
  end

  # API OAuth endpoints
  operation(:api_request,
    summary: "Initiate API OAuth",
    description: "Returns OAuth authorization URL for API clients",
    tags: ["Authentication"],
    parameters: [
      provider: [
        in: :path,
        name: "provider",
        schema: %OpenApiSpex.Schema{type: :string, enum: ["discord"]},
        description: "OAuth provider",
        required: true,
        example: "discord"
      ]
    ],
    responses: [
      ok: {
        "OAuth URL",
        "application/json",
        %OpenApiSpex.Schema{
          type: :object,
          properties: %{
            authorization_url: %OpenApiSpex.Schema{
              type: :string,
              description: "URL to redirect user to for OAuth"
            }
          },
          example: %{authorization_url: "https://discord.com/oauth2/authorize?..."}
        }
      }
    ]
  )

  def api_request(conn, %{"provider" => "discord"}) do
    # Generate the Discord OAuth URL
    client_id = System.get_env("DISCORD_CLIENT_ID")
    redirect_uri = "#{conn.scheme}://#{conn.host}:#{conn.port}/api/v1/auth/discord/callback"
    scope = "identify email"

    url =
      "https://discord.com/oauth2/authorize?client_id=#{client_id}&redirect_uri=#{URI.encode_www_form(redirect_uri)}&response_type=code&scope=#{URI.encode_www_form(scope)}"

    json(conn, %{authorization_url: url})
  end

  operation(:api_callback,
    summary: "API OAuth callback",
    description: "Handles OAuth callback and returns user token",
    tags: ["Authentication"],
    parameters: [
      provider: [
        in: :path,
        name: "provider",
        schema: %OpenApiSpex.Schema{type: :string, enum: ["discord"]},
        description: "OAuth provider",
        required: true,
        example: "discord"
      ],
      code: [
        in: :query,
        name: "code",
        schema: %OpenApiSpex.Schema{type: :string},
        description: "Authorization code from OAuth provider",
        required: true
      ]
    ],
    responses: [
      ok: {
        "Authentication successful",
        "application/json",
        %OpenApiSpex.Schema{
          type: :object,
          properties: %{
            data: %OpenApiSpex.Schema{
              type: :object,
              properties: %{
                token: %OpenApiSpex.Schema{type: :string, description: "Session token"},
                user: %OpenApiSpex.Schema{
                  type: :object,
                  properties: %{
                    id: %OpenApiSpex.Schema{type: :integer},
                    email: %OpenApiSpex.Schema{type: :string},
                    discord_username: %OpenApiSpex.Schema{type: :string}
                  }
                }
              }
            }
          },
          example: %{
            data: %{
              token: "SFMyNTY.g2gDYQFuBgBboby...",
              user: %{id: 1, email: "user@example.com", discord_username: "username"}
            }
          }
        }
      },
      bad_request: {"OAuth error", "application/json", nil}
    ]
  )

  def api_callback(conn, %{"provider" => "discord", "code" => code}) do
    # Exchange code for access token
    client_id = System.get_env("DISCORD_CLIENT_ID")
    client_secret = System.get_env("DISCORD_CLIENT_SECRET")
    redirect_uri = "#{conn.scheme}://#{conn.host}:#{conn.port}/api/v1/auth/discord/callback"

    case exchange_discord_code(code, client_id, client_secret, redirect_uri) do
      {:ok, user_info} ->
        user_params = %{
          email: user_info["email"],
          discord_id: user_info["id"],
          discord_username: user_info["username"],
          discord_avatar: user_info["avatar"]
        }

        case Accounts.find_or_create_from_discord(user_params) do
          {:ok, user} ->
            token = Accounts.generate_user_session_token(user)
            encoded_token = Base.url_encode64(token, padding: false)

            json(conn, %{
              data: %{
                token: encoded_token,
                user: %{
                  id: user.id,
                  email: user.email,
                  discord_username: user.discord_username
                }
              }
            })

          {:error, changeset} ->
            conn
            |> put_status(:bad_request)
            |> json(%{
              error: "Failed to create or update user account",
              details: changeset.errors
            })
        end

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "OAuth failed", details: reason})
    end
  end

  defp exchange_discord_code(code, client_id, client_secret, redirect_uri) do
    url = "https://discord.com/api/oauth2/token"

    body = %{
      client_id: client_id,
      client_secret: client_secret,
      grant_type: "authorization_code",
      code: code,
      redirect_uri: redirect_uri
    }

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    case Req.post(url, form: body, headers: headers) do
      {:ok, %{status: 200, body: %{"access_token" => access_token}}} ->
        # Get user info with access token
        user_url = "https://discord.com/api/users/@me"
        auth_headers = [{"Authorization", "Bearer #{access_token}"}]

        case Req.get(user_url, headers: auth_headers) do
          {:ok, %{status: 200, body: user_info}} ->
            {:ok, user_info}

          _ ->
            {:error, "Failed to get user info"}
        end

      _ ->
        {:error, "Failed to exchange code"}
    end
  end
end
