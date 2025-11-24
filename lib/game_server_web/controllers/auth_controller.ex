defmodule GameServerWeb.AuthController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GameServer.Accounts
  alias GameServerWeb.UserAuth
  alias GameServerWeb.Auth.Guardian

  # Browser OAuth request - redirects to provider
  def request(conn, %{"provider" => "discord"}) do
    client_id = System.get_env("DISCORD_CLIENT_ID")
    base = GameServerWeb.Endpoint.url()
    redirect_uri = "#{base}/auth/discord/callback"
    scope = "identify email"

    url =
      "https://discord.com/oauth2/authorize?client_id=#{client_id}&redirect_uri=#{URI.encode_www_form(redirect_uri)}&response_type=code&scope=#{URI.encode_www_form(scope)}"

    redirect(conn, external: url)
  end

  def request(conn, %{"provider" => "google"}) do
    client_id = System.get_env("GOOGLE_CLIENT_ID")
    base = GameServerWeb.Endpoint.url()
    redirect_uri = "#{base}/auth/google/callback"
    scope = "email profile"

    url =
      "https://accounts.google.com/o/oauth2/v2/auth?client_id=#{client_id}&redirect_uri=#{URI.encode_www_form(redirect_uri)}&response_type=code&scope=#{URI.encode_www_form(scope)}&access_type=offline"

    redirect(conn, external: url)
  end

  def request(conn, %{"provider" => "facebook"}) do
    client_id = System.get_env("FACEBOOK_CLIENT_ID")
    base = GameServerWeb.Endpoint.url()
    redirect_uri = "#{base}/auth/facebook/callback"
    scope = "email"

    url =
      "https://www.facebook.com/v18.0/dialog/oauth?client_id=#{client_id}&redirect_uri=#{URI.encode_www_form(redirect_uri)}&response_type=code&scope=#{URI.encode_www_form(scope)}"

    redirect(conn, external: url)
  end

  def request(conn, %{"provider" => "apple"}) do
    client_id = System.get_env("APPLE_CLIENT_ID")
    base = GameServerWeb.Endpoint.url()
    redirect_uri = "#{base}/auth/apple/callback"
    scope = "name email"

    url =
      "https://appleid.apple.com/auth/authorize?client_id=#{client_id}&redirect_uri=#{URI.encode_www_form(redirect_uri)}&response_type=code&response_mode=form_post&scope=#{URI.encode_www_form(scope)}"

    redirect(conn, external: url)
  end

  # Unified OAuth callback - handles both browser and API flows
  # API flows include a 'state' parameter with session_id
  # Browser flows don't have state
  def callback(conn, %{"provider" => "discord", "code" => code} = params) do
    require Logger
    exchanger = Application.get_env(:game_server, :oauth_exchanger, GameServer.OAuth.Exchanger)
    client_id = System.get_env("DISCORD_CLIENT_ID")
    secret = System.get_env("DISCORD_CLIENT_SECRET")
    base = GameServerWeb.Endpoint.url()
    redirect_uri = "#{base}/auth/discord/callback"

    case exchanger.exchange_discord_code(code, client_id, secret, redirect_uri) do
      {:ok, %{"id" => discord_id, "email" => email} = response} ->
        avatar = response["avatar"]

        user_params = %{
          email: email,
          discord_id: discord_id,
          profile_url:
            if(avatar,
              do: "https://cdn.discordapp.com/avatars/#{discord_id}/#{avatar}.png",
              else: nil
            )
        }

        case params["state"] do
          nil ->
            # Browser flow - no state parameter
            handle_browser_discord_callback(conn, user_params)

          session_id ->
            # API flow - has state parameter with session_id
            do_find_or_create_discord_for_session(conn, user_params, session_id)
        end

      {:error, error} ->
        Logger.error("Discord OAuth exchange failed: #{inspect(error)}")

        case params["state"] do
          nil ->
            conn
            |> put_flash(:error, "Failed to authenticate with Discord.")
            |> redirect(to: ~p"/users/log-in")

          session_id ->
            GameServer.OAuthSessions.create_session(session_id, %{
              status: "error",
              data: %{details: inspect(error)}
            })

            redirect(conn, to: ~p"/auth/success?session_id=#{session_id}")
        end
    end
  end

  def callback(conn, %{"provider" => "google", "code" => code} = params) do
    require Logger
    exchanger = Application.get_env(:game_server, :oauth_exchanger, GameServer.OAuth.Exchanger)
    client_id = System.get_env("GOOGLE_CLIENT_ID")
    secret = System.get_env("GOOGLE_CLIENT_SECRET")
    base = GameServerWeb.Endpoint.url()
    redirect_uri = "#{base}/auth/google/callback"

    case exchanger.exchange_google_code(code, client_id, secret, redirect_uri) do
      {:ok, %{"id" => google_id, "email" => email}} ->
        user_params = %{email: email, google_id: google_id}

        case params["state"] do
          nil ->
            # Browser flow
            handle_browser_google_callback(conn, user_params)

          session_id ->
            # API flow
            do_find_or_create_google_for_session(conn, user_params, session_id)
        end

      {:error, error} ->
        Logger.error("Google OAuth exchange failed: #{inspect(error)}")

        case params["state"] do
          nil ->
            conn
            |> put_flash(:error, "Failed to authenticate with Google.")
            |> redirect(to: ~p"/users/log-in")

          session_id ->
            GameServer.OAuthSessions.create_session(session_id, %{
              status: "error",
              data: %{details: inspect(error)}
            })

            redirect(conn, to: ~p"/auth/success?session_id=#{session_id}")
        end
    end
  end

  def callback(conn, %{"provider" => "facebook", "code" => code} = params) do
    require Logger
    exchanger = Application.get_env(:game_server, :oauth_exchanger, GameServer.OAuth.Exchanger)
    client_id = System.get_env("FACEBOOK_CLIENT_ID")
    secret = System.get_env("FACEBOOK_CLIENT_SECRET")
    base = GameServerWeb.Endpoint.url()
    redirect_uri = "#{base}/auth/facebook/callback"

    case exchanger.exchange_facebook_code(code, client_id, secret, redirect_uri) do
      {:ok, %{"id" => facebook_id} = user_info} ->
        # Facebook may not return email if user hasn't granted permission
        email = user_info["email"]
        user_params = %{email: email, facebook_id: facebook_id}

        case params["state"] do
          nil ->
            # Browser flow
            handle_browser_facebook_callback(conn, user_params)

          session_id ->
            # API flow
            do_find_or_create_facebook_for_session(conn, user_params, session_id)
        end

      {:error, error} ->
        Logger.error("Facebook OAuth exchange failed: #{inspect(error)}")

        case params["state"] do
          nil ->
            conn
            |> put_flash(:error, "Failed to authenticate with Facebook.")
            |> redirect(to: ~p"/users/log-in")

          session_id ->
            GameServer.OAuthSessions.create_session(session_id, %{
              status: "error",
              data: %{details: inspect(error)}
            })

            redirect(conn, to: ~p"/auth/success?session_id=#{session_id}")
        end
    end
  end

  def callback(conn, %{"provider" => "apple", "code" => code} = params) do
    require Logger
    Logger.info("Apple OAuth callback received. Params: #{inspect(Map.keys(params))}")

    exchanger = Application.get_env(:game_server, :oauth_exchanger, GameServer.OAuth.Exchanger)
    client_id = System.get_env("APPLE_CLIENT_ID")
    client_secret = GameServer.Apple.client_secret()
    base = GameServerWeb.Endpoint.url()
    redirect_uri = "#{base}/auth/apple/callback"

    Logger.info(
      "Apple OAuth: Exchanging code. Client ID: #{client_id}, Redirect URI: #{redirect_uri}"
    )

    case exchanger.exchange_apple_code(code, client_id, client_secret, redirect_uri) do
      {:ok, %{"sub" => apple_id} = user_info} ->
        Logger.info("Apple OAuth: Successfully exchanged code. User info: #{inspect(user_info)}")
        email = user_info["email"]
        user_params = %{email: email, apple_id: apple_id}

        case params["state"] do
          nil ->
            Logger.info("Apple OAuth: Browser flow")
            # Browser flow
            handle_browser_apple_callback(conn, user_params)

          session_id ->
            Logger.info("Apple OAuth: API flow with session_id: #{session_id}")
            # API flow
            do_find_or_create_apple_for_session(conn, user_params, session_id)
        end

      {:error, error} ->
        Logger.error("Apple OAuth exchange failed: #{inspect(error)}")

        case params["state"] do
          nil ->
            conn
            |> put_flash(:error, "Failed to authenticate with Apple.")
            |> redirect(to: ~p"/users/log-in")

          session_id ->
            GameServer.OAuthSessions.create_session(session_id, %{
              status: "error",
              data: %{details: inspect(error)}
            })

            redirect(conn, to: ~p"/auth/success?session_id=#{session_id}")
        end
    end
  end

  # Catch-all for missing code or unsupported providers
  def callback(conn, params) do
    require Logger

    Logger.error(
      "OAuth callback with invalid params. Provider: #{params["provider"]}, Params: #{inspect(params)}"
    )

    conn
    |> put_flash(:error, "Failed to authenticate.")
    |> redirect(to: ~p"/users/log-in")
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "You have been logged out!")
    |> UserAuth.log_out_user()
  end

  # API OAuth endpoints
  operation(:api_request,
    operation_id: "oauth_request",
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
            },
            session_id: %OpenApiSpex.Schema{
              type: :string,
              description: "Unique session ID to track this OAuth request"
            }
          },
          example: %{
            authorization_url: "https://discord.com/oauth2/authorize?...",
            session_id: "abc123..."
          }
        }
      }
    ]
  )

  def api_request(conn, %{"provider" => "discord"}) do
    # Generate a unique session ID for this OAuth request
    session_id = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

    # Persist session in DB for polling by API clients
    GameServer.OAuthSessions.create_session(session_id, %{provider: "discord", status: "pending"})

    # Generate the Discord OAuth URL with state parameter
    client_id = System.get_env("DISCORD_CLIENT_ID")
    # Use the unified callback endpoint
    base = GameServerWeb.Endpoint.url()
    redirect_uri = "#{base}/auth/discord/callback"
    scope = "identify email"
    state = session_id

    url =
      "https://discord.com/oauth2/authorize?client_id=#{client_id}&redirect_uri=#{URI.encode_www_form(redirect_uri)}&response_type=code&scope=#{URI.encode_www_form(scope)}&state=#{URI.encode_www_form(state)}"

    json(conn, %{authorization_url: url, session_id: session_id})
  end

  def api_request(conn, %{"provider" => "apple"}) do
    # Generate a unique session ID for this OAuth request
    session_id = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

    GameServer.OAuthSessions.create_session(session_id, %{provider: "apple", status: "pending"})

    # Generate the Apple OAuth URL
    client_id = System.get_env("APPLE_CLIENT_ID")
    base = GameServerWeb.Endpoint.url()
    redirect_uri = "#{base}/auth/apple/callback"
    scope = "name email"

    url =
      "https://appleid.apple.com/auth/authorize?client_id=#{client_id}&redirect_uri=#{URI.encode_www_form(redirect_uri)}&response_type=code&response_mode=form_post&scope=#{URI.encode_www_form(scope)}&state=#{URI.encode_www_form(session_id)}"

    json(conn, %{authorization_url: url, session_id: session_id})
  end

  def api_request(conn, %{"provider" => "google"}) do
    # Generate a unique session ID for this OAuth request
    session_id = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

    GameServer.OAuthSessions.create_session(session_id, %{provider: "google", status: "pending"})

    # Generate the Google OAuth URL
    client_id = System.get_env("GOOGLE_CLIENT_ID")
    base = GameServerWeb.Endpoint.url()
    redirect_uri = "#{base}/auth/google/callback"
    scope = "email profile"

    url =
      "https://accounts.google.com/o/oauth2/v2/auth?client_id=#{client_id}&redirect_uri=#{URI.encode_www_form(redirect_uri)}&response_type=code&scope=#{URI.encode_www_form(scope)}&access_type=offline&state=#{URI.encode_www_form(session_id)}"

    json(conn, %{authorization_url: url, session_id: session_id})
  end

  def api_request(conn, %{"provider" => "facebook"}) do
    # Generate a unique session ID for this OAuth request
    session_id = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

    GameServer.OAuthSessions.create_session(session_id, %{provider: "facebook", status: "pending"})

    # Generate the Facebook OAuth URL
    client_id = System.get_env("FACEBOOK_CLIENT_ID")
    base = GameServerWeb.Endpoint.url()
    redirect_uri = "#{base}/auth/facebook/callback"
    scope = "email"

    url =
      "https://www.facebook.com/v18.0/dialog/oauth?client_id=#{client_id}&redirect_uri=#{URI.encode_www_form(redirect_uri)}&response_type=code&scope=#{URI.encode_www_form(scope)}&state=#{URI.encode_www_form(session_id)}"

    json(conn, %{authorization_url: url, session_id: session_id})
  end

  operation(:api_conflict_delete,
    operation_id: "oauth_conflict_delete",
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

  operation(:api_session_status,
    operation_id: "oauth_session_status",
    summary: "Get OAuth session status",
    description: "Check the status of an OAuth session for API clients",
    tags: ["Authentication"],
    parameters: [
      session_id: [
        in: :path,
        name: "session_id",
        schema: %OpenApiSpex.Schema{type: :string},
        description: "Session ID from OAuth request",
        required: true
      ]
    ],
    responses: [
      ok: {
        "Session status",
        "application/json",
        %OpenApiSpex.Schema{
          type: :object,
          properties: %{
            status: %OpenApiSpex.Schema{
              type: :string,
              enum: ["pending", "completed", "error", "conflict"],
              description: "Current session status"
            },
            data: %OpenApiSpex.Schema{
              type: :object,
              description: "Session data when completed"
            },
            message: %OpenApiSpex.Schema{
              type: :string,
              description: "Optional status message"
            }
          }
        }
      },
      not_found: {"Session not found", "application/json", nil}
    ]
  )

  def api_session_status(conn, %{"session_id" => session_id}) do
    case GameServer.OAuthSessions.get_session(session_id) do
      %GameServer.OAuthSession{status: status, data: data} ->
        # Return a shape that matches the OpenAPI spec and the generated
        # JavaScript SDK: { status: string, data: { ... } }
        json(conn, %{status: status, data: data || %{}})

      [] ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Session not found"})
    end
  end

  defp handle_browser_google_callback(conn, user_params) do
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
            require Logger
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
            require Logger
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
            require Logger
            Logger.error("Failed to create user from Google: #{inspect(changeset.errors)}")

            conn
            |> put_flash(:error, "Failed to create or update user account.")
            |> redirect(to: ~p"/users/log-in")
        end
    end
  end

  defp handle_browser_facebook_callback(conn, user_params) do
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
            require Logger
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
            require Logger
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
            require Logger
            Logger.error("Failed to create user from Facebook: #{inspect(changeset.errors)}")

            conn
            |> put_flash(:error, "Failed to create or update user account.")
            |> redirect(to: ~p"/users/log-in")
        end
    end
  end

  defp handle_browser_apple_callback(conn, user_params) do
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
            require Logger
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
            require Logger
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
            require Logger
            Logger.error("Failed to create user from Apple: #{inspect(changeset.errors)}")

            conn
            |> put_flash(:error, "Failed to create or update user account.")
            |> redirect(to: ~p"/users/log-in")
        end
    end
  end

  defp handle_browser_discord_callback(conn, user_params) do
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
            require Logger
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
            require Logger
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
            require Logger
            Logger.error("Failed to create user from Discord: #{inspect(changeset.errors)}")

            conn
            |> put_flash(:error, "Failed to create or update user account.")
            |> redirect(to: ~p"/users/log-in")
        end
    end
  end

  defp do_find_or_create_discord_for_session(conn, user_params, session_id) do
    case Accounts.find_or_create_from_discord(user_params) do
      {:ok, user} ->
        {:ok, access_token, _access_claims} =
          Guardian.encode_and_sign(user, %{}, token_type: "access")

        {:ok, refresh_token, _refresh_claims} =
          Guardian.encode_and_sign(user, %{}, token_type: "refresh", ttl: {30, :days})

        # Store tokens in session
        GameServer.OAuthSessions.create_session(session_id, %{
          status: "completed",
          data: %{
            access_token: access_token,
            refresh_token: refresh_token,
            token_type: "Bearer",
            expires_in: 900,
            user: %{id: user.id, email: user.email, profile_url: user.profile_url}
          }
        })

        # Redirect to success page
        redirect(conn, to: ~p"/auth/success?session_id=#{session_id}")

      {:error, changeset} ->
        GameServer.OAuthSessions.create_session(session_id, %{
          status: "error",
          data: %{details: changeset.errors}
        })

        redirect(conn, to: ~p"/auth/success?session_id=#{session_id}")
    end
  end

  defp do_find_or_create_google_for_session(conn, user_params, session_id) do
    case Accounts.find_or_create_from_google(user_params) do
      {:ok, user} ->
        {:ok, access_token, _access_claims} =
          Guardian.encode_and_sign(user, %{}, token_type: "access")

        {:ok, refresh_token, _refresh_claims} =
          Guardian.encode_and_sign(user, %{}, token_type: "refresh", ttl: {30, :days})

        # Store tokens in session
        GameServer.OAuthSessions.create_session(session_id, %{
          status: "completed",
          data: %{
            access_token: access_token,
            refresh_token: refresh_token,
            token_type: "Bearer",
            expires_in: 900,
            user: %{id: user.id, email: user.email}
          }
        })

        # Redirect to success page
        redirect(conn, to: ~p"/auth/success?session_id=#{session_id}")

      {:error, changeset} ->
        GameServer.OAuthSessions.create_session(session_id, %{
          status: "error",
          data: %{details: changeset.errors}
        })

        redirect(conn, to: ~p"/auth/success?session_id=#{session_id}")
    end
  end

  defp do_find_or_create_facebook_for_session(conn, user_params, session_id) do
    case Accounts.find_or_create_from_facebook(user_params) do
      {:ok, user} ->
        {:ok, access_token, _access_claims} =
          Guardian.encode_and_sign(user, %{}, token_type: "access")

        {:ok, refresh_token, _refresh_claims} =
          Guardian.encode_and_sign(user, %{}, token_type: "refresh", ttl: {30, :days})

        # Store tokens in session
        GameServer.OAuthSessions.create_session(session_id, %{
          status: "completed",
          data: %{
            access_token: access_token,
            refresh_token: refresh_token,
            token_type: "Bearer",
            expires_in: 900,
            user: %{id: user.id, email: user.email}
          }
        })

        # Redirect to success page
        redirect(conn, to: ~p"/auth/success?session_id=#{session_id}")

      {:error, changeset} ->
        GameServer.OAuthSessions.create_session(session_id, %{
          status: "error",
          data: %{details: changeset.errors}
        })

        redirect(conn, to: ~p"/auth/success?session_id=#{session_id}")
    end
  end

  defp do_find_or_create_apple_for_session(conn, user_params, session_id) do
    case Accounts.find_or_create_from_apple(user_params) do
      {:ok, user} ->
        {:ok, access_token, _access_claims} =
          Guardian.encode_and_sign(user, %{}, token_type: "access")

        {:ok, refresh_token, _refresh_claims} =
          Guardian.encode_and_sign(user, %{}, token_type: "refresh", ttl: {30, :days})

        # Store tokens in session
        GameServer.OAuthSessions.create_session(session_id, %{
          status: "completed",
          data: %{
            access_token: access_token,
            refresh_token: refresh_token,
            token_type: "Bearer",
            expires_in: 900,
            user: %{id: user.id, email: user.email}
          }
        })

        # Redirect to success page
        redirect(conn, to: ~p"/auth/success?session_id=#{session_id}")

      {:error, changeset} ->
        GameServer.OAuthSessions.create_session(session_id, %{
          status: "error",
          data: %{details: changeset.errors}
        })

        redirect(conn, to: ~p"/auth/success?session_id=#{session_id}")
    end
  end
end
