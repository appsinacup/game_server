defmodule GameServerWeb.Plugs.RequestTimer do
  @moduledoc """
  A plug that logs the total request duration at the end of the request.
  This runs before the Router and captures the entire pipeline duration.

  The `x-request-time` response header is only included in non-production
  environments to avoid leaking server timing information to attackers.
  """
  import Plug.Conn
  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    start_time = System.monotonic_time()

    register_before_send(conn, fn conn ->
      end_time = System.monotonic_time()
      duration_us = System.convert_time_unit(end_time - start_time, :native, :microsecond)
      duration_ms = duration_us / 1000

      if duration_ms > 200 do
        Logger.warning("Slow Request: #{conn.method} #{conn.request_path} took #{duration_ms}ms")
      end

      if expose_header?() do
        put_resp_header(conn, "x-request-time", "#{duration_ms}ms")
      else
        conn
      end
    end)
  end

  defp expose_header? do
    Application.get_env(:game_server_web, :environment, :prod) != :prod
  end
end
