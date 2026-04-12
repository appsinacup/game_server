defmodule GameServerWeb.LiveHelpers do
  @moduledoc """
  Shared helpers for LiveView rate limiting and client IP extraction.
  """

  @doc """
  Extract the client IP from a LiveView socket's `connect_info`.

  Falls back to `"unknown"` when the socket has no peer data (e.g. during
  the initial static render or in tests).
  """
  def client_ip(socket) do
    case Phoenix.LiveView.get_connect_info(socket, :peer_data) do
      %{address: addr} -> addr |> :inet.ntoa() |> to_string()
      _ -> "unknown"
    end
  end

  @doc """
  Check a rate limit bucket for the given IP.

  Bucket types:
    - `:auth` — 10 requests per 60 seconds (matches the HTTP auth bucket)
    - `:general` — 120 requests per 60 seconds

  Returns `:ok` or `{:error, retry_after_ms}`.
  """
  def check_rate_limit(ip, bucket_type \\ :general)

  def check_rate_limit("unknown", _bucket_type), do: :ok

  def check_rate_limit(ip, :auth) do
    {limit, window} = auth_limits()
    do_check("lv_auth:#{ip}", window, limit)
  end

  def check_rate_limit(ip, :general) do
    {limit, window} = general_limits()
    do_check("lv_general:#{ip}", window, limit)
  end

  defp do_check(key, window_ms, limit) do
    case GameServerWeb.RateLimit.hit(key, window_ms, limit) do
      {:allow, _count} -> :ok
      {:deny, retry_after} -> {:error, retry_after}
    end
  end

  defp auth_limits do
    config = Application.get_env(:game_server_web, GameServerWeb.Plugs.RateLimiter, [])
    limit = Keyword.get(config, :auth_limit, 10)
    window = Keyword.get(config, :auth_window, :timer.seconds(60))
    {limit, window}
  end

  defp general_limits do
    config = Application.get_env(:game_server_web, GameServerWeb.Plugs.RateLimiter, [])
    limit = Keyword.get(config, :limit, 120)
    window = Keyword.get(config, :window, :timer.seconds(60))
    {limit, window}
  end
end
