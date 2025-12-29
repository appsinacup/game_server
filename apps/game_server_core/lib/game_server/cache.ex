defmodule GameServer.Cache do
  @moduledoc """
  Application cache backed by Nebulex.

  This cache uses a 2-level (near-cache) topology via
  `Nebulex.Adapters.Multilevel`:

  - L1: local in-memory cache (`GameServer.Cache.L1`)
  - L2: either Redis (`GameServer.Cache.L2.Redis`) or a partitioned topology
    (`GameServer.Cache.L2.Partitioned`), selected via runtime config.
  """

  use Nebulex.Cache,
    otp_app: :game_server_core,
    adapter: Nebulex.Adapters.Multilevel
end
