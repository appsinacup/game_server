defmodule GameServer.OAuth.Exchanger do
  @moduledoc """
  Default implementation for exchanging OAuth codes with providers.

  This module is intentionally small and works with the Req library.
  Tests may replace the exchanger via application config for easier stubbing.
  """

  @spec exchange_discord_code(String.t(), String.t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def exchange_discord_code(code, client_id, client_secret, redirect_uri, _opts \\ []) do
    url = "https://discord.com/api/oauth2/token"

    body = %{
      client_id: client_id,
      client_secret: client_secret,
      grant_type: "authorization_code",
      code: code,
      redirect_uri: redirect_uri
    }

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    case http_client().post(url, form: body, headers: headers) do
      {:ok, %{status: 200, body: %{"access_token" => access_token}}} ->
        # Get user info with access token
        user_url = "https://discord.com/api/users/@me"
        auth_headers = [{"Authorization", "Bearer #{access_token}"}]

        case http_client().get(user_url, headers: auth_headers) do
          {:ok, %{status: 200, body: user_info}} ->
            {:ok, user_info}

          _ ->
            {:error, "Failed to get user info"}
        end

      _ ->
        {:error, "Failed to exchange code"}
    end
  end

  @spec exchange_google_code(String.t(), String.t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def exchange_google_code(code, client_id, client_secret, redirect_uri, opts \\ []) do
    url = "https://oauth2.googleapis.com/token"

    body = %{
      client_id: client_id,
      client_secret: client_secret,
      grant_type: "authorization_code",
      code: code,
      redirect_uri: redirect_uri
    }

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    case http_client().post(url, form: body, headers: headers) do
      {:ok, %{status: 200, body: body}} ->
        if Keyword.get(opts, :fetch_profile, true) == false do
          google_handle_minimal(body, code, client_id, client_secret, redirect_uri)
        else
          google_handle_full(body)
        end

      _ ->
        {:error, "Failed to exchange code"}
    end
  end

  defp google_handle_minimal(body, code, client_id, client_secret, redirect_uri) do
    case Map.get(body, "id_token") do
      id_token when is_binary(id_token) ->
        case parse_id_token(id_token) do
          {:ok, parsed} when is_map(parsed) ->
            id = parsed["sub"] || parsed["id"]
            {:ok, Map.put(parsed, "id", id)}

          _ ->
            # cannot parse id_token -> fall back to full profile flow
            exchange_google_code(code, client_id, client_secret, redirect_uri,
              fetch_profile: true
            )
        end

      _ ->
        # no id_token -> perform full flow
        exchange_google_code(code, client_id, client_secret, redirect_uri, fetch_profile: true)
    end
  end

  defp google_handle_full(body) do
    case Map.get(body, "access_token") do
      access_token when is_binary(access_token) ->
        user_url = "https://www.googleapis.com/oauth2/v2/userinfo"
        auth_headers = [{"Authorization", "Bearer #{access_token}"}]

        case http_client().get(user_url, headers: auth_headers) do
          {:ok, %{status: 200, body: user_info}} -> {:ok, user_info}
          _ -> {:error, "Failed to get user info"}
        end

      _ ->
        {:error, "Failed to exchange code"}
    end
  end

  @spec exchange_facebook_code(String.t(), String.t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def exchange_facebook_code(code, client_id, client_secret, redirect_uri, _opts \\ []) do
    url = "https://graph.facebook.com/v18.0/oauth/access_token"

    params = %{
      client_id: client_id,
      client_secret: client_secret,
      code: code,
      redirect_uri: redirect_uri
    }

    case http_client().get(url, params: params) do
      {:ok, %{status: 200, body: %{"access_token" => access_token}}} ->
        # Get user info with access token
        user_url = "https://graph.facebook.com/v18.0/me"

        user_params = %{
          # request picture from facebook so we can map an avatar url
          fields: "id,email,picture",
          access_token: access_token
        }

        case http_client().get(user_url, params: user_params) do
          {:ok, %{status: 200, body: user_info}} when is_map(user_info) ->
            {:ok, user_info}

          {:ok, %{status: 200, body: user_info}} when is_binary(user_info) ->
            # Parse JSON string if needed
            case Jason.decode(user_info) do
              {:ok, parsed} -> {:ok, parsed}
              _ -> {:error, "Failed to parse user info"}
            end

          _ ->
            {:error, "Failed to get user info"}
        end

      _ ->
        {:error, "Failed to exchange code"}
    end
  end

  @spec exchange_apple_code(String.t(), String.t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def exchange_apple_code(code, client_id, client_secret, _redirect_uri, opts \\ []) do
    require Logger
    url = "https://appleid.apple.com/auth/token"

    body = %{
      client_id: client_id,
      client_secret: client_secret,
      grant_type: "authorization_code",
      code: code
    }

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    Logger.info("Apple OAuth: Exchanging code with Apple. URL: #{url}")

    case http_client().post(url, form: body, headers: headers) do
      {:ok, %{status: 200, body: %{"id_token" => id_token} = _body}} ->
        Logger.info("Apple OAuth: Successfully received id_token")
        # Parse the JWT id_token to get user info
        case parse_apple_id_token(id_token) do
          {:ok, user_info} ->
            # If caller requested minimal data, just return subject/email (avoid extra work)
            if Keyword.get(opts, :fetch_profile, true) == false do
              {:ok,
               Map.take(user_info, ["sub", "email"] |> Enum.filter(&Map.has_key?(user_info, &1)))}
            else
              Logger.info("Apple OAuth: Successfully parsed user info: #{inspect(user_info)}")
              {:ok, user_info}
            end

          {:error, reason} ->
            Logger.error("Apple OAuth: Failed to parse id_token: #{inspect(reason)}")
            {:error, "Failed to parse id_token"}
        end

      {:ok, %{status: status, body: body}} ->
        Logger.error(
          "Apple OAuth: Token exchange failed with status #{status}. Body: #{inspect(body)}"
        )

        {:error, "Failed to exchange code: #{status}"}

      {:error, error} ->
        Logger.error("Apple OAuth: Request failed: #{inspect(error)}")
        {:error, "Failed to exchange code"}
    end
  end

  # Parse Apple's JWT id_token to extract user information
  @doc false
  def parse_apple_id_token(id_token) do
    # Use safe, non-raising operations and return {:ok, map} or {:error, reason}
    case String.split(id_token, ".") do
      [_header, payload, _signature] ->
        padded_payload =
          case rem(String.length(payload), 4) do
            0 -> payload
            n -> payload <> String.duplicate("=", 4 - n)
          end

        with {:ok, decoded} <- Base.url_decode64(padded_payload),
             {:ok, parsed} <- Jason.decode(decoded) do
          {:ok, parsed}
        else
          _ -> {:error, "Invalid JWT token"}
        end

      _ ->
        {:error, "Invalid JWT token"}
    end
  end

  @doc false
  # Generic id_token parser usable for OpenID id_tokens across providers
  defp parse_id_token(id_token) do
    case String.split(id_token, ".") do
      [_header, payload, _signature] ->
        padded_payload =
          case rem(String.length(payload), 4) do
            0 -> payload
            n -> payload <> String.duplicate("=", 4 - n)
          end

        with {:ok, decoded} <- Base.url_decode64(padded_payload),
             {:ok, parsed} <- Jason.decode(decoded) do
          {:ok, parsed}
        else
          _ -> {:error, "Invalid JWT token"}
        end

      _ ->
        {:error, "Invalid JWT token"}
    end
  end

  # Helper to allow injecting a test HTTP client in tests. Defaults to Req.
  defp http_client do
    Application.get_env(:game_server, :oauth_exchanger_client, Req)
  end

  @spec exchange_steam_code(String.t()) :: {:ok, map()} | {:error, term()}
  def exchange_steam_code(code) do
    api_key =
      Application.get_env(:ueberauth, Ueberauth.Strategy.Steam)[:api_key] ||
        System.get_env("STEAM_API_KEY")

    if is_nil(api_key) or api_key == "" do
      {:error, :no_api_key}
    else
      # Accept either a steam id or a prefixed value like "steam:12345"
      steam_id =
        case String.split(code, ":") do
          ["steam", id] -> id
          [id] -> id
          _ -> code
        end

      url = "https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/"

      params = %{key: api_key, steamids: steam_id}

      case http_client().get(url, params: params) do
        {:ok, %{status: 200, body: %{"response" => %{"players" => [player | _]}}}} ->
          # Normalize returned player info to a minimal map usable by caller
          {:ok,
           %{
             "id" => to_string(steam_id),
             "display_name" => player["personaname"],
             "profile_url" => player["profileurl"],
             "avatar" => player["avatarfull"] || player["avatar"]
           }}

        _ ->
          {:error, :invalid_steam_response}
      end
    end
  end

  @doc """
  Verify a Steam auth ticket using ISteamUserAuth/AuthenticateUserTicket/v1

  Expects a ticket (binary blob) returned by the Steamworks client SDK. Returns
  {:ok, user_info} on successful verification or {:error, reason} on failure.
  """
  @spec exchange_steam_ticket(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def exchange_steam_ticket(ticket, opts \\ []) when is_binary(ticket) and is_list(opts) do
    api_key =
      Application.get_env(:ueberauth, Ueberauth.Strategy.Steam)[:api_key] ||
        System.get_env("STEAM_API_KEY")

    appid = System.get_env("STEAM_APP_ID")

    if is_nil(api_key) or api_key == "" or is_nil(appid) or appid == "" do
      {:error, :missing_config}
    else
      url = "https://api.steampowered.com/ISteamUserAuth/AuthenticateUserTicket/v1/"
      params = %{key: api_key, appid: appid, ticket: ticket}

      with {:ok,
            %{status: 200, body: %{"response" => %{"params" => params_map, "result" => result}}}} <-
             http_client().post(url, form: params),
           true <- result in ["OK", "ok"] do
        steamid = params_map["ownersteamid"] || params_map["steamid"]

        if is_nil(steamid) do
          {:error, :no_steamid}
        else
          if Keyword.get(opts, :fetch_profile, true) do
            steam_profile_for(api_key, steamid)
          else
            {:ok, %{"id" => to_string(steamid)}}
          end
        end
      else
        {:ok, %{status: 200, body: %{"response" => %{"result" => result}}}} ->
          {:error, {:steam_result, result}}

        _ ->
          {:error, :invalid_steam_response}
      end
    end
  end

  # Fetch a public profile for a steamid using GetPlayerSummaries.
  # Returns {:ok, %{"id" => id, ...}} even if no player info is available.
  defp steam_profile_for(api_key, steamid) do
    url = "https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/"
    params = %{key: api_key, steamids: steamid}

    case http_client().get(url, params: params) do
      {:ok, %{status: 200, body: %{"response" => %{"players" => [player | _]}}}} ->
        {:ok,
         %{
           "id" => to_string(steamid),
           "display_name" => player["personaname"],
           "profile_url" => player["profileurl"],
           "avatar" => player["avatarfull"] || player["avatar"]
         }}

      _ ->
        {:ok, %{"id" => to_string(steamid)}}
    end
  end

  @doc """
  Fetch a public Steam profile for a given steamid using GetPlayerSummaries.
  Returns {:ok, map} or {:error, reason}.
  """
  def get_player_profile(steamid) when is_binary(steamid) do
    api_key =
      Application.get_env(:ueberauth, Ueberauth.Strategy.Steam)[:api_key] ||
        System.get_env("STEAM_API_KEY")

    if is_nil(api_key) or api_key == "" do
      {:error, :no_api_key}
    else
      steam_profile_for(api_key, steamid)
    end
  end
end
