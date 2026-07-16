defmodule GameServerWeb.PartyChannel do
  @moduledoc """
  Channel for party realtime events.

  Topic: "party:<party_id>"

  Only users who are members of the party may join this channel.
  Membership is determined by the user's `party_id` field.

  ## Events pushed to clients

  - `"member_joined"` - A user joined the party. Payload: `%{user_id: integer}`
  - `"member_left"` - A user left or was kicked from the party. Payload: `%{user_id: integer}`
  - `"member_online"` - A party member came online. Payload: user brief object
  - `"member_offline"` - A party member went offline. Payload: user brief object
  - `"member_updated"` - A party member was updated. Payload: user brief object
  - `"updated"` - The party settings were updated. Payload: party object
  - `"disbanded"` - The party was disbanded. Payload: `%{party_id: integer}`
  - `"new_chat_message"` - A new chat message. Payload: chat message object
  - `"chat_message_updated"` - A chat message was updated. Payload: chat message object
  - `"chat_message_deleted"` - A chat message was deleted. Payload: `%{id: integer}`
  """

  use Phoenix.Channel

  import GameServerWeb.ChannelPush
  require Logger

  alias GameServer.Accounts
  alias GameServer.Accounts.Scope
  alias GameServer.Accounts.User
  alias GameServer.Chat
  alias GameServer.Parties
  alias GameServerWeb.PayloadDelta
  alias GameServerWeb.Serializers

  @impl true
  def join("party:" <> party_id_str, _payload, socket) do
    current_scope = Map.get(socket.assigns, :current_scope)

    with {:ok, party_id} <- Ecto.UUID.cast(party_id_str),
         %Scope{user: %{id: user_id}} <- current_scope do
      case Accounts.get_user(user_id) do
        %User{party_id: ^party_id} ->
          # Subscribe to party PubSub events to forward to WebSocket clients
          socket =
            if Map.get(socket.assigns, :subscribed_party, false) do
              socket
            else
              _ = Parties.unsubscribe_party(party_id)
              Parties.subscribe_party(party_id)
              Chat.subscribe_party_chat(party_id)
              assign(socket, :subscribed_party, true)
            end

          GameServerWeb.ConnectionTracker.register(:party_channel, %{
            party_id: party_id,
            user_id: user_id
          })

          party = Parties.get_party(party_id)
          send(self(), {:after_join, party})
          {:ok, socket |> assign(:party_id, party_id)}

        _ ->
          Logger.info(
            "PartyChannel: user #{user_id} attempted to join party #{party_id} but is not a member"
          )

          {:error, %{reason: "not_a_member"}}
      end
    else
      _ ->
        {:error, %{reason: "invalid_topic_or_unauthenticated"}}
    end
  end

  @impl true
  def handle_in(_event, _payload, socket),
    do: {:stop, :normal, {:error, %{error: "unknown_event"}}, socket}

  # Handle PubSub messages and forward them to WebSocket clients

  @impl true
  def handle_info({:party_member_joined, _party_id, user_id}, socket) do
    user = Accounts.get_user(user_id)

    payload =
      if user do
        User.serialize_brief(user) |> Map.put(:user_id, user_id)
      else
        %{user_id: user_id, display_name: ""}
      end

    push_event(socket, "member_joined", payload)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:party_member_left, _party_id, user_id}, socket) do
    push_event(socket, "member_left", %{
      user_id: user_id,
      display_name: Serializers.display_name(user_id)
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:party_updated, %GameServer.Parties.Party{} = party}, socket) do
    payload = Serializers.serialize_party(party)
    last_payload = Map.get(socket.assigns, :last_party_payload)

    case PayloadDelta.payload_delta(last_payload, payload) do
      nil ->
        {:noreply, socket}

      delta_payload ->
        push_event(socket, "updated", delta_payload)
        {:noreply, assign(socket, :last_party_payload, payload)}
    end
  end

  @impl true
  def handle_info({:party_updated, party_id}, socket) when is_binary(party_id) do
    case Parties.get_party(party_id) do
      nil ->
        {:noreply, socket}

      party ->
        payload = Serializers.serialize_party(party)
        last_payload = Map.get(socket.assigns, :last_party_payload)

        case PayloadDelta.payload_delta(last_payload, payload) do
          nil ->
            {:noreply, socket}

          delta_payload ->
            push_event(socket, "updated", delta_payload)
            {:noreply, assign(socket, :last_party_payload, payload)}
        end
    end
  end

  @impl true
  def handle_info({:party_disbanded, party_id}, socket) do
    push_event(socket, "disbanded", %{party_id: party_id})
    {:noreply, socket}
  end

  # Chat messages forwarded from PubSub

  @impl true
  def handle_info({:new_chat_message, message}, socket) do
    push_event(socket, "new_chat_message", Serializers.serialize_chat_message(message))
    {:noreply, socket}
  end

  @impl true
  def handle_info({:chat_message_updated, message}, socket) do
    push_event(socket, "chat_message_updated", Serializers.serialize_chat_message(message))
    {:noreply, socket}
  end

  @impl true
  def handle_info({:chat_message_deleted, message}, socket) do
    push_event(socket, "chat_message_deleted", %{id: message.id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({event, user_id}, socket) when event in [:member_online, :member_offline] do
    user = Accounts.get_user(user_id)
    ws_event = if event == :member_online, do: "member_online", else: "member_offline"

    payload =
      if user do
        User.serialize_brief(user) |> Map.put(:user_id, user_id)
      else
        %{user_id: user_id, display_name: "", is_online: event == :member_online}
      end

    push_event(socket, ws_event, payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:member_updated, user_id}, socket) do
    user = Accounts.get_user(user_id)

    if user do
      payload = User.serialize_brief(user) |> Map.put(:user_id, user_id)
      last_payloads = Map.get(socket.assigns, :last_member_payloads, %{})
      last_payload = Map.get(last_payloads, user_id)

      case PayloadDelta.payload_delta(last_payload, payload) do
        nil ->
          {:noreply, socket}

        delta_payload ->
          push_event(socket, "member_updated", delta_payload)

          socket =
            assign(socket, :last_member_payloads, Map.put(last_payloads, user_id, payload))

          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:after_join, nil}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:after_join, party}, socket) do
    payload = Serializers.serialize_party(party)
    push_event(socket, "updated", payload)
    {:noreply, assign(socket, :last_party_payload, payload)}
  end

  # Ignore other messages
  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    case socket.assigns do
      %{party_id: party_id} when is_binary(party_id) ->
        _ = Chat.unsubscribe_party_chat(party_id)
        _ = Parties.unsubscribe_party(party_id)
        :ok

      _ ->
        :ok
    end
  end
end
