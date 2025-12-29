defmodule GameServer.Cache.L2.Redis do
  @moduledoc """
  L2 cache backed by Redis.

  This cache is shared across app instances, enabling horizontal scaling.
  """

  use Nebulex.Cache,
    otp_app: :game_server_core,
    adapter: Nebulex.Adapters.Redis
end
