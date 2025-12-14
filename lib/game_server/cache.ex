defmodule GameServer.Cache do
  @moduledoc """
  Application cache backed by Nebulex.

  We currently use a local (in-memory) adapter for simplicity. In the future,
  this can be swapped for other Nebulex adapters/topologies.
  """

  use Nebulex.Cache,
    otp_app: :game_server,
    adapter: Nebulex.Adapters.Local
end
