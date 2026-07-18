defmodule GameServerWeb.LobbiesChannel do
  @moduledoc """
  Channel for broadcasting global lobby list events.

  Topic: "lobbies"

  Clients may join this topic to receive real-time notifications when lobbies
  are created/updated/deleted or when membership changes occur across lobbies.
  """

  use Phoenix.Channel

  alias GameServer.Lobbies
  alias GameServerWeb.PayloadDelta
  alias GameServerWeb.Plugs.FeatureGate
  alias GameServerWeb.Serializers

  @impl true
  def join("lobbies", _payload, socket) do
    # Same flag as GET /api/v1/lobbies — the feed must not outlive the API.
    if FeatureGate.enabled?("LIST_LOBBIES_ENABLED", true) do
      GameServerWeb.ConnectionTracker.register(:lobbies_channel)
      Lobbies.subscribe_lobbies()
      {:ok, socket}
    else
      {:error, %{reason: "listing_disabled"}}
    end
  end

  @impl true
  def handle_in(_event, _payload, socket),
    do: {:stop, :normal, {:error, %{error: "unknown_event"}}, socket}

  @impl true
  def handle_info({:lobby_created, lobby}, socket) do
    payload = Serializers.serialize_lobby(lobby, include_passworded: true)
    push(socket, "lobby_created", payload)
    {:noreply, put_lobby_payload(socket, payload)}
  end

  @impl true
  def handle_info({:lobby_updated, lobby}, socket) do
    payload = Serializers.serialize_lobby(lobby, include_passworded: true)
    last_payload = get_lobby_payload(socket, payload.id)

    case PayloadDelta.payload_delta(last_payload, payload) do
      nil ->
        {:noreply, socket}

      delta_payload ->
        push(socket, "lobby_updated", delta_payload)
        {:noreply, put_lobby_payload(socket, payload)}
    end
  end

  @impl true
  def handle_info({:lobby_deleted, lobby_id}, socket) do
    push(socket, "lobby_deleted", %{id: lobby_id})
    {:noreply, drop_lobby_payload(socket, lobby_id)}
  end

  @impl true
  def handle_info({:lobby_membership_changed, lobby_id}, socket) do
    push(socket, "lobby_membership_changed", %{id: lobby_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp get_lobby_payload(socket, lobby_id) do
    socket.assigns
    |> Map.get(:last_lobby_payloads, %{})
    |> Map.get(lobby_id)
  end

  defp put_lobby_payload(socket, payload) do
    payloads = Map.get(socket.assigns, :last_lobby_payloads, %{})
    assign(socket, :last_lobby_payloads, Map.put(payloads, payload.id, payload))
  end

  # Prune the delta cache when a lobby goes away so a long-lived list socket
  # doesn't accumulate an entry for every lobby ever seen.
  defp drop_lobby_payload(socket, lobby_id) do
    payloads = Map.get(socket.assigns, :last_lobby_payloads, %{})
    assign(socket, :last_lobby_payloads, Map.delete(payloads, lobby_id))
  end
end
