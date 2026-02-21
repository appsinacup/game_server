defmodule GameServerWeb.UserChannel do
  @moduledoc """
  Channel for sending per-user realtime updates (e.g. metadata changes).

  Topic: "user:<user_id>"
  Clients must authenticate the socket connection (JWT) and may only join topics belonging to their own user id.

  ## Online presence

  When a user joins the channel their `is_online` flag is set to `true` in the
  database and a `"friend_online"` event is pushed to every accepted friend's
  channel.  When the last channel process for a user terminates the flag is
  reset and a `"friend_offline"` event is pushed.
  """

  use Phoenix.Channel
  require Logger

  intercept ["updated"]

  alias GameServer.Accounts
  alias GameServer.Accounts.Scope
  alias GameServer.Accounts.User
  alias GameServer.Friends

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
  def handle_out("updated", payload, socket) do
    last_payload = Map.get(socket.assigns, :last_user_payload)

    if last_payload == payload do
      {:noreply, socket}
    else
      push(socket, "updated", payload)
      {:noreply, assign(socket, :last_user_payload, payload)}
    end
  end

  @impl true
  def handle_out(event, payload, socket) do
    push(socket, event, payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:after_join, %User{} = user}, socket) do
    # Mark user online in DB
    case Accounts.set_user_online(user) do
      {:ok, updated_user} ->
        payload = Accounts.serialize_user_payload(updated_user)
        push(socket, "updated", payload)
        broadcast_online_status(updated_user.id, true)
        {:noreply, assign(socket, :last_user_payload, payload)}

      _ ->
        payload = Accounts.serialize_user_payload(user)
        push(socket, "updated", payload)
        {:noreply, assign(socket, :last_user_payload, payload)}
    end
  end

  @impl true
  def terminate(_reason, socket) do
    user_id = Map.get(socket.assigns, :user_id)

    if user_id do
      case Accounts.set_user_offline(user_id) do
        {:ok, _} ->
          broadcast_online_status(user_id, false)

        _ ->
          :ok
      end
    end

    :ok
  end

  # Broadcast online/offline status change to all accepted friends' user channels.
  defp broadcast_online_status(user_id, online?) do
    event = if online?, do: "friend_online", else: "friend_offline"

    payload = %{
      user_id: user_id,
      is_online: online?
    }

    friend_ids = Friends.friend_ids(user_id)

    Enum.each(friend_ids, fn friend_id ->
      topic = "user:#{friend_id}"

      Phoenix.PubSub.broadcast(
        GameServer.PubSub,
        topic,
        %Phoenix.Socket.Broadcast{topic: topic, event: event, payload: payload}
      )
    end)
  end
end
