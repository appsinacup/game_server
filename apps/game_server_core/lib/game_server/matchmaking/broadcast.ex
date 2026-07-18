defmodule GameServer.Matchmaking.Broadcast do
  @moduledoc """
  Broadcasts matchmaking events to users.
  """

  alias GameServer.Matchmaking.Constants
  alias GameServerWeb.Endpoint

  @doc """
  Notifies every matched user that a lobby has been found.
  """
  @spec match_found([map()], Ecto.UUID.t()) :: :ok
  def match_found(tickets, lobby_id) do
    first = hd(tickets)

    Enum.each(tickets, fn ticket ->
      Endpoint.broadcast(
        "user:#{ticket.user_id}",
        Constants.event_found(),
        %{
          lobby_id: lobby_id,
          match_params: first.match_params
        }
      )
    end)
  end
end
