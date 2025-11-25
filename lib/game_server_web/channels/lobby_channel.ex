defmodule GameServerWeb.LobbyChannel do
  @moduledoc """
  Channel for lobby realtime events.

  Topic: "lobby:<lobby_id>"

  Only users who are members of the lobby may join this channel. Membership is managed via the Lobbies context.
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
          Logger.debug("LobbyChannel: user #{user_id} joined lobby #{lobby_id}")
          {:ok, socket}

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
end
