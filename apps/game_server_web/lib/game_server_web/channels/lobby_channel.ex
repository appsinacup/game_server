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
  - `"updated"` - The lobby settings were updated. Payload: lobby object
  - `"host_changed"` - The host changed. Payload: `%{new_host_id: integer}`
  - `"new_chat_message"` - A new chat message. Payload: chat message object
  """

  use Phoenix.Channel
  require Logger

  alias GameServer.Accounts
  alias GameServer.Accounts.Scope
  alias GameServer.Accounts.User
  alias GameServer.Chat
  alias GameServer.Lobbies
  alias GameServer.Lobbies.SpectatorTracker

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
          socket = subscribe_to_lobby(socket, lobby_id)
          send(self(), {:after_join, lobby})
          {:ok, socket |> assign(:lobby_id, lobby_id) |> assign(:spectator, false)}

        # Case 2: user is in a *different* lobby → reject (must listen to their own)
        is_struct(user, User) and is_integer(user.lobby_id) ->
          {:error, %{reason: "must_spectate_own_lobby"}}

        # Case 3: user is not in any lobby and lobby is spectatable → join as spectator
        Lobbies.spectatable?(lobby) ->
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

  # Handle PubSub messages and forward them to WebSocket clients

  @impl true
  def handle_info({:user_joined, _lobby_id, user_id}, socket) do
    push(socket, "user_joined", %{user_id: user_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:user_left, _lobby_id, user_id}, socket) do
    push(socket, "user_left", %{user_id: user_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:user_kicked, _lobby_id, user_id}, socket) do
    push(socket, "user_kicked", %{user_id: user_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:lobby_updated, lobby}, socket) do
    payload = serialize_lobby(lobby)
    last_payload = Map.get(socket.assigns, :last_lobby_payload)

    if last_payload == payload do
      {:noreply, socket}
    else
      push(socket, "updated", payload)
      {:noreply, assign(socket, :last_lobby_payload, payload)}
    end
  end

  @impl true
  def handle_info({:host_changed, _lobby_id, new_host_id}, socket) do
    push(socket, "host_changed", %{new_host_id: new_host_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:after_join, lobby}, socket) do
    payload = serialize_lobby(lobby) |> Map.put(:spectator, socket.assigns[:spectator] || false)
    push(socket, "updated", payload)
    {:noreply, assign(socket, :last_lobby_payload, payload)}
  end

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

  # Ignore other messages
  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    case socket.assigns do
      %{lobby_id: lobby_id, spectator: true} when is_integer(lobby_id) ->
        user_id = socket.assigns.current_scope.user.id
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

  defp serialize_lobby(lobby) do
    host_id = if is_nil(lobby.host_id), do: -1, else: lobby.host_id

    %{
      id: lobby.id,
      title: lobby.title,
      host_id: host_id,
      hostless: lobby.hostless,
      max_users: lobby.max_users,
      is_hidden: lobby.is_hidden,
      is_locked: lobby.is_locked,
      metadata: lobby.metadata || %{}
    }
  end

  defp serialize_chat_message(msg) do
    %{
      id: msg.id,
      content: msg.content,
      metadata: msg.metadata,
      sender_id: msg.sender_id,
      chat_type: msg.chat_type,
      chat_ref_id: msg.chat_ref_id,
      inserted_at: msg.inserted_at
    }
  end
end
