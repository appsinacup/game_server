defmodule GameServer.Matchmaking.Match do
  @moduledoc """
  Creates the lobby for a claimed match and notifies the players.

  Runs *outside* the sweep's cluster lock: `Lobbies.create_lobby/1` and
  `join_lobby/2` fire plugin hooks and broadcasts, which must never run
  inside a transaction. The tickets are already claimed (status `matched`),
  so no other node can pick them up meanwhile; on failure they are requeued
  and retried on the next tick.

  Errors return tuples instead of raising, so one bad match never aborts the
  rest of the sweep.
  """

  require Logger

  alias GameServer.Lobbies
  alias GameServer.Matchmaking
  alias GameServer.Matchmaking.Broadcast
  alias GameServer.Types

  @doc """
  Creates a hidden lobby for the claimed tickets, seats the users, locks the
  lobby, records it on the tickets and broadcasts `match_found`.
  """
  @spec create([Types.matchmaking_ticket()]) :: {:ok, Ecto.UUID.t()} | {:error, term()}
  def create(tickets) do
    first = hd(tickets)

    case Lobbies.create_lobby(%{
           max_users: first.max_players,
           is_hidden: true,
           is_locked: false,
           hostless: true,
           metadata: %{match_params: first.match_params}
         }) do
      {:ok, lobby} ->
        seat_players(tickets, lobby)

      {:error, reason} ->
        Logger.warning("matchmaking: lobby creation failed: #{inspect(reason)}")
        _ = Matchmaking.requeue(tickets)
        {:error, reason}
    end
  end

  defp seat_players(tickets, lobby) do
    failed =
      Enum.reject(tickets, fn ticket ->
        match?({:ok, _}, Lobbies.join_lobby(ticket.user, lobby.id))
      end)

    if failed == [] do
      _ = Lobbies.update_lobby(lobby, %{is_locked: true})
      :ok = Matchmaking.assign_lobby(tickets, lobby.id)
      Broadcast.match_found(tickets, lobby.id)

      GameServer.Async.run(fn ->
        GameServer.Hooks.internal_call(:after_matchmaking_matched, [tickets, lobby.id])
      end)

      {:ok, lobby.id}
    else
      # A player could not be seated (banned, already in a lobby, ...). Drop
      # the half-built lobby, cancel the unseatable tickets, and requeue the
      # rest so they simply wait for the next tick.
      Logger.warning(
        "matchmaking: #{length(failed)} of #{length(tickets)} joins failed; dropping lobby #{lobby.id}"
      )

      _ = Lobbies.delete_lobby(lobby)
      failed_ids = MapSet.new(failed, & &1.id)

      _ = Matchmaking.discard(failed)
      _ = tickets |> Enum.reject(&MapSet.member?(failed_ids, &1.id)) |> Matchmaking.requeue()

      {:error, :join_failed}
    end
  end
end
