defmodule GameServer.Cache.L1 do
  @moduledoc """
  L1 cache (local, in-memory).

  This cache is the fastest level in the multi-level cache hierarchy.
  """

  use Nebulex.Cache,
    otp_app: :game_server_core,
    adapter: Nebulex.Adapters.Local
end
