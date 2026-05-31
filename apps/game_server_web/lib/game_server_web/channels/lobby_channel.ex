defmodule GameServerWeb.LobbyChannel do
  @moduledoc """
  Channel for lobby realtime events.

  Topic: "lobby:<lobby_id>"

  Users may join this channel either as a **member** (their `lobby_id` matches)
  or as a **spectator** (the lobby is public: not hidden, not locked).

  Spectators receive all events (membership changes, updates, chat) but cannot
  perform any write operations.  A user who is already in a lobby can only join
  their own lobby's channel.

  ## Events pushed to clients

  - `"user_joined"` - A user joined the lobby. Payload: `%{user_id: integer}`
  - `"user_left"` - A user left the lobby. Payload: `%{user_id: integer}`
  - `"user_kicked"` - A user was kicked from the lobby. Payload: `%{user_id: integer}`
  - `"member_online"` - A lobby member came online. Payload: user brief object
  - `"member_offline"` - A lobby member went offline. Payload: user brief object
  - `"member_updated"` - A lobby member was updated. Payload: user brief object
  - `"updated"` - The lobby settings were updated. Payload: lobby object
  - `"host_changed"` - The host changed. Payload: `%{new_host_id: integer}`
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
  alias GameServer.Lobbies
  alias GameServer.Lobbies.SpectatorTracker
  alias GameServerWeb.PayloadDelta
  alias GameServerWeb.Serializers

  @impl true
  def join("lobby:" <> lobby_id_str, _payload, socket) do
    current_scope = Map.get(socket.assigns, :current_scope)

    with {lobby_id, ""} <- Integer.parse(lobby_id_str),
         %Scope{user: %{id: user_id}} <- current_scope,
         %GameServer.Lobbies.Lobby{} = lobby <- Lobbies.get_lobby(lobby_id) do
      user = Accounts.get_user(user_id)

      cond do
        # Case 1: user is a member of this lobby → join as member
        match?(%User{lobby_id: ^lobby_id}, user) ->
          GameServerWeb.ConnectionTracker.register(:lobby_channel, %{
            lobby_id: lobby_id,
            user_id: user_id
          })

          socket = subscribe_to_lobby(socket, lobby_id)
          send(self(), {:after_join, lobby})
          {:ok, socket |> assign(:lobby_id, lobby_id) |> assign(:spectator, false)}

        # Case 2: user is in a *different* lobby → reject (must listen to their own)
        is_struct(user, User) and is_integer(user.lobby_id) ->
          {:error, %{reason: "must_spectate_own_lobby"}}

        # Case 3: user is not in any lobby and lobby is spectatable → join as spectator
        Lobbies.spectatable?(lobby) ->
          GameServerWeb.ConnectionTracker.register(:lobby_channel, %{
            lobby_id: lobby_id,
            user_id: user_id,
            spectator: true
          })

          socket = subscribe_to_lobby(socket, lobby_id)
          SpectatorTracker.track(lobby_id, user_id)
          send(self(), {:after_join, lobby})
          {:ok, socket |> assign(:lobby_id, lobby_id) |> assign(:spectator, true)}

        # Case 4: lobby is hidden or locked → reject
        true ->
          {:error, %{reason: "not_spectatable"}}
      end
    else
      _ ->
        {:error, %{reason: "invalid_topic_or_unauthenticated"}}
    end
  end

  defp subscribe_to_lobby(socket, lobby_id) do
    if Map.get(socket.assigns, :subscribed_lobby, false) do
      socket
    else
      _ = Lobbies.unsubscribe_lobby(lobby_id)
      Lobbies.subscribe_lobby(lobby_id)
      Chat.subscribe_lobby_chat(lobby_id)
      assign(socket, :subscribed_lobby, true)
    end
  end

  @impl true
  def handle_in(_event, _payload, socket),
    do: {:stop, :normal, {:error, %{error: "unknown_event"}}, socket}

  # Handle PubSub messages and forward them to WebSocket clients

  @impl true
  def handle_info({:user_joined, _lobby_id, user_id}, socket) do
    user = Accounts.get_user(user_id)

    payload =
      if user do
        User.serialize_brief(user) |> Map.put(:user_id, user_id)
      else
        %{user_id: user_id, display_name: ""}
      end

    push(socket, "user_joined", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:user_left, _lobby_id, user_id}, socket) do
    push(socket, "user_left", %{user_id: user_id, display_name: Serializers.display_name(user_id)})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:user_kicked, _lobby_id, user_id}, socket) do
    push(socket, "user_kicked", %{
      user_id: user_id,
      display_name: Serializers.display_name(user_id)
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:lobby_updated, lobby}, socket) do
    payload = Serializers.serialize_lobby(lobby, include_members: true)
    last_payload = Map.get(socket.assigns, :last_lobby_payload)

    case PayloadDelta.payload_delta(last_payload, payload) do
      nil ->
        {:noreply, socket}

      delta_payload ->
        push(socket, "updated", delta_payload)
        {:noreply, assign(socket, :last_lobby_payload, payload)}
    end
  end

  @impl true
  def handle_info({:host_changed, _lobby_id, new_host_id}, socket) do
    push(socket, "host_changed", %{
      new_host_id: new_host_id,
      display_name: Serializers.display_name(new_host_id)
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:after_join, lobby}, socket) do
    payload =
      lobby
      |> Serializers.serialize_lobby(include_members: true)
      |> Map.put(:spectator, socket.assigns[:spectator] || false)

    push(socket, "updated", payload)
    {:noreply, assign(socket, :last_lobby_payload, payload)}
  end

  @impl true
  def handle_info({:new_chat_message, message}, socket) do
    push(socket, "new_chat_message", Serializers.serialize_chat_message(message))
    {:noreply, socket}
  end

  @impl true
  def handle_info({:chat_message_updated, message}, socket) do
    push(socket, "chat_message_updated", Serializers.serialize_chat_message(message))
    {:noreply, socket}
  end

  @impl true
  def handle_info({:chat_message_deleted, message}, socket) do
    push(socket, "chat_message_deleted", %{id: message.id})
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

    push(socket, ws_event, payload)
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
          push(socket, "member_updated", delta_payload)

          socket =
            assign(socket, :last_member_payloads, Map.put(last_payloads, user_id, payload))

          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  # Ignore other messages
  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    case socket.assigns do
      %{lobby_id: lobby_id, spectator: true, current_scope: %{user: %{id: user_id}}}
      when is_integer(lobby_id) ->
        SpectatorTracker.untrack(lobby_id, user_id)
        _ = Lobbies.unsubscribe_lobby(lobby_id)
        :ok

      %{lobby_id: lobby_id} when is_integer(lobby_id) ->
        _ = Lobbies.unsubscribe_lobby(lobby_id)
        _ = Chat.unsubscribe_lobby_chat(lobby_id)
        :ok

      _ ->
        :ok
    end
  end
end
