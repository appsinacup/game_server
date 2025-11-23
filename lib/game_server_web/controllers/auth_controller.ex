defmodule GameServerWeb.AuthController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs
  plug Ueberauth

  alias GameServer.Accounts
  alias GameServerWeb.UserAuth
  alias GameServerWeb.Auth.Guardian

  # Browser OAuth operations (not included in API spec)
  def request(conn, _params) do
    # This is handled by Ueberauth
    conn
  end

  def callback(%{assigns: %{ueberauth_failure: _fails}} = conn, _params) do
    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: ~p"/users/log-in")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, %{"provider" => "discord"}) do
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

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, %{"provider" => "apple"}) do
    user_params = %{
      email: auth.info.email,
      apple_id: auth.uid
    }

    require Logger
    Logger.info("Apple OAuth user params: #{inspect(user_params)}")

    case Accounts.find_or_create_from_apple(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Successfully authenticated with Apple.")
        |> UserAuth.log_in_user(user)

      {:error, changeset} ->
        Logger.error("Failed to create user from Apple: #{inspect(changeset.errors)}")

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
        schema: %OpenApiSpex.Schema{type: :string, enum: ["discord", "apple"]},
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

  def api_request(conn, %{"provider" => "apple"}) do
    # Generate the Apple OAuth URL
    client_id = System.get_env("APPLE_CLIENT_ID")
    redirect_uri = "#{conn.scheme}://#{conn.host}:#{conn.port}/api/v1/auth/apple/callback"
    scope = "name email"

    url =
      "https://appleid.apple.com/auth/authorize?client_id=#{client_id}&redirect_uri=#{URI.encode_www_form(redirect_uri)}&response_type=code&response_mode=form_post&scope=#{URI.encode_www_form(scope)}"

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
        schema: %OpenApiSpex.Schema{type: :string, enum: ["discord", "apple"]},
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
                access_token: %OpenApiSpex.Schema{
                  type: :string,
                  description: "JWT access token (15 min)"
                },
                refresh_token: %OpenApiSpex.Schema{
                  type: :string,
                  description: "JWT refresh token (30 days)"
                },
                token_type: %OpenApiSpex.Schema{type: :string, description: "Token type"},
                expires_in: %OpenApiSpex.Schema{
                  type: :integer,
                  description: "Seconds until access token expires"
                },
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
              access_token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
              refresh_token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
              token_type: "Bearer",
              expires_in: 900,
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
            {:ok, access_token, _access_claims} =
              Guardian.encode_and_sign(user, %{}, token_type: "access")

            {:ok, refresh_token, _refresh_claims} =
              Guardian.encode_and_sign(user, %{}, token_type: "refresh", ttl: {30, :days})

            json(conn, %{
              data: %{
                access_token: access_token,
                refresh_token: refresh_token,
                token_type: "Bearer",
                expires_in: 900,
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

  def api_callback(conn, %{"provider" => "apple", "code" => _code}) do
    # For Apple Sign In, we use Ueberauth strategy which handles the JWT verification
    # Apple returns user info differently - they only send it on first authorization
    # After that, we only get the user identifier (sub claim in ID token)

    # Note: Full Apple Sign In implementation with ueberauth_apple handles the
    # ID token verification, so we can extract user info from the Ueberauth callback
    # For API flow, clients should use the browser flow or implement their own
    # client-side Apple Sign In and send us the validated identity token

    conn
    |> put_status(:not_implemented)
    |> json(%{
      error: "Apple Sign In API flow not fully implemented",
      message:
        "Please use the browser OAuth flow at /auth/apple or implement client-side Apple Sign In"
    })
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
