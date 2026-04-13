defmodule GameServerWeb.Plugs.MetricsAuth do
  @moduledoc """
  Authentication for the `/metrics` endpoint.

  Access rules (checked in order):

  1. **Private/local IPs** — always allowed without auth.
     Covers Docker internal networks (172.x, 10.x, 192.168.x), localhost (127.x),
     and IPv6 loopback (::1). This means Prometheus running in the same
     docker-compose can always scrape `/metrics`.

  2. **Bearer token** — if `METRICS_AUTH_TOKEN` is set, external requests
     must include `Authorization: Bearer <token>`.

  3. **No token configured** — all requests are allowed (dev default).

  ## Configuration

      # In production — set this to restrict external access
      METRICS_AUTH_TOKEN=my-secret-prometheus-token

  Prometheus scrape config with token:

      scrape_configs:
        - job_name: "gamend"
          bearer_token: "my-secret-prometheus-token"
          static_configs:
            - targets: ["app:4000"]
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    if private_ip?(conn.remote_ip) do
      # Always allow local/Docker-internal access
      conn
    else
      check_token(conn)
    end
  end

  defp check_token(conn) do
    case required_token() do
      nil ->
        # No token configured — allow unrestricted access
        conn

      expected ->
        case get_req_header(conn, "authorization") do
          ["Bearer " <> token] when token == expected ->
            conn

          _ ->
            conn
            |> put_resp_content_type("text/plain")
            |> send_resp(401, "Unauthorized")
            |> halt()
        end
    end
  end

  # Check if the IP is in a private/local range
  defp private_ip?({127, _, _, _}), do: true
  defp private_ip?({10, _, _, _}), do: true
  defp private_ip?({172, b, _, _}) when b >= 16 and b <= 31, do: true
  defp private_ip?({192, 168, _, _}), do: true
  defp private_ip?({0, 0, 0, 0, 0, 0, 0, 1}), do: true
  defp private_ip?(_), do: false

  defp required_token do
    case Application.get_env(:game_server_web, :metrics_auth_token) do
      token when is_binary(token) and token != "" -> token
      _ -> nil
    end
  end
end
