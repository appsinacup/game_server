defmodule GameServer.OAuth.Exchanger do
  @moduledoc """
  Default implementation for exchanging OAuth codes with providers.

  This module is intentionally small and works with the Req library.
  Tests may replace the exchanger via application config for easier stubbing.
  """

  @spec exchange_discord_code(String.t(), String.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def exchange_discord_code(code, client_id, client_secret, redirect_uri) do
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

  @spec exchange_google_code(String.t(), String.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def exchange_google_code(code, client_id, client_secret, redirect_uri) do
    url = "https://oauth2.googleapis.com/token"

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
        user_url = "https://www.googleapis.com/oauth2/v2/userinfo"
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

  @spec exchange_facebook_code(String.t(), String.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def exchange_facebook_code(code, client_id, client_secret, redirect_uri) do
    url = "https://graph.facebook.com/v18.0/oauth/access_token"

    params = %{
      client_id: client_id,
      client_secret: client_secret,
      code: code,
      redirect_uri: redirect_uri
    }

    case Req.get(url, params: params) do
      {:ok, %{status: 200, body: %{"access_token" => access_token}}} ->
        # Get user info with access token
        user_url = "https://graph.facebook.com/v18.0/me"

        user_params = %{
          # request picture from facebook so we can map an avatar url
          fields: "id,email,picture",
          access_token: access_token
        }

        case Req.get(user_url, params: user_params) do
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

  @spec exchange_apple_code(String.t(), String.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def exchange_apple_code(code, client_id, client_secret, _redirect_uri) do
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

    case Req.post(url, form: body, headers: headers) do
      {:ok, %{status: 200, body: %{"id_token" => id_token}}} ->
        Logger.info("Apple OAuth: Successfully received id_token")
        # Parse the JWT id_token to get user info
        case parse_apple_id_token(id_token) do
          {:ok, user_info} ->
            Logger.info("Apple OAuth: Successfully parsed user info: #{inspect(user_info)}")
            {:ok, user_info}

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
  defp parse_apple_id_token(id_token) do
    try do
      # JWT tokens have 3 parts separated by dots: header.payload.signature
      [_header, payload, _signature] = String.split(id_token, ".")

      # Decode the base64-encoded payload
      # Add padding if needed
      padded_payload =
        case rem(String.length(payload), 4) do
          0 -> payload
          n -> payload <> String.duplicate("=", 4 - n)
        end

      decoded = Base.url_decode64!(padded_payload)
      Jason.decode(decoded)
    rescue
      _ -> {:error, "Invalid JWT token"}
    end
  end
end
