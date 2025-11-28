defmodule GameServerWeb.LobbyChannel do
  @moduledoc """
  Channel for lobby realtime events.

  Topic: "lobby:<lobby_id>"

  Only users who are members of the lobby may join this channel. Membership is managed via the Lobbies context.

  ## Events pushed to clients

  - `"user_joined"` - A user joined the lobby. Payload: `%{user_id: integer}`
  - `"user_left"` - A user left the lobby. Payload: `%{user_id: integer}`
  - `"user_kicked"` - A user was kicked from the lobby. Payload: `%{user_id: integer}`
  - `"lobby_updated"` - The lobby settings were updated. Payload: lobby object
  - `"host_changed"` - The host changed. Payload: `%{new_host_id: integer}`
  """

  use Phoenix.Channel
  require Logger

  alias GameServer.Accounts.Scope
  alias GameServer.Lobbies

  @impl true
  def join("lobby:" <> lobby_id_str, _payload, socket) do
    current_scope = Map.get(socket.assigns, :current_scope)

    with {lobby_id, ""} <- Integer.parse(lobby_id_str),
         %Scope{user: %{id: user_id}} <- current_scope,
         %GameServer.Lobbies.Lobby{} <- Lobbies.get_lobby(lobby_id) do
      case GameServer.Repo.get_by(GameServer.Accounts.User, id: user_id, lobby_id: lobby_id) do
        %GameServer.Accounts.User{} ->
          # Subscribe to lobby PubSub events to forward to WebSocket clients
          Lobbies.subscribe_lobby(lobby_id)
          {:ok, assign(socket, :lobby_id, lobby_id)}

        _ ->
          Logger.info(
            "LobbyChannel: user #{user_id} attempted to join lobby #{lobby_id} but is not a member"
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
    push(socket, "lobby_updated", serialize_lobby(lobby))
    {:noreply, socket}
  end

  @impl true
  def handle_info({:host_changed, _lobby_id, new_host_id}, socket) do
    push(socket, "host_changed", %{new_host_id: new_host_id})
    {:noreply, socket}
  end

  # Ignore other messages
  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp serialize_lobby(lobby) do
    %{
      id: lobby.id,
      name: lobby.name,
      title: lobby.title,
      host_id: lobby.host_id,
      hostless: lobby.hostless,
      max_users: lobby.max_users,
      is_hidden: lobby.is_hidden,
      is_locked: lobby.is_locked,
      metadata: lobby.metadata || %{}
    }
  end
end
