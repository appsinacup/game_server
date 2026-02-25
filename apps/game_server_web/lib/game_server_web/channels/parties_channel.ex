defmodule GameServerWeb.PartiesChannel do
  @moduledoc """
  Channel for broadcasting global party list events.

  Topic: "parties"

  Clients may join this topic to receive real-time notifications when parties
  are created, updated, or deleted.

  ## Events pushed to clients

  - `"party_created"` - A new party was created. Payload: `%{party_id: integer}`
  - `"party_updated"` - A party was updated. Payload: `%{party_id: integer}`
  - `"party_deleted"` - A party was deleted. Payload: `%{party_id: integer}`
  """

  use Phoenix.Channel

  alias GameServer.Parties

  @impl true
  def join("parties", _payload, socket) do
    # Allow authenticated sockets to subscribe to global party events
    Parties.subscribe_parties()
    {:ok, socket}
  end

  @impl true
  def handle_info({:party_created, party_id}, socket) do
    push(socket, "party_created", %{party_id: party_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:party_updated, party_id}, socket) when is_integer(party_id) do
    push(socket, "party_updated", %{party_id: party_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:party_deleted, party_id}, socket) do
    push(socket, "party_deleted", %{party_id: party_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}
end
