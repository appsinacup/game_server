defmodule GameServerWeb.AuthController do
  use GameServerWeb, :controller
  use OpenApiSpex.ControllerSpecs
  # Only use Ueberauth for Steam (OpenID), other providers use custom implementation
  plug Ueberauth, only: [:request, :callback], providers: [:steam]

  alias GameServer.Accounts
  alias GameServer.Accounts.User
  alias GameServer.OAuthSessions
  alias GameServerWeb.Auth.Guardian
  alias GameServerWeb.UserAuth

  # Optionally extract current user from JWT in Authorization header.
  # Returns {:ok, user} if valid JWT present, or {:ok, nil} if no JWT or invalid.
  # This allows the same endpoint to handle both login and linking.
  defp maybe_load_user_from_jwt(conn) do
    case Plug.Conn.get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        case Guardian.decode_and_verify(token, %{"typ" => "access"}) do
          {:ok, claims} ->
            case Guardian.resource_from_claims(claims) do
              {:ok, user} -> {:ok, user}
              _ -> {:ok, nil}
            end

          _ ->
            {:ok, nil}
        end

      _ ->
        {:ok, nil}
    end
  end

  # Create an OAuth session for the API flow.
  # If a JWT is present, stores the user_id in the data map for linking when the callback completes.
  defp create_api_oauth_session(conn, provider) do
    session_id = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

    # Check if user is authenticated - if so, store their ID for linking
    data =
      case maybe_load_user_from_jwt(conn) do
        {:ok, %User{id: user_id}} ->
          %{link_user_id: user_id}

        {:ok, nil} ->
          %{}
      end

    GameServer.OAuthSessions.create_session(session_id, %{
      provider: provider,
      status: "pending",
      data: data
    })

    session_id
  end

  # Handle the session-based OAuth callback (browser redirect flow).
  # If link_user_id is present in the session data, links the provider instead of login.
  defp handle_session_oauth_callback(
         conn,
         session_id,
         user_params,
         provider_id_field,
         changeset_fn,
         find_or_create_fn
       ) do
    # Check if this session has a link_user_id in its data (meaning we should link, not login)
    session = OAuthSessions.get_session(session_id)
    link_user_id = session && get_in(session.data, ["link_user_id"])

    if is_integer(link_user_id) do
      # This is a linking flow
      case Accounts.get_user!(link_user_id) do
        user ->
          case Accounts.link_account(user, user_params, provider_id_field, changeset_fn) do
            {:ok, _updated_user} ->
              OAuthSessions.create_session(session_id, %{
                status: "completed",
                data: %{linked: true, provider: Atom.to_string(provider_id_field)}
              })

              redirect(conn, to: ~p"/auth/success?session_id=#{session_id}")

            {:error, {:conflict, _other_user}} ->
              OAuthSessions.create_session(session_id, %{
                status: "error",
                data: %{
                  error: "provider_already_linked",
                  message: "This provider is already linked to another account"
                }
              })

              redirect(conn, to: ~p"/auth/success?session_id=#{session_id}")

            {:error, changeset} ->
              OAuthSessions.create_session(session_id, %{
                status: "error",
                data: %{error: "link_failed", details: inspect(changeset.errors)}
              })

              redirect(conn, to: ~p"/auth/success?session_id=#{session_id}")
          end
      end
    else
      # Normal login/create flow
      case find_or_create_fn.(user_params) do
        {:ok, user} ->
          {:ok, access_token, _} = Guardian.encode_and_sign(user, %{}, token_type: "access")

          {:ok, refresh_token, _} =
            Guardian.encode_and_sign(user, %{}, token_type: "refresh", ttl: {30, :days})

          OAuthSessions.create_session(session_id, %{
            status: "completed",
            data: %{
              access_token: access_token,
              refresh_token: refresh_token,
              expires_in: 900,
              user_id: user.id
            }
          })

          redirect(conn, to: ~p"/auth/success?session_id=#{session_id}")

        {:error, changeset} ->
          OAuthSessions.create_session(session_id, %{
            status: "error",
            data: %{details: changeset.errors}
          })

          redirect(conn, to: ~p"/auth/success?session_id=#{session_id}")
      end
    end
  rescue
    Ecto.NoResultsError ->
      OAuthSessions.create_session(session_id, %{
        status: "error",
        data: %{error: "user_not_found", message: "The user to link to was not found"}
      })

      redirect(conn, to: ~p"/auth/success?session_id=#{session_id}")
  end

  # Handle linking a provider to an existing user (API flow)
  defp handle_api_link(conn, user, user_params, provider_id_field, changeset_fn) do
    case Accounts.link_account(user, user_params, provider_id_field, changeset_fn) do
      {:ok, _updated_user} ->
        json(conn, %{data: %{linked: true, provider: Atom.to_string(provider_id_field)}})

      {:error, {:conflict, _other_user}} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          error: "provider_already_linked",
          message: "This provider is already linked to another account"
        })

      {:error, changeset} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "link_failed", details: inspect(changeset.errors)})
    end
  end

  # Handle login/create flow (API) - returns JWT tokens
  defp handle_api_login(conn, find_or_create_fn, user_params) do
    case find_or_create_fn.(user_params) do
      {:ok, user} ->
        {:ok, access_token, _} = Guardian.encode_and_sign(user, %{}, token_type: "access")

        {:ok, refresh_token, _} =
          Guardian.encode_and_sign(user, %{}, token_type: "refresh", ttl: {30, :days})

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
        |> json(%{error: "create_failed", details: changeset.errors})
    end
  end

  # Show a helpful dev-mode flash for browser flows when exchanges fail
  defp browser_oauth_error_redirect(conn, provider, error) do
    # Log the error at controller level as well
    require Logger

    Logger.error(
      "#{String.capitalize(provider)} OAuth exchange failed (controller): #{inspect(error)}"
    )

    msg =
      if Mix.env() == :dev do
        "Failed to authenticate with #{String.capitalize(provider)}: #{inspect(error)}"
      else
        "Failed to authenticate with #{String.capitalize(provider)}."
      end

    conn
    |> put_flash(:error, msg)
    |> redirect(to: ~p"/users/log-in")
  end

  # Browser OAuth request - redirects to provider
  operation(:request,
    operation_id: "oauth_request_browser",
    summary: "Browser OAuth request",
    description: "Initiate a browser OAuth flow and redirect the user to the provider",
    tags: ["Authentication"],
    parameters: [
      provider: [
        in: :path,
        name: "provider",
        schema: %OpenApiSpex.Schema{
          type: :string,
          enum: ["discord", "apple", "google", "facebook", "steam"]
        },
        required: true
      ]
    ],
    responses: [
      found: {"Redirect to provider", "text/html", %OpenApiSpex.Schema{type: :string}}
    ]
  )

  def request(conn, %{"provider" => "discord"}) do
    cfg = Application.get_env(:ueberauth, Ueberauth.Strategy.Discord.OAuth, [])
    client_id = cfg[:client_id] || System.get_env("DISCORD_CLIENT_ID")
    base = GameServerWeb.Endpoint.url()
    redirect_uri = cfg[:redirect_uri] || "#{base}/auth/discord/callback"
    scope = "identify email"

    url =
      "https://discord.com/oauth2/authorize?client_id=#{client_id}&redirect_uri=#{URI.encode_www_form(redirect_uri)}&response_type=code&scope=#{URI.encode_www_form(scope)}"

    redirect(conn, external: url)
  end

  # steam_callback helper is defined with the other callbacks below

  # Steam callback handlers live alongside other provider callbacks below

  def request(conn, %{"provider" => "google"}) do
    cfg = Application.get_env(:ueberauth, Ueberauth.Strategy.Google.OAuth, [])
    client_id = cfg[:client_id] || System.get_env("GOOGLE_CLIENT_ID")
    base = GameServerWeb.Endpoint.url()
    redirect_uri = cfg[:redirect_uri] || "#{base}/auth/google/callback"
    scope = "email profile"

    url =
      "https://accounts.google.com/o/oauth2/v2/auth?client_id=#{client_id}&redirect_uri=#{URI.encode_www_form(redirect_uri)}&response_type=code&scope=#{URI.encode_www_form(scope)}&access_type=offline"

    redirect(conn, external: url)
  end

  def request(conn, %{"provider" => "facebook"}) do
    cfg = Application.get_env(:ueberauth, Ueberauth.Strategy.Facebook.OAuth, [])
    client_id = cfg[:client_id] || System.get_env("FACEBOOK_CLIENT_ID")
    base = GameServerWeb.Endpoint.url()
    redirect_uri = cfg[:redirect_uri] || "#{base}/auth/facebook/callback"
    scope = "email"

    url =
      "https://www.facebook.com/v18.0/dialog/oauth?client_id=#{client_id}&redirect_uri=#{URI.encode_www_form(redirect_uri)}&response_type=code&scope=#{URI.encode_www_form(scope)}"

    redirect(conn, external: url)
  end

  def request(conn, %{"provider" => "apple"}) do
    cfg = Application.get_env(:ueberauth, Ueberauth.Strategy.Apple.OAuth, [])
    client_id = cfg[:client_id] || System.get_env("APPLE_CLIENT_ID")
    base = GameServerWeb.Endpoint.url()
    redirect_uri = cfg[:redirect_uri] || "#{base}/auth/apple/callback"
    scope = "name email"

    url =
      "https://appleid.apple.com/auth/authorize?client_id=#{client_id}&redirect_uri=#{URI.encode_www_form(redirect_uri)}&response_type=code&response_mode=form_post&scope=#{URI.encode_www_form(scope)}"

    redirect(conn, external: url)
  end

  # helper route used for Steam callback routing - delegates into the
  # unified `callback/2` handler by injecting the `provider` param.
  operation(:steam_callback,
    operation_id: "oauth_callback_steam",
    summary: "Steam callback (browser OpenID helper)",
    description:
      "Helper route used for Steam OpenID callbacks. Delegates to `callback/2` with provider=steam.",
    tags: ["Authentication"],
    parameters: [
      state: [
        in: :query,
        name: "state",
        schema: %OpenApiSpex.Schema{type: :string},
        required: false
      ]
    ],
    responses: [
      found: {"Redirect or success page", "text/html", %OpenApiSpex.Schema{type: :string}},
      bad_request: {"Bad request", "text/html", %OpenApiSpex.Schema{type: :string}}
    ]
  )

  def steam_callback(conn, params) do
    callback(conn, Map.put(params, "provider", "steam"))
  end

  operation(:callback,
    operation_id: "oauth_callback_browser",
    summary: "Browser OAuth callback",
    description:
      "Handles provider callback for browser OAuth flows (redirects or shows messages)",
    tags: ["Authentication"],
    parameters: [
      provider: [
        in: :path,
        name: "provider",
        schema: %OpenApiSpex.Schema{type: :string},
        required: true
      ],
      code: [
        in: :query,
        name: "code",
        schema: %OpenApiSpex.Schema{type: :string},
        required: false
      ],
      state: [
        in: :query,
        name: "state",
        schema: %OpenApiSpex.Schema{type: :string},
        required: false
      ]
    ],
    responses: [
      found: {"Redirect or success page", "text/html", %OpenApiSpex.Schema{type: :string}},
      bad_request: {"Bad request", "text/html", %OpenApiSpex.Schema{type: :string}}
    ]
  )

  # Unified OAuth callback - handles both browser and API flows
  # API flows include a 'state' parameter with session_id
  # Browser flows don't have state
  def callback(conn, %{"provider" => "discord", "code" => code} = params) do
    require Logger

    exchanger =
      Application.get_env(:game_server_web, :oauth_exchanger, GameServer.OAuth.Exchanger)

    client_id = System.get_env("DISCORD_CLIENT_ID")
    secret = System.get_env("DISCORD_CLIENT_SECRET")
    base = GameServerWeb.Endpoint.url()
    redirect_uri = "#{base}/auth/discord/callback"

    case exchanger.exchange_discord_code(code, client_id, secret, redirect_uri) do
      {:ok, %{"id" => discord_id, "email" => email} = response} ->
        avatar = response["avatar"]

        display_name = Map.get(response, "global_name") || Map.get(response, "username")

        user_params = %{
          email: email,
          discord_id: discord_id,
          display_name: display_name,
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
            case OAuthSessions.get_session(session_id) do
              nil ->
                # No matching session -> treat like browser flow
                handle_browser_discord_callback(conn, user_params)

              _ ->
                # API flow - has valid session_id
                do_find_or_create_discord_for_session(conn, user_params, session_id)
            end
        end

      {:error, error} ->
        case params["state"] do
          nil ->
            browser_oauth_error_redirect(conn, "discord", error)

          session_id ->
            case OAuthSessions.get_session(session_id) do
              nil ->
                browser_oauth_error_redirect(conn, "discord", error)

              _ ->
                GameServer.OAuthSessions.create_session(session_id, %{
                  status: "error",
                  data: %{details: inspect(error)}
                })

                redirect(conn, to: ~p"/auth/success?session_id=#{session_id}")
            end
        end
    end
  end

  def callback(conn, %{"provider" => "google", "code" => code} = params) do
    require Logger

    exchanger =
      Application.get_env(:game_server_web, :oauth_exchanger, GameServer.OAuth.Exchanger)

    client_id = System.get_env("GOOGLE_CLIENT_ID")
    secret = System.get_env("GOOGLE_CLIENT_SECRET")
    base = GameServerWeb.Endpoint.url()
    redirect_uri = "#{base}/auth/google/callback"

    case exchanger.exchange_google_code(code, client_id, secret, redirect_uri) do
      {:ok, %{"id" => google_id, "email" => email} = user_info} ->
        # Google userinfo often contains a `picture` field with a profile image URL
        picture = Map.get(user_info, "picture")

        # Google userinfo commonly includes the full name under `name`.
        name = Map.get(user_info, "name") || Map.get(user_info, "given_name")

        user_params =
          %{email: email, google_id: google_id, display_name: name}
          |> Map.merge(if(picture, do: %{profile_url: picture}, else: %{}))

        case params["state"] do
          nil ->
            # Browser flow
            handle_browser_google_callback(conn, user_params)

          session_id ->
            case OAuthSessions.get_session(session_id) do
              nil ->
                # No matching session -> treat as browser flow
                handle_browser_google_callback(conn, user_params)

              _ ->
                # API flow
                do_find_or_create_google_for_session(conn, user_params, session_id)
            end
        end

      {:error, error} ->
        case params["state"] do
          nil ->
            browser_oauth_error_redirect(conn, "google", error)

          session_id ->
            case OAuthSessions.get_session(session_id) do
              nil ->
                browser_oauth_error_redirect(conn, "google", error)

              _ ->
                GameServer.OAuthSessions.create_session(session_id, %{
                  status: "error",
                  data: %{details: inspect(error)}
                })

                redirect(conn, to: ~p"/auth/success?session_id=#{session_id}")
            end
        end
    end
  end

  def callback(conn, %{"provider" => "facebook", "code" => code} = params) do
    require Logger

    exchanger =
      Application.get_env(:game_server_web, :oauth_exchanger, GameServer.OAuth.Exchanger)

    client_id = System.get_env("FACEBOOK_CLIENT_ID")
    secret = System.get_env("FACEBOOK_CLIENT_SECRET")
    base = GameServerWeb.Endpoint.url()
    redirect_uri = "#{base}/auth/facebook/callback"

    case exchanger.exchange_facebook_code(code, client_id, secret, redirect_uri) do
      {:ok, %{"id" => facebook_id} = user_info} ->
        # Facebook may not return email if user hasn't granted permission
        email = user_info["email"]

        # Facebook returns picture in nested structure: %{"picture" => %{"data" => %{"url" => url}}}
        profile_url =
          user_info
          |> Map.get("picture", %{})
          |> Map.get("data", %{})
          |> Map.get("url")

        # Facebook exposes a `name` field for the user's full name
        name = Map.get(user_info, "name")

        user_params = %{email: email, facebook_id: facebook_id, display_name: name}

        user_params =
          if(profile_url, do: Map.put(user_params, :profile_url, profile_url), else: user_params)

        case params["state"] do
          nil ->
            # Browser flow
            handle_browser_facebook_callback(conn, user_params)

          session_id ->
            case OAuthSessions.get_session(session_id) do
              nil ->
                # No matching session -> treat as browser flow
                handle_browser_facebook_callback(conn, user_params)

              _ ->
                # API flow
                do_find_or_create_facebook_for_session(conn, user_params, session_id)
            end
        end

      {:error, error} ->
        case params["state"] do
          nil ->
            browser_oauth_error_redirect(conn, "facebook", error)

          session_id ->
            case OAuthSessions.get_session(session_id) do
              nil ->
                browser_oauth_error_redirect(conn, "facebook", error)

              _ ->
                GameServer.OAuthSessions.create_session(session_id, %{
                  status: "error",
                  data: %{details: inspect(error)}
                })

                redirect(conn, to: ~p"/auth/success?session_id=#{session_id}")
            end
        end
    end
  end

  def callback(conn, %{"provider" => "apple", "code" => code} = params) do
    exchanger =
      Application.get_env(:game_server_web, :oauth_exchanger, GameServer.OAuth.Exchanger)

    client_id = System.get_env("APPLE_CLIENT_ID")

    client_secret =
      try do
        GameServer.Apple.client_secret()
      rescue
        _ ->
          # In tests the APPLE_PRIVATE_KEY may be invalid, avoid blowing up the
          # request lifecycle - exchanger implementations / mocks can handle
          # a nil client_secret as needed.
          nil
      end

    base = GameServerWeb.Endpoint.url()
    redirect_uri = "#{base}/auth/apple/callback"

    case exchanger.exchange_apple_code(code, client_id, client_secret, redirect_uri) do
      {:ok, %{"sub" => apple_id} = user_info} ->
        email = user_info["email"]
        # Apple may include name payload in the id_token on first authentication
        name = Map.get(user_info, "name")

        user_params = %{email: email, apple_id: apple_id, display_name: name}

        case params["state"] do
          nil ->
            # Browser flow
            handle_browser_apple_callback(conn, user_params)

          session_id ->
            case OAuthSessions.get_session(session_id) do
              nil ->
                handle_browser_apple_callback(conn, user_params)

              _ ->
                # API flow
                do_find_or_create_apple_for_session(conn, user_params, session_id)
            end
        end

      {:error, error} ->
        case params["state"] do
          nil ->
            browser_oauth_error_redirect(conn, "apple", error)

          session_id ->
            case OAuthSessions.get_session(session_id) do
              nil ->
                browser_oauth_error_redirect(conn, "apple", error)

              _ ->
                GameServer.OAuthSessions.create_session(session_id, %{
                  status: "error",
                  data: %{details: inspect(error)}
                })

                redirect(conn, to: ~p"/auth/success?session_id=#{session_id}")
            end
        end
    end
  end

  def callback(
        %Plug.Conn{assigns: %{ueberauth_auth: auth}} = conn,
        %{"provider" => "steam"} = params
      ) do
    uid = to_string(auth.uid)
    info = auth.info || %{}
    extra = Map.get(auth, :extra) || %{}
    raw_info = Map.get(extra, :raw_info) || %{}
    raw_user = Map.get(raw_info, :user) || %{}

    display_name =
      Map.get(info, :name) ||
        Map.get(info, :nickname) ||
        Map.get(raw_user, :personaname) ||
        Map.get(raw_user, :realname)

    urls = Map.get(info, :urls, %{})
    profile_url = Map.get(urls, :profile) || Map.get(info, :image)

    user_params = %{
      steam_id: uid,
      display_name: display_name,
      profile_url: profile_url
    }

    case params["state"] do
      nil ->
        handle_browser_steam_callback(conn, user_params)

      session_id ->
        case OAuthSessions.get_session(session_id) do
          nil ->
            handle_browser_steam_callback(conn, user_params)

          _ ->
            do_find_or_create_steam_for_session(conn, user_params, session_id)
        end
    end
  end

  def callback(
        %Plug.Conn{assigns: %{ueberauth_failure: failure}} = conn,
        %{"provider" => "steam"} = params
      ) do
    case params["state"] do
      nil ->
        browser_oauth_error_redirect(conn, "steam", failure)

      session_id ->
        case OAuthSessions.get_session(session_id) do
          nil ->
            browser_oauth_error_redirect(conn, "steam", failure)

          _ ->
            GameServer.OAuthSessions.create_session(session_id, %{
              status: "error",
              data: %{details: inspect(failure)}
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
          enum: ["discord", "apple", "google", "facebook", "steam"]
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

  operation(:api_callback,
    operation_id: "oauth_api_callback",
    summary: "API callback / code exchange",
    description:
      "Accepts an OAuth authorization code via the API and returns access/refresh tokens on success. " <>
        "If a valid JWT is provided in the Authorization header, the provider will be **linked** to the authenticated user instead of logging in. " <>
        "For the Steam provider, the `code` field should contain a server-verifiable Steam credential (for example a Steam auth ticket or Steam identifier) and will be validated via the Steam Web API.",
    tags: ["Authentication"],
    parameters: [
      provider: [
        in: :path,
        name: "provider",
        schema: %OpenApiSpex.Schema{type: :string},
        required: true
      ]
    ],
    request_body: {
      "Code exchange or steam payload",
      "application/json",
      %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          code: %OpenApiSpex.Schema{
            type: :string,
            description:
              "Authorization code (for code-based providers). For Steam provider this MUST be a Steam auth ticket (AuthenticateUserTicket) and NOT a steam id."
          }
        }
      }
    },
    responses: [
      ok:
        {"OAuth tokens", "application/json",
         %OpenApiSpex.Schema{
           type: :object,
           properties: %{data: GameServerWeb.Schemas.OAuthSessionData}
         }},
      bad_request: {"Bad request", "application/json", %OpenApiSpex.Schema{type: :object}}
    ]
  )

  def api_request(conn, %{"provider" => "discord"}) do
    # Create session (with optional link_user_id if JWT is present)
    session_id = create_api_oauth_session(conn, "discord")

    # Generate the Discord OAuth URL with state parameter
    client_id = System.get_env("DISCORD_CLIENT_ID")
    base = GameServerWeb.Endpoint.url()
    redirect_uri = "#{base}/auth/discord/callback"
    scope = "identify email"

    url =
      "https://discord.com/oauth2/authorize?client_id=#{client_id}&redirect_uri=#{URI.encode_www_form(redirect_uri)}&response_type=code&scope=#{URI.encode_www_form(scope)}&state=#{URI.encode_www_form(session_id)}"

    json(conn, %{authorization_url: url, session_id: session_id})
  end

  def api_request(conn, %{"provider" => "apple"}) do
    # Create session (with optional link_user_id if JWT is present)
    session_id = create_api_oauth_session(conn, "apple")

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
    # Create session (with optional link_user_id if JWT is present)
    session_id = create_api_oauth_session(conn, "google")

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
    # Create session (with optional link_user_id if JWT is present)
    session_id = create_api_oauth_session(conn, "facebook")

    # Generate the Facebook OAuth URL
    client_id = System.get_env("FACEBOOK_CLIENT_ID")
    base = GameServerWeb.Endpoint.url()
    redirect_uri = "#{base}/auth/facebook/callback"
    scope = "email"

    url =
      "https://www.facebook.com/v18.0/dialog/oauth?client_id=#{client_id}&redirect_uri=#{URI.encode_www_form(redirect_uri)}&response_type=code&scope=#{URI.encode_www_form(scope)}&state=#{URI.encode_www_form(session_id)}"

    json(conn, %{authorization_url: url, session_id: session_id})
  end

  def api_request(conn, %{"provider" => "steam"}) do
    # Create session (with optional link_user_id if JWT is present)
    session_id = create_api_oauth_session(conn, "steam")

    base = GameServerWeb.Endpoint.url()

    # For Steam OpenID, include the session_id in the return_to callback so
    # the callback handler can treat this as an API/session flow when the
    # session_id is present.
    return_to = "#{base}/auth/steam/callback?state=#{URI.encode_www_form(session_id)}"
    realm = base

    url =
      "https://steamcommunity.com/openid/login?openid.ns=http://specs.openid.net/auth/2.0&openid.mode=checkid_setup&openid.return_to=#{URI.encode_www_form(return_to)}&openid.realm=#{URI.encode_www_form(realm)}&openid.identity=http://specs.openid.net/auth/2.0/identifier_select&openid.claimed_id=http://specs.openid.net/auth/2.0/identifier_select"

    json(conn, %{authorization_url: url, session_id: session_id})
  end

  # Unknown provider
  def api_request(conn, %{"provider" => _provider}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "invalid_provider", message: "Unsupported OAuth provider"})
  end

  # API clients can POST a code (or steam_id) to the callback endpoint and receive
  # tokens directly. Supports discord, google, facebook, apple and steam (steam via steam_id).
  # If a valid JWT is provided in Authorization header, links the provider instead of login.
  def api_callback(conn, %{"provider" => "discord", "code" => code}) do
    exchanger =
      Application.get_env(:game_server_web, :oauth_exchanger, GameServer.OAuth.Exchanger)

    client_id = System.get_env("DISCORD_CLIENT_ID")
    secret = System.get_env("DISCORD_CLIENT_SECRET")
    base = GameServerWeb.Endpoint.url()
    redirect_uri = "#{base}/auth/discord/callback"

    case exchanger.exchange_discord_code(code, client_id, secret, redirect_uri) do
      {:ok, %{"id" => discord_id, "email" => email} = response} ->
        avatar = response["avatar"]

        display_name = Map.get(response, "global_name") || Map.get(response, "username")

        user_params = %{
          email: email,
          discord_id: discord_id,
          display_name: display_name,
          profile_url:
            if(avatar,
              do: "https://cdn.discordapp.com/avatars/#{discord_id}/#{avatar}.png",
              else: nil
            )
        }

        # Check if user is authenticated (linking) or not (login)
        case maybe_load_user_from_jwt(conn) do
          {:ok, %User{} = current_user} ->
            handle_api_link(
              conn,
              current_user,
              user_params,
              :discord_id,
              &User.discord_oauth_changeset/2
            )

          {:ok, nil} ->
            handle_api_login(conn, &Accounts.find_or_create_from_discord/1, user_params)
        end

      {:error, err} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "exchange_failed", details: inspect(err)})

      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "exchange_failed", details: "missing id/email"})
    end
  end

  def api_callback(conn, %{"provider" => "google", "code" => code}) do
    exchanger =
      Application.get_env(:game_server_web, :oauth_exchanger, GameServer.OAuth.Exchanger)

    client_id = System.get_env("GOOGLE_CLIENT_ID")
    secret = System.get_env("GOOGLE_CLIENT_SECRET")
    base = GameServerWeb.Endpoint.url()
    redirect_uri = "#{base}/auth/google/callback"

    case exchanger.exchange_google_code(code, client_id, secret, redirect_uri) do
      {:ok, %{"id" => google_id, "email" => email} = user_info} ->
        picture = Map.get(user_info, "picture")
        name = Map.get(user_info, "name") || Map.get(user_info, "given_name")

        user_params = %{email: email, google_id: google_id, display_name: name}

        user_params =
          if(picture, do: Map.put(user_params, :profile_url, picture), else: user_params)

        # Check if user is authenticated (linking) or not (login)
        case maybe_load_user_from_jwt(conn) do
          {:ok, %User{} = current_user} ->
            handle_api_link(
              conn,
              current_user,
              user_params,
              :google_id,
              &User.google_oauth_changeset/2
            )

          {:ok, nil} ->
            handle_api_login(conn, &Accounts.find_or_create_from_google/1, user_params)
        end

      {:error, err} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "exchange_failed", details: inspect(err)})
    end
  end

  def api_callback(conn, %{"provider" => "facebook", "code" => code}) do
    exchanger =
      Application.get_env(:game_server_web, :oauth_exchanger, GameServer.OAuth.Exchanger)

    client_id = System.get_env("FACEBOOK_CLIENT_ID")
    secret = System.get_env("FACEBOOK_CLIENT_SECRET")
    base = GameServerWeb.Endpoint.url()
    redirect_uri = "#{base}/auth/facebook/callback"

    case exchanger.exchange_facebook_code(code, client_id, secret, redirect_uri) do
      {:ok, %{"id" => facebook_id} = user_info} ->
        email = user_info["email"]

        profile_url =
          user_info
          |> Map.get("picture", %{})
          |> Map.get("data", %{})
          |> Map.get("url")

        name = Map.get(user_info, "name")

        user_params = %{email: email, facebook_id: facebook_id, display_name: name}

        user_params =
          if(profile_url, do: Map.put(user_params, :profile_url, profile_url), else: user_params)

        # Check if user is authenticated (linking) or not (login)
        case maybe_load_user_from_jwt(conn) do
          {:ok, %User{} = current_user} ->
            handle_api_link(
              conn,
              current_user,
              user_params,
              :facebook_id,
              &User.facebook_oauth_changeset/2
            )

          {:ok, nil} ->
            handle_api_login(conn, &Accounts.find_or_create_from_facebook/1, user_params)
        end

      {:error, err} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "exchange_failed", details: inspect(err)})
    end
  end

  def api_callback(conn, %{"provider" => "apple", "code" => code}) do
    exchanger =
      Application.get_env(:game_server_web, :oauth_exchanger, GameServer.OAuth.Exchanger)

    client_id = System.get_env("APPLE_CLIENT_ID")

    client_secret =
      try do
        GameServer.Apple.client_secret()
      rescue
        _ ->
          nil
      end

    base = GameServerWeb.Endpoint.url()
    redirect_uri = "#{base}/auth/apple/callback"

    case exchanger.exchange_apple_code(code, client_id, client_secret, redirect_uri) do
      {:ok, %{"sub" => apple_id} = user_info} ->
        email = user_info["email"]
        name = Map.get(user_info, "name")

        user_params = %{email: email, apple_id: apple_id, display_name: name}

        # Check if user is authenticated (linking) or not (login)
        case maybe_load_user_from_jwt(conn) do
          {:ok, %User{} = current_user} ->
            handle_api_link(
              conn,
              current_user,
              user_params,
              :apple_id,
              &User.apple_oauth_changeset/2
            )

          {:ok, nil} ->
            handle_api_login(conn, &Accounts.find_or_create_from_apple/1, user_params)
        end

      {:error, err} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "exchange_failed", details: inspect(err)})
    end
  end

  # For steam, allow clients to POST an object with a steam_id (and optional display_name/profile_url)
  # and return tokens on success.
  # Steam: verify the provided `code` with the configured exchanger (uses Steam Web API)
  # For steam, allow clients to POST either a steam SDK `ticket` (preferred for SDK flows)
  # or a `code`/steam_id. If `ticket` is present prefer exchange_steam_ticket which
  # verifies the client-provided ticket via the Steam Web API. Otherwise fall back to
  # exchange_steam_code which validates a steam id or steam-specific code.
  def api_callback(conn, %{"provider" => "steam"} = params) do
    exchanger =
      Application.get_env(:game_server_web, :oauth_exchanger, GameServer.OAuth.Exchanger)

    # For API Steam flows, the 'code' field MUST be a Steam auth ticket
    # issued by the client (AuthenticateUserTicket). We prefer the stronger
    # AuthenticateUserTicket verification and explicitly DO NOT accept plain
    # steam ids via the API (they remain supported in the browser OpenID flow).
    exchange_result =
      case params["code"] do
        nil -> {:error, :missing_param}
        code -> exchanger.exchange_steam_ticket(code, fetch_profile: true)
      end

    case exchange_result do
      {:ok, %{"id" => steam_id} = profile_info} ->
        user_params = %{
          steam_id: steam_id,
          display_name: Map.get(profile_info, "display_name"),
          profile_url: Map.get(profile_info, "profile_url")
        }

        # Check if user is authenticated (linking) or not (login)
        case maybe_load_user_from_jwt(conn) do
          {:ok, %User{} = current_user} ->
            handle_api_link(
              conn,
              current_user,
              user_params,
              :steam_id,
              &User.steam_oauth_changeset/2
            )

          {:ok, nil} ->
            handle_api_login(conn, &Accounts.find_or_create_from_steam/1, user_params)
        end

      {:error, :missing_param} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "missing_param",
          message: "code (Steam auth ticket) is required for steam provider"
        })

      {:error, err} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "exchange_failed", details: inspect(err)})
    end
  end

  def api_callback(conn, %{"provider" => _provider}) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      error: "missing_or_unsupported",
      message: "provider or required params are missing/unsupported"
    })
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
      ok: {"Session status", "application/json", GameServerWeb.Schemas.OAuthSessionStatus},
      not_found: {"Session not found", "application/json", nil}
    ]
  )

  def api_session_status(conn, %{"session_id" => session_id}) do
    case GameServer.OAuthSessions.get_session(session_id) do
      %GameServer.OAuthSession{status: status, data: data} ->
        # Return a shape that matches the OpenAPI spec and the generated
        # JavaScript SDK: { status: string, data: { ... } }
        json(conn, %{status: status, data: data || %{}})

      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "session_not_found", message: "OAuth session not found"})
    end
  end

  defp handle_browser_google_callback(conn, user_params) do
    case conn.assigns[:current_scope] do
      %{:user => current_user} ->
        case Accounts.link_account(
               current_user,
               user_params,
               :google_id,
               &User.google_oauth_changeset/2
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
               &User.facebook_oauth_changeset/2
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
               &User.apple_oauth_changeset/2
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

  defp handle_browser_steam_callback(conn, user_params) do
    case conn.assigns[:current_scope] do
      %{:user => current_user} ->
        case Accounts.link_account(
               current_user,
               user_params,
               :steam_id,
               &User.steam_oauth_changeset/2
             ) do
          {:ok, _user} ->
            conn
            |> put_flash(:info, "Linked Steam to your account.")
            |> redirect(to: ~p"/users/settings")

          {:error, {:conflict, other_user}} ->
            require Logger
            Logger.warning("Steam already linked to another user id=#{other_user.id}")

            conn
            |> put_flash(
              :error,
              "Steam is already linked to another account. You can delete the conflicting account on this page if it belongs to you."
            )
            |> redirect(
              to: ~p"/users/settings?conflict_provider=steam&conflict_user_id=#{other_user.id}"
            )

          {:error, changeset} ->
            require Logger
            Logger.error("Failed to link Steam: #{inspect(changeset.errors)}")

            conn
            |> put_flash(:error, "Failed to link Steam account.")
            |> redirect(to: ~p"/users/settings")
        end

      _ ->
        case Accounts.find_or_create_from_steam(user_params) do
          {:ok, user} ->
            conn
            |> put_flash(:info, "Successfully authenticated with Steam.")
            |> UserAuth.log_in_user(user)

          {:error, changeset} ->
            require Logger
            Logger.error("Failed to create user from Steam: #{inspect(changeset.errors)}")

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
               &User.discord_oauth_changeset/2
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
    handle_session_oauth_callback(
      conn,
      session_id,
      user_params,
      :discord_id,
      &User.discord_oauth_changeset/2,
      &Accounts.find_or_create_from_discord/1
    )
  end

  defp do_find_or_create_google_for_session(conn, user_params, session_id) do
    handle_session_oauth_callback(
      conn,
      session_id,
      user_params,
      :google_id,
      &User.google_oauth_changeset/2,
      &Accounts.find_or_create_from_google/1
    )
  end

  defp do_find_or_create_facebook_for_session(conn, user_params, session_id) do
    handle_session_oauth_callback(
      conn,
      session_id,
      user_params,
      :facebook_id,
      &User.facebook_oauth_changeset/2,
      &Accounts.find_or_create_from_facebook/1
    )
  end

  defp do_find_or_create_apple_for_session(conn, user_params, session_id) do
    handle_session_oauth_callback(
      conn,
      session_id,
      user_params,
      :apple_id,
      &User.apple_oauth_changeset/2,
      &Accounts.find_or_create_from_apple/1
    )
  end

  defp do_find_or_create_steam_for_session(conn, user_params, session_id) do
    handle_session_oauth_callback(
      conn,
      session_id,
      user_params,
      :steam_id,
      &User.steam_oauth_changeset/2,
      &Accounts.find_or_create_from_steam/1
    )
  end
end
