defmodule GameServerWeb.Plugs.DynamicCors do
  @moduledoc """
  Runtime CORS plug that delegates to Corsica using values read from
  application environment at startup. This allows `PHX_ALLOWED_ORIGINS`
  to be configured at runtime (via `config/runtime.exs`).

  The Corsica options are compiled once on first request and cached in a
  persistent_term for near-zero overhead on subsequent requests.
  """

  @default_allow_headers ["content-type", "authorization"]
  @default_allow_methods ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]

  @pt_key {__MODULE__, :corsica_opts}

  def init(opts), do: opts

  def call(conn, _opts) do
    Corsica.call(conn, cached_corsica_opts())
  end

  defp cached_corsica_opts do
    case :persistent_term.get(@pt_key, nil) do
      nil ->
        compiled = compile_corsica_opts()
        :persistent_term.put(@pt_key, compiled)
        compiled

      cached ->
        cached
    end
  end

  defp compile_corsica_opts do
    origins = Application.get_env(:game_server_web, :cors_allowed_origins, "*")

    Corsica.init(
      origins: origins,
      allow_headers: @default_allow_headers,
      allow_methods: @default_allow_methods,
      expose_headers: ["x-request-time"],
      allow_credentials: true
    )
  end

  @doc """
  Invalidate the cached Corsica options. Call this if CORS origins
  are changed at runtime (e.g. via admin config).
  """
  def invalidate_cache do
    :persistent_term.erase(@pt_key)
    :ok
  end
end
