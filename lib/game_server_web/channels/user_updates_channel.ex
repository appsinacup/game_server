defmodule GameServerWeb.UserUpdatesChannel do
  @moduledoc """
  Channel for sending per-user realtime updates (e.g. metadata changes).

  Topic: "user_updates:<user_id>"
  Clients must authenticate the socket connection (JWT) and may only join topics belonging to their own user id.
  """

  use Phoenix.Channel
  require Logger

  alias GameServer.Accounts.Scope

  @impl true
  def join("user_updates:" <> user_id_str, _payload, socket) do
    # ensure the socket has a current_scope assign created during socket connect
    current_scope = Map.get(socket.assigns, :current_scope)

    case Integer.parse(user_id_str) do
      {user_id, ""} ->
        case current_scope do
          %Scope{user: %{id: ^user_id}} = _scope ->
            {:ok, socket}

          _ ->
            Logger.warning("UserUpdatesChannel: unauthorized join attempt for user=#{user_id}")
            {:error, %{reason: "unauthorized"}}
        end

      _ ->
        {:error, %{reason: "invalid topic"}}
    end
  end
end
