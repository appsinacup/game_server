defmodule GameServer.Cache.Sync do
  @moduledoc """
  Applies cache invalidations broadcast by other app instances.

  `GameServer.Cache.invalidate/1` deletes a key locally and broadcasts it on
  `GameServer.Cache.invalidation_topic/0`; this process evicts the key from
  this node's L1 so all instances converge immediately instead of waiting for
  the entry's TTL. Events originating on this node are skipped — the caller
  already deleted the key locally.
  """

  use GenServer

  alias GameServer.Cache
  alias GameServer.Cache.L1

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Phoenix.PubSub.subscribe(GameServer.PubSub, Cache.invalidation_topic())
    {:ok, %{}}
  end

  @impl true
  def handle_info({:cache_invalidate, key, from_node}, state) do
    if from_node != Node.self() do
      _ = L1.delete(key)
    end

    {:noreply, state}
  end

  # Bump (don't delete) so the local counter stays monotonic — see
  # `GameServer.Cache.bump_version/1`. Only L1 is touched: a shared L2 was
  # already incremented by the originating node's write-through.
  def handle_info({:cache_bump_version, key, from_node}, state) do
    if from_node != Node.self() do
      _ = L1.incr(key, 1, default: 1)
    end

    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}
end
