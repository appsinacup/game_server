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
    # Log the full failure details so we can debug provider-specific issues in prod
    require Logger
    failure = conn.assigns[:ueberauth_failure]
    Logger.error("Ueberauth failure: #{inspect(failure)}")

    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: ~p"/users/log-in")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, %{"provider" => "discord"}) do
    user_params = %{
      email: auth.info.email,
      discord_id: auth.uid,
      profile_url: auth.info.image
    }

    require Logger
    Logger.info("Discord OAuth user params: #{inspect(user_params)}")

    # If a user is already logged in, link Discord to their account instead
    case conn.assigns[:current_scope] do
      %{:user => current_user} ->
        case Accounts.link_account(
               current_user,
               user_params,
               :discord_id,
               &GameServer.Accounts.User.discord_oauth_changeset/2
             ) do
          {:ok, _user} ->
            conn
            |> put_flash(:info, "Linked Discord to your account.")
            |> redirect(to: ~p"/users/settings")

          {:error, {:conflict, other_user}} ->
            Logger.warning("Discord already linked to another user id=#{other_user.id}")

            conn
            |> put_flash(
              :error,
              "Discord is already linked to another account. You can delete the conflicting account on this page if it belongs to you."
            )
            |> redirect(
              to: ~p"/users/settings?conflict_provider=discord&conflict_user_id=#{other_user.id}"
            )

          {:error, changeset} ->
            Logger.error("Failed to link Discord: #{inspect(changeset.errors)}")

            conn
            |> put_flash(:error, "Failed to link Discord account.")
            |> redirect(to: ~p"/users/settings")
        end

      _ ->
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
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, %{"provider" => "google"}) do
    user_params = %{
      email: auth.info.email,
      google_id: auth.uid
    }

    require Logger
    Logger.info("Google OAuth user params: #{inspect(user_params)}")

    case conn.assigns[:current_scope] do
      %{:user => current_user} ->
        case Accounts.link_account(
               current_user,
               user_params,
               :google_id,
               &GameServer.Accounts.User.google_oauth_changeset/2
             ) do
          {:ok, _user} ->
            conn
            |> put_flash(:info, "Linked Google to your account.")
            |> redirect(to: ~p"/users/settings")

          {:error, {:conflict, other_user}} ->
            Logger.warning("Google already linked to another user id=#{other_user.id}")

            conn
            |> put_flash(
              :error,
              "Google is already linked to another account. You can delete the conflicting account on this page if it belongs to you."
            )
            |> redirect(
              to: ~p"/users/settings?conflict_provider=google&conflict_user_id=#{other_user.id}"
            )

          {:error, changeset} ->
            Logger.error("Failed to link Google: #{inspect(changeset.errors)}")

            conn
            |> put_flash(:error, "Failed to link Google account.")
            |> redirect(to: ~p"/users/settings")
        end

      _ ->
        case Accounts.find_or_create_from_google(user_params) do
          {:ok, user} ->
            conn
            |> put_flash(:info, "Successfully authenticated with Google.")
            |> UserAuth.log_in_user(user)

          {:error, changeset} ->
            Logger.error("Failed to create user from Google: #{inspect(changeset.errors)}")

            conn
            |> put_flash(:error, "Failed to create or update user account.")
            |> redirect(to: ~p"/users/log-in")
        end
    end
  end

  # Apple browser OAuth flow
  # Apple behaves differently (often returns name/email only on first auth), so
  # we explicitly handle it here and log details to make prod debugging easier.
  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, %{"provider" => "apple"}) do
    user_params = %{
      email: auth.info.email,
      apple_id: auth.uid
    }

    require Logger

    Logger.info(
      "Apple OAuth user params: #{inspect(user_params)} auth_extra=#{inspect(auth.extra)}"
    )

    case conn.assigns[:current_scope] do
      %{:user => current_user} ->
        case Accounts.link_account(
               current_user,
               user_params,
               :apple_id,
               &GameServer.Accounts.User.apple_oauth_changeset/2
             ) do
          {:ok, _user} ->
            conn
            |> put_flash(:info, "Linked Apple to your account.")
            |> redirect(to: ~p"/users/settings")

          {:error, {:conflict, other_user}} ->
            Logger.warning("Apple already linked to another user id=#{other_user.id}")

            conn
            |> put_flash(
              :error,
              "Apple is already linked to another account. You can delete the conflicting account on this page if it belongs to you."
            )
            |> redirect(
              to: ~p"/users/settings?conflict_provider=apple&conflict_user_id=#{other_user.id}"
            )

          {:error, changeset} ->
            Logger.error("Failed to link Apple: #{inspect(changeset.errors)}")

            conn
            |> put_flash(:error, "Failed to link Apple account.")
            |> redirect(to: ~p"/users/settings")
        end

      _ ->
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
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, %{"provider" => "facebook"}) do
    user_params = %{
      email: auth.info.email,
      facebook_id: auth.uid
    }

    require Logger
    Logger.info("Facebook OAuth user params: #{inspect(user_params)}")

    case conn.assigns[:current_scope] do
      %{:user => current_user} ->
        case Accounts.link_account(
               current_user,
               user_params,
               :facebook_id,
               &GameServer.Accounts.User.facebook_oauth_changeset/2
             ) do
          {:ok, _user} ->
            conn
            |> put_flash(:info, "Linked Facebook to your account.")
            |> redirect(to: ~p"/users/settings")

          {:error, {:conflict, other_user}} ->
            Logger.warning("Facebook already linked to another user id=#{other_user.id}")

            conn
            |> put_flash(
              :error,
              "Facebook is already linked to another account. You can delete the conflicting account on this page if it belongs to you."
            )
            |> redirect(
              to: ~p"/users/settings?conflict_provider=facebook&conflict_user_id=#{other_user.id}"
            )

          {:error, changeset} ->
            Logger.error("Failed to link Facebook: #{inspect(changeset.errors)}")

            conn
            |> put_flash(:error, "Failed to link Facebook account.")
            |> redirect(to: ~p"/users/settings")
        end

      _ ->
        case Accounts.find_or_create_from_facebook(user_params) do
          {:ok, user} ->
            conn
            |> put_flash(:info, "Successfully authenticated with Facebook.")
            |> UserAuth.log_in_user(user)

          {:error, changeset} ->
            Logger.error("Failed to create user from Facebook: #{inspect(changeset.errors)}")

            conn
            |> put_flash(:error, "Failed to create or update user account.")
            |> redirect(to: ~p"/users/log-in")
        end
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
        schema: %OpenApiSpex.Schema{
          type: :string,
          enum: ["discord", "apple", "google", "facebook"]
        },
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

  def api_request(conn, %{"provider" => "google"}) do
    # Generate the Google OAuth URL
    client_id = System.get_env("GOOGLE_CLIENT_ID")
    redirect_uri = "#{conn.scheme}://#{conn.host}:#{conn.port}/api/v1/auth/google/callback"
    scope = "email profile"

    url =
      "https://accounts.google.com/o/oauth2/v2/auth?client_id=#{client_id}&redirect_uri=#{URI.encode_www_form(redirect_uri)}&response_type=code&scope=#{URI.encode_www_form(scope)}&access_type=offline"

    json(conn, %{authorization_url: url})
  end

  def api_request(conn, %{"provider" => "facebook"}) do
    # Generate the Facebook OAuth URL
    client_id = System.get_env("FACEBOOK_CLIENT_ID")
    redirect_uri = "#{conn.scheme}://#{conn.host}:#{conn.port}/api/v1/auth/facebook/callback"
    scope = "email"

    url =
      "https://www.facebook.com/v18.0/dialog/oauth?client_id=#{client_id}&redirect_uri=#{URI.encode_www_form(redirect_uri)}&response_type=code&scope=#{URI.encode_www_form(scope)}"

    json(conn, %{authorization_url: url})
  end

  operation(:api_callback,
    summary: "API OAuth callback",
    description:
      "Handles OAuth callback and returns user token. If the request is authenticated (Authorization: Bearer <token>) this endpoint will attempt to link the provider to the current API user instead of creating a new account.",
    tags: ["Authentication"],
    parameters: [
      provider: [
        in: :path,
        name: "provider",
        schema: %OpenApiSpex.Schema{
          type: :string,
          enum: ["discord", "apple", "google", "facebook"]
        },
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
                    profile_url: %OpenApiSpex.Schema{type: :string}
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
              user: %{
                id: 1,
                email: "user@example.com",
                profile_url: "https://cdn.discordapp.com/avatars/123/abc.png"
              }
            }
          }
        }
      },
      bad_request: {"OAuth error", "application/json", nil},
      conflict:
        {"Provider already linked", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{
             error: %OpenApiSpex.Schema{type: :string},
             conflict_user_id: %OpenApiSpex.Schema{type: :integer}
           }
         }}
    ]
  )

  def api_callback(conn, %{"provider" => "discord", "code" => code}) do
    # Exchange code for access token
    client_id = System.get_env("DISCORD_CLIENT_ID")
    client_secret = System.get_env("DISCORD_CLIENT_SECRET")
    redirect_uri = "#{conn.scheme}://#{conn.host}:#{conn.port}/api/v1/auth/discord/callback"

    exchanger = Application.get_env(:game_server, :oauth_exchanger, GameServer.OAuth.Exchanger)

    case exchanger.exchange_discord_code(code, client_id, client_secret, redirect_uri) do
      {:ok, user_info} ->
        user_params = %{
          email: user_info["email"],
          discord_id: user_info["id"],
          profile_url:
            (user_info["avatar"] &&
               "https://cdn.discordapp.com/avatars/#{user_info["id"]}/#{user_info["avatar"]}.png") ||
              nil
        }

        # If the request includes a bearer token, attempt to link the provider
        # to the currently authenticated API user (if any). Otherwise, create
        # or find a user and return tokens as before.
        case get_req_header(conn, "authorization") do
          ["Bearer " <> token] ->
            case Guardian.resource_from_token(token) do
              {:ok, current_user, _claims} ->
                case Accounts.link_account(
                       current_user,
                       user_params,
                       :discord_id,
                       &GameServer.Accounts.User.discord_oauth_changeset/2
                     ) do
                  {:ok, user} ->
                    # return the updated user
                    json(conn, %{
                      data: %{
                        user: %{id: user.id, email: user.email, profile_url: user.profile_url},
                        message: "Linked"
                      }
                    })

                  {:error, {:conflict, other_user}} ->
                    conn
                    |> put_status(:conflict)
                    |> json(%{error: "conflict", conflict_user_id: other_user.id})

                  {:error, changeset} ->
                    conn
                    |> put_status(:bad_request)
                    |> json(%{error: "Failed to link provider", details: changeset.errors})
                end

              _ ->
                # No valid token -> fallback to create/find
                do_find_or_create_discord(conn, user_params)
            end

          _ ->
            do_find_or_create_discord(conn, user_params)
        end
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

  def api_callback(conn, %{"provider" => "google", "code" => code}) do
    # Exchange code for access token
    client_id = System.get_env("GOOGLE_CLIENT_ID")
    client_secret = System.get_env("GOOGLE_CLIENT_SECRET")
    redirect_uri = "#{conn.scheme}://#{conn.host}:#{conn.port}/api/v1/auth/google/callback"

    exchanger = Application.get_env(:game_server, :oauth_exchanger, GameServer.OAuth.Exchanger)

    case exchanger.exchange_google_code(code, client_id, client_secret, redirect_uri) do
      {:ok, user_info} ->
        user_params = %{
          email: user_info["email"],
          google_id: user_info["id"]
        }

        case get_req_header(conn, "authorization") do
          ["Bearer " <> token] ->
            case Guardian.resource_from_token(token) do
              {:ok, current_user, _claims} ->
                case Accounts.link_account(
                       current_user,
                       user_params,
                       :google_id,
                       &GameServer.Accounts.User.google_oauth_changeset/2
                     ) do
                  {:ok, user} ->
                    json(conn, %{
                      data: %{user: %{id: user.id, email: user.email}, message: "Linked"}
                    })

                  {:error, {:conflict, other_user}} ->
                    conn
                    |> put_status(:conflict)
                    |> json(%{error: "conflict", conflict_user_id: other_user.id})

                  {:error, changeset} ->
                    conn
                    |> put_status(:bad_request)
                    |> json(%{error: "Failed to link provider", details: changeset.errors})
                end

              _ ->
                do_find_or_create_google(conn, user_params)
            end

          _ ->
            do_find_or_create_google(conn, user_params)
        end

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "OAuth failed", details: reason})
    end
  end

  def api_callback(conn, %{"provider" => "facebook", "code" => code}) do
    # Exchange code for access token
    client_id = System.get_env("FACEBOOK_CLIENT_ID")
    client_secret = System.get_env("FACEBOOK_CLIENT_SECRET")
    redirect_uri = "#{conn.scheme}://#{conn.host}:#{conn.port}/api/v1/auth/facebook/callback"

    exchanger = Application.get_env(:game_server, :oauth_exchanger, GameServer.OAuth.Exchanger)

    case exchanger.exchange_facebook_code(code, client_id, client_secret, redirect_uri) do
      {:ok, user_info} ->
        user_params = %{
          email: user_info["email"],
          facebook_id: user_info["id"]
        }

        case get_req_header(conn, "authorization") do
          ["Bearer " <> token] ->
            case Guardian.resource_from_token(token) do
              {:ok, current_user, _claims} ->
                case Accounts.link_account(
                       current_user,
                       user_params,
                       :facebook_id,
                       &GameServer.Accounts.User.facebook_oauth_changeset/2
                     ) do
                  {:ok, user} ->
                    json(conn, %{
                      data: %{user: %{id: user.id, email: user.email}, message: "Linked"}
                    })

                  {:error, {:conflict, other_user}} ->
                    conn
                    |> put_status(:conflict)
                    |> json(%{error: "conflict", conflict_user_id: other_user.id})

                  {:error, changeset} ->
                    conn
                    |> put_status(:bad_request)
                    |> json(%{error: "Failed to link provider", details: changeset.errors})
                end

              _ ->
                do_find_or_create_facebook(conn, user_params)
            end

          _ ->
            do_find_or_create_facebook(conn, user_params)
        end

      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "OAuth failed", details: reason})
    end
  end

  operation(:api_conflict_delete,
    summary: "Delete conflicting provider account",
    description:
      "Deletes a conflicting account that owns a provider ID when allowed (must be authenticated). Only allowed when the conflicting account either has no password (provider-only) or has the same email as the current user.",
    tags: ["Authentication"],
    parameters: [
      provider: [
        in: :path,
        name: "provider",
        schema: %OpenApiSpex.Schema{
          type: :string,
          enum: ["discord", "apple", "google", "facebook"]
        },
        required: true
      ],
      conflict_user_id: [
        in: :query,
        name: "conflict_user_id",
        schema: %OpenApiSpex.Schema{type: :integer},
        required: true
      ]
    ],
    responses: [
      ok: {"Deleted", "application/json", %OpenApiSpex.Schema{type: :object}},
      bad_request: {"Bad Request", "application/json", %OpenApiSpex.Schema{type: :object}},
      unauthorized: {"Unauthorized", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def api_conflict_delete(conn, %{"provider" => _provider, "conflict_user_id" => conflict_user_id}) do
    # Delete conflicting account via API (authenticated)
    current = conn.assigns.current_scope.user

    case Integer.parse(conflict_user_id) do
      {id, ""} ->
        case Accounts.get_user!(id) do
          %Accounts.User{} = other_user ->
            cond do
              other_user.id == current.id ->
                conn
                |> put_status(:bad_request)
                |> json(%{error: "Cannot delete your own logged-in account"})

              (other_user.email || "") |> String.downcase() ==
                (current.email || "") |> String.downcase() and
                  (other_user.email || "") != "" ->
                case Accounts.delete_user(other_user) do
                  {:ok, _} ->
                    json(conn, %{message: "deleted"})

                  {:error, _} ->
                    conn |> put_status(:bad_request) |> json(%{error: "Failed to delete account"})
                end

              other_user.hashed_password == nil ->
                case Accounts.delete_user(other_user) do
                  {:ok, _} ->
                    json(conn, %{message: "deleted"})

                  {:error, _} ->
                    conn |> put_status(:bad_request) |> json(%{error: "Failed to delete account"})
                end

              true ->
                conn
                |> put_status(:bad_request)
                |> json(%{error: "Cannot delete an account you do not own"})
            end

          _ ->
            conn |> put_status(:bad_request) |> json(%{error: "Account not found"})
        end

      :error ->
        conn |> put_status(:bad_request) |> json(%{error: "invalid id"})
    end
  end

  defp do_find_or_create_discord(conn, user_params) do
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
              profile_url: user.profile_url
            }
          }
        })

      {:error, changeset} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Failed to create or update user account", details: changeset.errors})
    end
  end

  defp do_find_or_create_google(conn, user_params) do
    case Accounts.find_or_create_from_google(user_params) do
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
              email: user.email
            }
          }
        })

      {:error, changeset} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Failed to create or update user account", details: changeset.errors})
    end
  end

  defp do_find_or_create_facebook(conn, user_params) do
    case Accounts.find_or_create_from_facebook(user_params) do
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
              email: user.email
            }
          }
        })

      {:error, changeset} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Failed to create or update user account", details: changeset.errors})
    end
  end

  # OAuth HTTP exchange is handled by GameServer.OAuth.Exchanger
end
