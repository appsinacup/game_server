defmodule GameServerWeb.Plugs.SecurityHeaders do
  @moduledoc """
  Sets baseline security headers on every response.

  These headers apply to all requests — static assets, API endpoints, and
  browser pages alike. Router-level pipelines may override individual headers
  (e.g. `Content-Security-Policy`) for specific scopes.

  Headers set:

  | Header | Value | Purpose |
  |--------|-------|---------|
  | `X-Content-Type-Options` | `nosniff` | Prevents MIME type sniffing |
  | `X-Frame-Options` | `SAMEORIGIN` | Prevents clickjacking |
  | `Referrer-Policy` | `strict-origin-when-cross-origin` | Limits referrer leakage |
  | `Permissions-Policy` | (restrictive) | Limits browser feature access |
  | `Cross-Origin-Resource-Policy` | `same-origin` | Prevents cross-origin embedding |
  | `X-Permitted-Cross-Domain-Policies` | `none` | Prevents Flash/PDF cross-domain |

  In production, the `x-request-id` response header is stripped to avoid
  leaking internal correlation identifiers. The request ID remains available
  in `conn.assigns[:request_id]` for logging.
  """

  import Plug.Conn

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    conn
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-frame-options", "SAMEORIGIN")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("permissions-policy", permissions_policy())
    |> put_resp_header("cross-origin-resource-policy", "same-origin")
    |> put_resp_header("x-permitted-cross-domain-policies", "none")
    |> maybe_hsts()
    |> maybe_strip_request_id()
  end

  # In production, strip x-request-id from response headers to avoid leaking
  # internal identifiers. The value is still in conn.assigns for log correlation.
  defp maybe_strip_request_id(conn) do
    if strip_request_id?() do
      register_before_send(conn, fn conn ->
        delete_resp_header(conn, "x-request-id")
      end)
    else
      conn
    end
  end

  defp strip_request_id? do
    Application.get_env(:game_server_web, :environment, :prod) == :prod
  end

  # Set HSTS when the connection is over HTTPS (or behind a proxy that
  # terminates TLS and sets x-forwarded-proto: https).
  defp maybe_hsts(conn) do
    scheme = conn.scheme

    forwarded_proto =
      case Plug.Conn.get_req_header(conn, "x-forwarded-proto") do
        [proto | _] -> String.downcase(proto)
        _ -> nil
      end

    if scheme == :https or forwarded_proto == "https" do
      # max-age=1 year, includeSubDomains + preload for HSTS preload list eligibility
      put_resp_header(
        conn,
        "strict-transport-security",
        "max-age=31536000; includeSubDomains; preload"
      )
    else
      conn
    end
  end

  defp permissions_policy do
    # Deny all powerful browser features by default. Add exceptions as needed.
    [
      "camera=()",
      "microphone=()",
      "geolocation=()",
      "payment=()",
      "usb=()",
      "magnetometer=()",
      "gyroscope=()",
      "accelerometer=()"
    ]
    |> Enum.join(", ")
  end
end
