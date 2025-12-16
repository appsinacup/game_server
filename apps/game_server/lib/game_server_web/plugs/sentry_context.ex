defmodule GameServerWeb.Plugs.SentryContext do
  @moduledoc """
  A small Plug that sets Sentry scope information for each request.

  If the request includes an authenticated user (via `current_scope` assign)
  this plug will set the Sentry user context and add a couple of extra fields
  (request_id and path). This helps Sentry group errors by user and gives
  more telemetry context for debugging.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    # Find user if present
    user = conn.assigns[:current_scope] && conn.assigns[:current_scope].user

    # Set Sentry context - Sentry 11.x automatically captures this process context
    if user do
      # Only include safe identifying information here
      Sentry.Context.set_user_context(%{id: user.id, email: user.email})
    end

    # Add request metadata
    request_id = get_resp_header(conn, "x-request-id") |> List.first()
    Sentry.Context.set_extra_context(%{request_id: request_id, path: conn.request_path})

    conn
  end
end
