defmodule GameServerWeb.Plugs.FeatureGate do
  @moduledoc """
  Plug that gates routes behind environment-variable feature flags.

  ## Usage

      plug GameServerWeb.Plugs.FeatureGate, env: "OPENAPI_ENABLED", default: true

  When the feature is disabled (env var is `"false"` / `"0"` / `"no"`),
  requests are rejected with `404 Not Found`.
  """

  import Plug.Conn
  @behaviour Plug

  @impl true
  def init(opts) do
    %{
      env: Keyword.fetch!(opts, :env),
      default: Keyword.get(opts, :default, true)
    }
  end

  @impl true
  def call(conn, %{env: env_var, default: default}) do
    if enabled?(env_var, default) do
      conn
    else
      conn
      |> send_resp(404, "Not Found")
      |> halt()
    end
  end

  defp enabled?(env_var, default) do
    case System.get_env(env_var) do
      nil -> default
      val -> val not in ["false", "0", "no"]
    end
  end
end
