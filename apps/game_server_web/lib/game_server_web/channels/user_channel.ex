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

  ## Notifications

  On join the channel pushes all undeleted notifications for the user in
  chronological order (oldest-first) as individual `"notification"` events.
  New notifications arriving while connected are also pushed as `"notification"`.

  ## Hook RPC

  Clients can call plugin hooks via `"call_hook"` push with reply:

      push("call_hook", %{plugin: "my_plugin", fn: "my_func", args: [1, 2]})
      → reply {:ok, %{data: result}} | {:error, %{error: reason}}

  This avoids the HTTP round-trip of `POST /api/v1/hooks/call` while the
  socket is connected.  The caller context (user) is injected automatically.
  """

  use Phoenix.Channel
  require Logger

  intercept ["updated"]

  alias GameServer.Accounts
  alias GameServer.Accounts.Scope
  alias GameServer.Accounts.User
  alias GameServer.Friends
  alias GameServer.Groups
  alias GameServer.Hooks.PluginManager
  alias GameServer.Lobbies
  alias GameServer.Notifications
  alias GameServer.Parties

  @impl true
  def join("user:" <> user_id_str, _payload, socket) do
    # ensure the socket has a current_scope assign created during socket connect
    current_scope = Map.get(socket.assigns, :current_scope)

    case Integer.parse(user_id_str) do
      {user_id, ""} ->
        case current_scope do
          %Scope{user: %User{id: ^user_id} = scoped_user} ->
            user = Accounts.get_user(user_id) || scoped_user
            GameServerWeb.ConnectionTracker.register(:user_channel, %{user_id: user_id})
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

  # ── Hook RPC via channel ─────────────────────────────────────────────────────

  @impl true
  def handle_in(
        "call_hook",
        %{"plugin" => plugin, "fn" => fn_name} = payload,
        socket
      )
      when is_binary(plugin) and is_binary(fn_name) do
    args = Map.get(payload, "args", [])
    args = if is_list(args), do: args, else: [args]

    reserved? =
      GameServer.Hooks.internal_hooks()
      |> Enum.any?(fn atom -> to_string(atom) == fn_name end)

    if reserved? do
      {:reply, {:error, %{error: "reserved_hook_name"}}, socket}
    else
      user = socket.assigns.current_scope.user

      case PluginManager.call_rpc(plugin, fn_name, args, caller: user) do
        {:ok, res} ->
          {:reply, {:ok, %{data: res}}, socket}

        {:error, reason} ->
          {:reply, {:error, %{error: to_string(reason)}}, socket}
      end
    end
  end

  # ── WebRTC signaling via channel ────────────────────────────────────────────

  @impl true
  def handle_in("webrtc:offer", %{"sdp" => _} = offer_json, socket) do
    webrtc_config = Application.get_env(:game_server_web, :webrtc, [])
    enabled? = Keyword.get(webrtc_config, :enabled, true)

    if enabled? do
      # Stop existing peer if re-negotiating
      if peer = Map.get(socket.assigns, :webrtc_peer) do
        if Process.alive?(peer), do: GameServerWeb.WebRTCPeer.close(peer)
      end

      {:ok, peer} =
        GameServerWeb.WebRTCPeer.start_link(
          user_id: socket.assigns.user_id,
          channel_pid: self()
        )

      GameServerWeb.WebRTCPeer.handle_offer(peer, offer_json)
      {:reply, {:ok, %{}}, assign(socket, :webrtc_peer, peer)}
    else
      {:reply, {:error, %{error: "webrtc_disabled"}}, socket}
    end
  end

  @impl true
  def handle_in("webrtc:ice", %{"candidate" => _} = candidate_json, socket) do
    case Map.get(socket.assigns, :webrtc_peer) do
      nil ->
        {:reply, {:error, %{error: "no_webrtc_session"}}, socket}

      peer ->
        GameServerWeb.WebRTCPeer.add_ice_candidate(peer, candidate_json)
        {:reply, {:ok, %{}}, socket}
    end
  end

  @impl true
  def handle_in("webrtc:send", %{"channel" => label, "data" => data}, socket) do
    case Map.get(socket.assigns, :webrtc_peer) do
      nil ->
        {:reply, {:error, %{error: "no_webrtc_session"}}, socket}

      peer ->
        case GameServerWeb.WebRTCPeer.send_data(peer, label, data) do
          :ok -> {:reply, {:ok, %{}}, socket}
          {:error, reason} -> {:reply, {:error, %{error: to_string(reason)}}, socket}
        end
    end
  end

  @impl true
  def handle_in("webrtc:close", _payload, socket) do
    case Map.get(socket.assigns, :webrtc_peer) do
      nil ->
        {:reply, {:ok, %{}}, socket}

      peer ->
        if Process.alive?(peer), do: GameServerWeb.WebRTCPeer.close(peer)
        {:reply, {:ok, %{}}, assign(socket, :webrtc_peer, nil)}
    end
  end

  @impl true
  def handle_in(_event, _payload, socket) do
    {:reply, {:error, %{error: "unknown_event"}}, socket}
  end

  # ── PubSub event forwarding ────────────────────────────────────────────────

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
    socket =
      case Accounts.set_user_online(user) do
        {:ok, updated_user} ->
          payload = Accounts.serialize_user_payload(updated_user)
          push(socket, "updated", payload)
          broadcast_online_status(updated_user.id, true)
          broadcast_member_presence(updated_user.id, true)
          assign(socket, :last_user_payload, payload)

        _ ->
          payload = Accounts.serialize_user_payload(user)
          push(socket, "updated", payload)
          assign(socket, :last_user_payload, payload)
      end

    # Subscribe to notifications PubSub
    Notifications.subscribe(user.id)

    # Push all existing (undeleted) notifications in chronological order
    push_existing_notifications(socket, user.id)

    {:noreply, socket}
  end

  # ── Notification PubSub events ──────────────────────────────────────────────

  @impl true
  def handle_info({:new_notification, notification}, socket) do
    push(socket, "notification", serialize_notification(notification))
    {:noreply, socket}
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

  @impl true
  def handle_info({:group_invite_accepted, payload}, socket) do
    push(socket, "group_invite_accepted", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:group_invite_cancelled, payload}, socket) do
    push(socket, "group_invite_cancelled", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:group_join_approved, payload}, socket) do
    push(socket, "group_join_approved", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:group_join_rejected, payload}, socket) do
    push(socket, "group_join_rejected", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:party_invite_accepted, payload}, socket) do
    push(socket, "party_invite_accepted", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:party_invite_declined, payload}, socket) do
    push(socket, "party_invite_declined", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:party_invite_cancelled, payload}, socket) do
    push(socket, "party_invite_cancelled", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:achievement_unlocked, user_achievement}, socket) do
    push(socket, "achievement_unlocked", serialize_user_achievement(user_achievement))
    {:noreply, socket}
  end

  @impl true
  def handle_info({:achievement_progress, user_achievement}, socket) do
    push(socket, "achievement_progress", serialize_user_achievement(user_achievement))
    {:noreply, socket}
  end

  # ── WebRTC peer messages ────────────────────────────────────────────────────

  @impl true
  def handle_info({:webrtc_answer, answer_json}, socket) do
    push(socket, "webrtc:answer", %{sdp: answer_json["sdp"], type: answer_json["type"]})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:webrtc_ice, candidate_json}, socket) do
    push(socket, "webrtc:ice", candidate_json)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:webrtc_data, channel_label, data}, socket) do
    push(socket, "webrtc:data", %{channel: channel_label, data: data})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:webrtc_channel_open, _ref, label}, socket) do
    push(socket, "webrtc:channel_open", %{channel: label})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:webrtc_channel_closed, _ref}, socket) do
    push(socket, "webrtc:channel_closed", %{})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:webrtc_connection_state, conn_state}, socket) do
    push(socket, "webrtc:state", %{state: to_string(conn_state)})
    {:noreply, socket}
  end

  # Catch-all for unknown messages
  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    user_id = Map.get(socket.assigns, :user_id)

    # Clean up WebRTC peer if active
    if peer = Map.get(socket.assigns, :webrtc_peer) do
      if Process.alive?(peer), do: GameServerWeb.WebRTCPeer.close(peer)
    end

    if user_id do
      # Unsubscribe from notifications
      Notifications.unsubscribe(user_id)

      # Only mark offline if no other user_channel processes remain for this user.
      # ConnectionTracker automatically unregisters the *current* process on exit,
      # but terminate runs before the process fully exits, so we subtract 1 (self).
      other_channels =
        GameServerWeb.ConnectionTracker.list_registered(:user_channel)
        |> Enum.count(fn {pid, meta} ->
          pid != self() and Map.get(meta, :user_id) == user_id
        end)

      if other_channels == 0 do
        case Accounts.set_user_offline(user_id) do
          {:ok, _} ->
            broadcast_online_status(user_id, false)
            broadcast_member_presence(user_id, false)

          _ ->
            :ok
        end
      end
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Push all existing undeleted notifications for the user, ordered oldest-first.
  defp push_existing_notifications(socket, user_id) do
    notifications = Notifications.list_notifications(user_id, page: 1, page_size: 1000)

    Enum.each(notifications, fn notification ->
      push(socket, "notification", serialize_notification(notification))
    end)
  end

  # Broadcast online/offline status change to all accepted friends' user channels.
  defp broadcast_online_status(user_id, online?) do
    event = if online?, do: "friend_online", else: "friend_offline"
    user = Accounts.get_user(user_id)

    payload =
      if user do
        User.serialize_brief(user) |> Map.put(:user_id, user_id)
      else
        %{user_id: user_id, display_name: "", is_online: online?}
      end

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

  defp serialize_notification(notification) do
    sender = if Ecto.assoc_loaded?(notification.sender), do: notification.sender, else: nil

    %{
      id: notification.id,
      sender_id: notification.sender_id,
      sender_name: if(sender, do: sender.display_name || "", else: ""),
      recipient_id: notification.recipient_id,
      title: notification.title,
      content: notification.content || "",
      metadata: notification.metadata || %{},
      inserted_at: notification.inserted_at
    }
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

  defp serialize_user_achievement(ua) do
    %{
      id: ua.id,
      user_id: ua.user_id,
      achievement_id: ua.achievement_id,
      progress: ua.progress,
      unlocked_at: ua.unlocked_at,
      metadata: ua.metadata || %{},
      inserted_at: ua.inserted_at,
      updated_at: ua.updated_at
    }
  end

  # Broadcast member_online/member_offline to the user's current lobby, party, and group channels.
  defp broadcast_member_presence(user_id, online?) do
    user = Accounts.get_user(user_id)
    event = if online?, do: :member_online, else: :member_offline

    if user do
      if user.lobby_id do
        Lobbies.broadcast_member_presence(user.lobby_id, {event, user_id})
      end

      if user.party_id do
        Parties.broadcast_member_presence(user.party_id, {event, user_id})
      end

      for group_id <- Groups.user_group_ids(user_id) do
        Groups.broadcast_member_presence(group_id, {event, user_id})
      end
    end
  end
end
