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
          fields: "id,email",
          access_token: access_token
        }

        case Req.get(user_url, params: user_params) do
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
