defmodule GameServerWeb.GroupChannel do
  @moduledoc """
  Channel for per-group realtime events.

  Topic: "group:<group_id>"

  Only users who are members of the group may join this channel.

  ## Events pushed to clients

  - `"member_joined"` - A user joined the group. Payload: `%{group_id, user_id}`
  - `"member_left"` - A user left the group. Payload: `%{group_id, user_id}`
  - `"member_kicked"` - A user was kicked. Payload: `%{group_id, user_id}`
  - `"member_promoted"` - A user was promoted to admin. Payload: `%{group_id, user_id}`
  - `"member_demoted"` - A user was demoted to member. Payload: `%{group_id, user_id}`
  - `"updated"` - Group settings were updated. Payload: group object
  - `"join_request_approved"` - A join request was approved. Payload: `%{group_id, user_id}`
  - `"join_request_rejected"` - A join request was rejected. Payload: `%{group_id, user_id}`
  """

  use Phoenix.Channel
  require Logger

  alias GameServer.Accounts.Scope
  alias GameServer.Groups

  @impl true
  def join("group:" <> group_id_str, _payload, socket) do
    current_scope = Map.get(socket.assigns, :current_scope)

    with {group_id, ""} <- Integer.parse(group_id_str),
         %Scope{user: %{id: user_id}} <- current_scope,
         true <- Groups.member?(group_id, user_id) do
      # Unsubscribe first to avoid duplicate subscriptions on reconnect
      Groups.unsubscribe_group(group_id)
      Groups.subscribe_group(group_id)

      group = Groups.get_group!(group_id)
      send(self(), {:after_join, group})

      {:ok, assign(socket, :group_id, group_id)}
    else
      _ ->
        {:error, %{reason: "not_a_member_or_invalid"}}
    end
  end

  # ── PubSub → WebSocket ────────────────────────────────────────────────────

  @impl true
  def handle_info({:after_join, group}, socket) do
    payload = serialize_group(group)
    push(socket, "updated", payload)
    {:noreply, assign(socket, :last_group_payload, payload)}
  end

  @impl true
  def handle_info({:group_updated, group}, socket) do
    payload = serialize_group(group)
    last_payload = Map.get(socket.assigns, :last_group_payload)

    if last_payload == payload do
      {:noreply, socket}
    else
      push(socket, "updated", payload)
      {:noreply, assign(socket, :last_group_payload, payload)}
    end
  end

  @impl true
  def handle_info({:member_joined, group_id, user_id}, socket) do
    push(socket, "member_joined", %{group_id: group_id, user_id: user_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:member_left, group_id, user_id}, socket) do
    push(socket, "member_left", %{group_id: group_id, user_id: user_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:member_kicked, group_id, user_id}, socket) do
    push(socket, "member_kicked", %{group_id: group_id, user_id: user_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:member_promoted, group_id, user_id}, socket) do
    push(socket, "member_promoted", %{group_id: group_id, user_id: user_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:member_demoted, group_id, user_id}, socket) do
    push(socket, "member_demoted", %{group_id: group_id, user_id: user_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:join_request_approved, group_id, user_id}, socket) do
    push(socket, "join_request_approved", %{group_id: group_id, user_id: user_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:join_request_rejected, group_id, user_id}, socket) do
    push(socket, "join_request_rejected", %{group_id: group_id, user_id: user_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def terminate(_reason, socket) do
    case socket.assigns do
      %{group_id: group_id} when is_integer(group_id) ->
        Groups.unsubscribe_group(group_id)
        :ok

      _ ->
        :ok
    end
  end

  # ── Helpers ────────────────────────────────────────────────────────────────

  defp serialize_group(group) do
    %{
      id: group.id,
      title: group.title,
      description: group.description,
      type: group.type,
      max_members: group.max_members,
      creator_id: group.creator_id,
      metadata: group.metadata || %{}
    }
  end
end
