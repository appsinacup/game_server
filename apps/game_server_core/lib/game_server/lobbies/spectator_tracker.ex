defmodule GameServer.Lobbies.SpectatorTracker do
  @moduledoc """
  Lightweight ETS-based tracker for lobby spectators.

  Spectators are users connected to a lobby channel who are not members.
  This module tracks them in-memory (no persistence) so we can show spectator
  counts in admin panels and API responses.
  """
  use GenServer

  @table __MODULE__

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :bag, :public, read_concurrency: true])
    {:ok, nil}
  end

  @doc "Track a spectator joining a lobby."
  @spec track(integer(), integer()) :: true
  def track(lobby_id, user_id) do
    :ets.insert(@table, {lobby_id, user_id})
  end

  @doc "Remove a spectator from a lobby."
  @spec untrack(integer(), integer()) :: true
  def untrack(lobby_id, user_id) do
    :ets.delete_object(@table, {lobby_id, user_id})
  end

  @doc "Count spectators in a lobby."
  @spec count(integer()) :: non_neg_integer()
  def count(lobby_id) do
    :ets.select_count(@table, [{{lobby_id, :_}, [], [true]}])
  end

  @doc "Count spectators for multiple lobbies at once. Returns `%{lobby_id => count}`."
  @spec counts(list(integer())) :: %{integer() => non_neg_integer()}
  def counts(lobby_ids) when is_list(lobby_ids) do
    Map.new(lobby_ids, fn id -> {id, count(id)} end)
  end

  @doc "List spectator user IDs for a lobby."
  @spec list(integer()) :: list(integer())
  def list(lobby_id) do
    :ets.match(@table, {lobby_id, :"$1"}) |> List.flatten()
  end

  @doc "Remove all spectators for a given lobby (e.g. when lobby is deleted)."
  @spec untrack_all(integer()) :: true
  def untrack_all(lobby_id) do
    :ets.match_delete(@table, {lobby_id, :_})
  end
end
