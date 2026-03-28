defmodule GameServerWeb.LobbiesChannel do
  @moduledoc """
  Channel for broadcasting global lobby list events.

  Topic: "lobbies"

  Clients may join this topic to receive real-time notifications when lobbies
  are created/updated/deleted or when membership changes occur across lobbies.
  """

  use Phoenix.Channel

  alias GameServer.Lobbies

  @impl true
  def join("lobbies", _payload, socket) do
    # allow anonymous or authenticated sockets to subscribe to global lobby events
    GameServerWeb.ConnectionTracker.register(:lobbies_channel)
    Lobbies.subscribe_lobbies()
    {:ok, socket}
  end

  @impl true
  def handle_in(_event, _payload, socket),
    do: {:stop, :normal, {:error, %{error: "unknown_event"}}, socket}

  @impl true
  def handle_info({:lobby_created, lobby}, socket) do
    push(socket, "lobby_created", serialize_lobby(lobby))
    {:noreply, socket}
  end

  @impl true
  def handle_info({:lobby_updated, lobby}, socket) do
    push(socket, "lobby_updated", serialize_lobby(lobby))
    {:noreply, socket}
  end

  @impl true
  def handle_info({:lobby_deleted, lobby_id}, socket) do
    push(socket, "lobby_deleted", %{id: lobby_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:lobby_membership_changed, lobby_id}, socket) do
    push(socket, "lobby_membership_changed", %{id: lobby_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp serialize_lobby(lobby) do
    host_id = if is_nil(lobby.host_id), do: -1, else: lobby.host_id

    host_name =
      cond do
        is_nil(lobby.host_id) -> ""
        Ecto.assoc_loaded?(lobby.host) and lobby.host != nil -> lobby.host.display_name || ""
        true -> resolve_display_name(lobby.host_id)
      end

    %{
      id: lobby.id,
      title: lobby.title,
      host_id: host_id,
      host_name: host_name,
      hostless: lobby.hostless,
      max_users: lobby.max_users,
      is_hidden: lobby.is_hidden,
      is_locked: lobby.is_locked,
      metadata: lobby.metadata || %{},
      is_passworded: lobby.password_hash != nil
    }
  end

  defp resolve_display_name(nil), do: ""

  defp resolve_display_name(user_id) do
    case GameServer.Accounts.get_user(user_id) do
      %{display_name: name} when is_binary(name) -> name
      _ -> ""
    end
  end
end
