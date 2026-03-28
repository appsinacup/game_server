defmodule GameServerWeb.Plugs.RateLimiter do
  @moduledoc """
  Plug that rate-limits incoming HTTP requests per client IP.

  Uses `GameServerWeb.RateLimit` (Hammer ETS backend) to enforce
  configurable limits per time window. Different path prefixes can have
  different limits (e.g. auth endpoints are stricter).

  ## Configuration

      config :game_server_web, GameServerWeb.Plugs.RateLimiter,
        general_limit: 120,          # requests per window
        general_window: 60_000,     # 60 seconds
        auth_limit: 10,             # login/registration
        auth_window: 60_000

  Responds with `429 Too Many Requests` when the limit is exceeded.
  """

  import Plug.Conn

  @default_general_limit 120
  @default_general_window :timer.seconds(60)
  @default_auth_limit 10
  @default_auth_window :timer.seconds(60)

  def init(opts), do: opts

  def call(conn, _opts) do
    if enabled?() do
      do_rate_limit(conn)
    else
      conn
    end
  end

  defp do_rate_limit(conn) do
    ip = client_ip(conn)
    {bucket, scale, limit} = bucket_for(conn, ip)

    case GameServerWeb.RateLimit.hit(bucket, scale, limit) do
      {:allow, _count} ->
        conn

      {:deny, retry_after_ms} ->
        retry_secs = max(div(retry_after_ms, 1000), 1)

        conn
        |> put_resp_header("retry-after", to_string(retry_secs))
        |> send_resp(429, "Too Many Requests")
        |> halt()
    end
  end

  defp bucket_for(%{path_info: ["api", "v1", path | _]} = _conn, ip)
       when path in ~w(login register) do
    config = config()

    {"auth:#{ip}", Keyword.get(config, :auth_window, @default_auth_window),
     Keyword.get(config, :auth_limit, @default_auth_limit)}
  end

  defp bucket_for(_conn, ip) do
    config = config()

    {"general:#{ip}", Keyword.get(config, :general_window, @default_general_window),
     Keyword.get(config, :general_limit, @default_general_limit)}
  end

  defp config do
    Application.get_env(:game_server_web, __MODULE__, [])
  end

  # Prefer Cloudflare's CF-Connecting-IP, then Fly-Client-IP, then remote_ip.
  defp client_ip(conn) do
    cond do
      cf = get_req_header(conn, "cf-connecting-ip") |> List.first() ->
        cf

      fly = get_req_header(conn, "fly-client-ip") |> List.first() ->
        fly

      xff = get_req_header(conn, "x-forwarded-for") |> List.first() ->
        xff |> String.split(",") |> List.first() |> String.trim()

      true ->
        conn.remote_ip |> :inet.ntoa() |> to_string()
    end
  end

  defp enabled? do
    Keyword.get(config(), :enabled, true)
  end
end
