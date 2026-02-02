defmodule GameServerWeb.Plugs.RequestTimer do
  @moduledoc """
  A plug that logs the total request duration at the end of the request.
  This runs before the Router and captures the entire pipeline duration.
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

      conn
      |> put_resp_header("x-request-time", "#{duration_ms}ms")
    end)
  end
end
