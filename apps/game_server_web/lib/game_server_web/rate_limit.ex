defmodule GameServerWeb.RateLimit do
  @moduledoc """
  ETS-backed rate limiter powered by Hammer.

  Started in the host application supervision tree.
  Used by `GameServerWeb.Plugs.RateLimiter` for HTTP request throttling.
  """
  use Hammer, backend: :ets
end
