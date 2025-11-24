defmodule GameServer.Apple do
  @moduledoc """
  Apple OAuth client secret generation for Ueberauth.

  Apple requires client secrets to be generated dynamically as they expire after 6 months.
  This module handles the generation and caching of Apple client secrets.
  """

  # 6 months
  @expiration_sec 86400 * 180

  @doc """
  Generates or retrieves a cached Apple client secret.

  Returns the client secret string, either from cache or newly generated.
  """
  @spec client_secret(keyword) :: String.t()
  def client_secret(_config \\ []) do
    with {:error, :not_found} <- get_client_secret_from_cache() do
      secret =
        UeberauthApple.generate_client_secret(%{
          client_id: System.get_env("APPLE_CLIENT_ID"),
          expires_in: @expiration_sec,
          key_id: System.get_env("APPLE_KEY_ID"),
          team_id: System.get_env("APPLE_TEAM_ID"),
          private_key: System.get_env("APPLE_PRIVATE_KEY")
        })

      put_client_secret_in_cache(secret, @expiration_sec)
      secret
    end
  end

  # Simple cache implementation using ETS
  defp get_client_secret_from_cache do
    case :ets.lookup(:apple_oauth_cache, :client_secret) do
      [{:client_secret, secret, expires_at}] ->
        if expires_at > System.system_time(:second) do
          {:ok, secret}
        else
          {:error, :not_found}
        end

      _ ->
        {:error, :not_found}
    end
  rescue
    _ -> {:error, :not_found}
  end

  defp put_client_secret_in_cache(secret, ttl_seconds) do
    # Ensure ETS table exists
    case :ets.info(:apple_oauth_cache) do
      :undefined ->
        :ets.new(:apple_oauth_cache, [:named_table, :public, :set])

      _ ->
        :ok
    end

    expires_at = System.system_time(:second) + ttl_seconds
    :ets.insert(:apple_oauth_cache, {:client_secret, secret, expires_at})
  end
end
