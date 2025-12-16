defmodule GameServer.AppleCacheTest do
  use ExUnit.Case, async: true

  setup do
    # Ensure a clean ETS table for each test
    case :ets.info(:apple_oauth_cache) do
      :undefined -> :ok
      _ -> :ets.delete(:apple_oauth_cache)
    end

    :ok
  end

  test "client_secret returns cached value when present and not expired" do
    secret = "cached-secret-#{System.unique_integer([:positive])}"
    # create table and insert value that is not yet expired
    :ets.new(:apple_oauth_cache, [:named_table, :public, :set])
    expires_at = System.system_time(:second) + 10_000
    :ets.insert(:apple_oauth_cache, {:client_secret, secret, expires_at})

    # The with statement returns {:ok, secret} from cache, which becomes the function return
    assert {:ok, secret} == GameServer.Apple.client_secret()
  end

  test "client_secret raises when env var missing and cache empty" do
    # ensure no cache and no APPLE_PRIVATE_KEY env var
    case :ets.info(:apple_oauth_cache) do
      :undefined -> :ok
      _ -> :ets.delete(:apple_oauth_cache)
    end

    old = System.get_env("APPLE_PRIVATE_KEY")
    System.delete_env("APPLE_PRIVATE_KEY")

    on_exit(fn ->
      if old, do: System.put_env("APPLE_PRIVATE_KEY", old)
    end)

    assert_raise RuntimeError, fn -> GameServer.Apple.client_secret() end
  end

  test "get_client_secret_from_cache returns error when cache is expired" do
    # Create an expired cache entry
    :ets.new(:apple_oauth_cache, [:named_table, :public, :set])
    expired_secret = "expired-secret"
    expires_at = System.system_time(:second) - 100
    :ets.insert(:apple_oauth_cache, {:client_secret, expired_secret, expires_at})

    # Calling client_secret should attempt to regenerate (and fail without env vars)
    old = System.get_env("APPLE_PRIVATE_KEY")
    System.delete_env("APPLE_PRIVATE_KEY")

    on_exit(fn ->
      if old, do: System.put_env("APPLE_PRIVATE_KEY", old)
    end)

    # Should raise because cache is expired and env var is missing
    assert_raise RuntimeError, fn -> GameServer.Apple.client_secret() end
  end
end
