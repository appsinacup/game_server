defmodule GameServer.Cache.L2.Partitioned do
  @moduledoc """
  L2 cache (partitioned topology).

  This adapter shards keys across the Erlang cluster (single-hop) and uses a
  local primary storage on each node.
  """

  use Nebulex.Cache,
    otp_app: :game_server_core,
    adapter: Nebulex.Adapters.Partitioned
end
