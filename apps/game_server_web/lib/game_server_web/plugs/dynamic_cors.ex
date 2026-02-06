defmodule GameServerWeb.Plugs.DynamicCors do
  @moduledoc """
  Runtime CORS plug that delegates to Corsica using values read from
  application environment at startup. This allows `PHX_ALLOWED_ORIGINS`
  to be configured at runtime (via `config/runtime.exs`).
  """

  @default_allow_headers ["content-type", "authorization"]
  @default_allow_methods ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]

  def init(opts), do: opts

  def call(conn, _opts) do
    origins = Application.get_env(:game_server_web, :cors_allowed_origins, "*")

    cors_opts = [
      origins: origins,
      allow_headers: @default_allow_headers,
      allow_methods: @default_allow_methods,
      expose_headers: ["x-request-time"],
      allow_credentials: true
    ]

    Corsica.call(conn, Corsica.init(cors_opts))
  end
end
