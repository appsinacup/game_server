defmodule GameServerWeb.PartyChannel do
  @moduledoc """
  Channel for party realtime events.

  Topic: "party:<party_id>"

  Only users who are members of the party may join this channel.
  Membership is determined by the user's `party_id` field.

  ## Events pushed to clients

  - `"member_joined"` - A user joined the party. Payload: `%{user_id: integer}`
  - `"member_left"` - A user left or was kicked from the party. Payload: `%{user_id: integer}`
  - `"updated"` - The party settings were updated. Payload: party object
  - `"disbanded"` - The party was disbanded. Payload: `%{party_id: integer}`
  - `"new_chat_message"` - A new chat message. Payload: chat message object
  - `"chat_message_updated"` - A chat message was updated. Payload: chat message object
  - `"chat_message_deleted"` - A chat message was deleted. Payload: `%{id: integer}`
  """

  use Phoenix.Channel
  require Logger

  alias GameServer.Accounts
  alias GameServer.Accounts.Scope
  alias GameServer.Accounts.User
  alias GameServer.Chat
  alias GameServer.Parties

  @impl true
  def join("party:" <> party_id_str, _payload, socket) do
    current_scope = Map.get(socket.assigns, :current_scope)

    with {party_id, ""} <- Integer.parse(party_id_str),
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

  # Handle PubSub messages and forward them to WebSocket clients

  @impl true
  def handle_info({:party_member_joined, _party_id, user_id}, socket) do
    push(socket, "member_joined", %{user_id: user_id, display_name: resolve_display_name(user_id)})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:party_member_left, _party_id, user_id}, socket) do
    push(socket, "member_left", %{user_id: user_id, display_name: resolve_display_name(user_id)})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:party_updated, %GameServer.Parties.Party{} = party}, socket) do
    payload = serialize_party(party)
    last_payload = Map.get(socket.assigns, :last_party_payload)

    if last_payload == payload do
      {:noreply, socket}
    else
      push(socket, "updated", payload)
      {:noreply, assign(socket, :last_party_payload, payload)}
    end
  end

  @impl true
  def handle_info({:party_updated, party_id}, socket) when is_integer(party_id) do
    case Parties.get_party(party_id) do
      nil ->
        {:noreply, socket}

      party ->
        payload = serialize_party(party)
        last_payload = Map.get(socket.assigns, :last_party_payload)

        if last_payload == payload do
          {:noreply, socket}
        else
          push(socket, "updated", payload)
          {:noreply, assign(socket, :last_party_payload, payload)}
        end
    end
  end

  @impl true
  def handle_info({:party_disbanded, party_id}, socket) do
    push(socket, "disbanded", %{party_id: party_id})
    {:noreply, socket}
  end

  # Chat messages forwarded from PubSub

  @impl true
  def handle_info({:new_chat_message, message}, socket) do
    push(socket, "new_chat_message", serialize_chat_message(message))
    {:noreply, socket}
  end

  @impl true
  def handle_info({:chat_message_updated, message}, socket) do
    push(socket, "chat_message_updated", serialize_chat_message(message))
    {:noreply, socket}
  end

  @impl true
  def handle_info({:chat_message_deleted, message}, socket) do
    push(socket, "chat_message_deleted", %{id: message.id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:after_join, nil}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:after_join, party}, socket) do
    payload = serialize_party(party)
    push(socket, "updated", payload)
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
      %{party_id: party_id} when is_integer(party_id) ->
        _ = Chat.unsubscribe_party_chat(party_id)
        _ = Parties.unsubscribe_party(party_id)
        :ok

      _ ->
        :ok
    end
  end

  defp serialize_chat_message(msg) do
    sender = if Ecto.assoc_loaded?(msg.sender), do: msg.sender, else: nil

    %{
      id: msg.id,
      content: msg.content,
      metadata: msg.metadata || %{},
      sender_id: msg.sender_id,
      sender_name: if(sender, do: sender.display_name || "", else: ""),
      chat_type: msg.chat_type,
      chat_ref_id: msg.chat_ref_id,
      inserted_at: msg.inserted_at
    }
  end

  defp serialize_party(party) do
    leader_name =
      cond do
        is_nil(party.leader_id) ->
          ""

        Ecto.assoc_loaded?(party.leader) and party.leader != nil ->
          party.leader.display_name || ""

        true ->
          resolve_display_name(party.leader_id)
      end

    %{
      id: party.id,
      leader_id: party.leader_id,
      leader_name: leader_name,
      max_size: party.max_size,
      code: party.code,
      metadata: party.metadata || %{}
    }
  end

  defp resolve_display_name(nil), do: ""

  defp resolve_display_name(user_id) do
    case Accounts.get_user(user_id) do
      %{display_name: name} when is_binary(name) -> name
      _ -> ""
    end
  end
end
