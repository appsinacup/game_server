defmodule GameServerWeb.UserChannel do
  @moduledoc """
  Channel for sending per-user realtime updates (e.g. metadata changes).

  Topic: "user:<user_id>"
  Clients must authenticate the socket connection (JWT) and may only join topics belonging to their own user id.
  """

  use Phoenix.Channel
  require Logger

  alias GameServer.Accounts
  alias GameServer.Accounts.Scope
  alias GameServer.Accounts.User

  @impl true
  def join("user:" <> user_id_str, _payload, socket) do
    # ensure the socket has a current_scope assign created during socket connect
    current_scope = Map.get(socket.assigns, :current_scope)

    case Integer.parse(user_id_str) do
      {user_id, ""} ->
        case current_scope do
          %Scope{user: %User{id: ^user_id} = scoped_user} ->
            user = Accounts.get_user(user_id) || scoped_user
            send(self(), {:after_join, user})
            {:ok, assign(socket, :user_id, user_id)}

          _ ->
            Logger.warning("UserChannel: unauthorized join attempt for user=#{user_id}")
            {:error, %{reason: "unauthorized"}}
        end

      _ ->
        {:error, %{reason: "invalid topic"}}
    end
  end

  @impl true
  def handle_out(event, payload, socket) do
    push(socket, event, payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:after_join, %User{} = user}, socket) do
    push(socket, "updated", Accounts.serialize_user_payload(user))
    {:noreply, socket}
  end
end
