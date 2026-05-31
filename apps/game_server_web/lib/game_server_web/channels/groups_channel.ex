defmodule GameServerWeb.GroupsChannel do
  @moduledoc """
  Channel for broadcasting global group list events.

  Topic: "groups"

  Clients may join this topic to receive real-time notifications when groups
  are created, updated, or deleted. Hidden groups are excluded from broadcasts.

  ## Events pushed to clients

  - `"group_created"` - A new group was created. Payload: group object
  - `"group_updated"` - A group was updated. Payload: group object
  - `"group_deleted"` - A group was deleted. Payload: `%{id: integer}`
  """

  use Phoenix.Channel

  alias GameServer.Groups
  alias GameServerWeb.PayloadDelta
  alias GameServerWeb.Serializers

  @impl true
  def join("groups", _payload, socket) do
    GameServerWeb.ConnectionTracker.register(:groups_channel)
    Groups.subscribe_groups()
    {:ok, socket}
  end

  @impl true
  def handle_in(_event, _payload, socket),
    do: {:stop, :normal, {:error, %{error: "unknown_event"}}, socket}

  @impl true
  def handle_info({:group_created, group}, socket) do
    # Don't broadcast hidden groups to the public list channel
    if group.type != "hidden" do
      payload = Serializers.serialize_group(group)
      push(socket, "group_created", payload)
      {:noreply, put_group_payload(socket, payload)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:group_updated, group}, socket) do
    if group.type != "hidden" do
      payload = Serializers.serialize_group(group)
      last_payload = get_group_payload(socket, payload.id)

      case PayloadDelta.payload_delta(last_payload, payload) do
        nil ->
          {:noreply, socket}

        delta_payload ->
          push(socket, "group_updated", delta_payload)
          {:noreply, put_group_payload(socket, payload)}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:group_deleted, group_id}, socket) do
    push(socket, "group_deleted", %{id: group_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp get_group_payload(socket, group_id) do
    socket.assigns
    |> Map.get(:last_group_payloads, %{})
    |> Map.get(group_id)
  end

  defp put_group_payload(socket, payload) do
    payloads = Map.get(socket.assigns, :last_group_payloads, %{})
    assign(socket, :last_group_payloads, Map.put(payloads, payload.id, payload))
  end
end
