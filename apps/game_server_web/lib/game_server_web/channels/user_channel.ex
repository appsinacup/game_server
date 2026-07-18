defmodule GameServerWeb.UserChannel do
  @moduledoc """
  Channel for sending per-user realtime updates (e.g. metadata changes).

  Topic: "user:<user_id>"
  Clients must authenticate the socket connection (JWT) and may only join topics belonging to their own user id.

  ## Online presence

  When a user joins the channel their `is_online` flag is set to `true` in the
  database and a `"friend_updated"` event is pushed to every accepted friend's
  channel.  When the last channel process for a user terminates the flag is
  reset and pushed through the same `"friend_updated"` event.

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

  ## KV RPC

  Clients can subscribe to a key/scope and receive `"kv_updated"` /
  `"kv_deleted"` pushes when that KV entry changes:

      push("kv:subscribe", %{key: "my_key", user_id: 123})
      -> reply {:ok, %{subscribed: true, ...}}
  """

  use Phoenix.Channel
  require Logger

  intercept ["updated", "friend_updated"]

  alias GameServer.Accounts
  alias GameServer.Accounts.Scope
  alias GameServer.Accounts.User
  alias GameServer.Friends
  alias GameServer.Groups
  alias GameServer.Hooks
  alias GameServer.Hooks.PluginManager
  alias GameServer.KV
  alias GameServer.Lobbies
  alias GameServer.Matchmaking
  alias GameServer.Notifications
  alias GameServer.Parties
  alias GameServerWeb.PayloadDelta
  alias GameServerWeb.Serializers

  # WebSocket message rate limits (per user) — defaults, overridden by config
  @default_ws_rate_limit 300
  @default_ws_rate_window :timer.seconds(10)

  # Separate ICE candidate budget — prevents ICE flooding from starving
  # other channel events. A typical WebRTC session sends 5–30 candidates.
  @default_ice_rate_limit 150
  @default_ice_rate_window :timer.seconds(30)

  # Interval for periodic presence refresh (keeps StalePresenceSweeper from
  # marking actively connected users as offline).  Default: 3 minutes.
  @presence_refresh_interval :timer.minutes(3)

  @impl true
  def join("user:" <> user_id_str, _payload, socket) do
    # ensure the socket has a current_scope assign created during socket connect
    current_scope = Map.get(socket.assigns, :current_scope)

    case Ecto.UUID.cast(user_id_str) do
      {:ok, user_id} ->
        case current_scope do
          %Scope{user: %User{id: ^user_id} = scoped_user} ->
            user = Accounts.get_user(user_id) || scoped_user
            GameServerWeb.ConnectionTracker.register_user_channel(user_id)
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
    with :ok <- check_ws_rate_limit(socket) do
      args = Map.get(payload, "args", [])
      args = if is_list(args), do: args, else: [args]

      reserved? =
        GameServer.Hooks.internal_hooks()
        |> Enum.any?(fn atom -> to_string(atom) == fn_name end)

      if reserved? do
        {:reply, {:error, %{error: "reserved_hook_name"}}, socket}
      else
        # Re-fetch user from DB to get current lobby_id / state
        user = Accounts.get_user(socket.assigns.user_id) || socket.assigns.current_scope.user

        case PluginManager.call_rpc(plugin, fn_name, args, caller: user) do
          {:ok, res} ->
            {:reply, {:ok, %{data: res}}, socket}

          {:error, reason} ->
            {:reply, {:error, %{error: to_string(reason)}}, socket}
        end
      end
    end
  end

  # ── KV subscriptions via channel ────────────────────────────────────────────

  @impl true
  def handle_in("kv:subscribe", %{"key" => key} = payload, socket) when is_binary(key) do
    with :ok <- check_ws_rate_limit(socket) do
      user_id = parse_optional_id(Map.get(payload, "user_id"))
      lobby_id = parse_optional_id(Map.get(payload, "lobby_id"))

      if kv_read_allowed?(socket, key, user_id, lobby_id) do
        :ok = KV.subscribe(key, user_id: user_id, lobby_id: lobby_id)
        {:reply, {:ok, kv_subscribe_reply(key, user_id, lobby_id, payload)}, socket}
      else
        {:reply, {:error, kv_reply_payload(%{error: "forbidden"}, payload)}, socket}
      end
    end
  end

  @impl true
  def handle_in("kv:subscribe", payload, socket) do
    with :ok <- check_ws_rate_limit(socket) do
      {:reply, {:error, kv_reply_payload(%{error: "invalid_key"}, payload)}, socket}
    end
  end

  @impl true
  def handle_in("kv:unsubscribe", %{"key" => key} = payload, socket) when is_binary(key) do
    with :ok <- check_ws_rate_limit(socket) do
      user_id = parse_optional_id(Map.get(payload, "user_id"))
      lobby_id = parse_optional_id(Map.get(payload, "lobby_id"))

      :ok = KV.unsubscribe(key, user_id: user_id, lobby_id: lobby_id)

      {:reply,
       {:ok,
        kv_reply_payload(
          %{unsubscribed: true, key: key, user_id: user_id, lobby_id: lobby_id},
          payload
        )}, socket}
    end
  end

  @impl true
  def handle_in("kv:unsubscribe", payload, socket) do
    with :ok <- check_ws_rate_limit(socket) do
      {:reply, {:error, kv_reply_payload(%{error: "invalid_key"}, payload)}, socket}
    end
  end

  # ── WebRTC signaling via channel ────────────────────────────────────────────

  @impl true
  def handle_in("webrtc:offer", %{"sdp" => _} = offer_json, socket) do
    with :ok <- check_ws_rate_limit(socket),
         :ok <- check_webrtc_enabled() do
      stop_existing_peer(socket)

      {:ok, peer} =
        GameServerWeb.WebRTCPeer.start_link(
          user_id: socket.assigns.user_id,
          channel_pid: self()
        )

      GameServerWeb.WebRTCPeer.handle_offer(peer, offer_json)
      {:reply, {:ok, %{}}, assign(socket, :webrtc_peer, peer)}
    else
      {:error, %{error: _} = err} -> {:reply, {:error, err}, socket}
      other -> other
    end
  end

  @impl true
  def handle_in("webrtc:ice", %{"candidate" => _} = candidate_json, socket) do
    with :ok <- check_ws_rate_limit(socket),
         :ok <- check_ice_rate_limit(socket) do
      case Map.get(socket.assigns, :webrtc_peer) do
        nil ->
          {:reply, {:error, %{error: "no_webrtc_session"}}, socket}

        peer ->
          GameServerWeb.WebRTCPeer.add_ice_candidate(peer, candidate_json)
          {:reply, {:ok, %{}}, socket}
      end
    end
  end

  @impl true
  def handle_in("webrtc:close", _payload, socket) do
    with :ok <- check_ws_rate_limit(socket) do
      case Map.get(socket.assigns, :webrtc_peer) do
        nil ->
          {:reply, {:ok, %{}}, socket}

        peer ->
          if Process.alive?(peer), do: GameServerWeb.WebRTCPeer.close(peer)
          {:reply, {:ok, %{}}, assign(socket, :webrtc_peer, nil)}
      end
    end
  end

  # ── Matchmaking via channel ───────────────────────────────────────────────────

  @impl true
  def handle_in("matchmaking:join", payload, socket) do
    with :ok <- check_ws_rate_limit(socket) do
      match_params = parse_match_params(payload)
      min_players = parse_optional_int(Map.get(payload || %{}, "min_players"))
      max_players = parse_optional_int(Map.get(payload || %{}, "max_players"))

      case Matchmaking.join(
             Accounts.get_user(socket.assigns.user_id) || socket.assigns.current_scope.user,
             match_params,
             min_players,
             max_players
           ) do
        {:ok, ticket} ->
          {:reply, {:ok, %{ticket_id: ticket.id, status: ticket.status}}, socket}

        {:error, changeset} ->
          {:reply, {:error, %{error: "invalid_ticket", details: format_errors(changeset)}},
           socket}
      end
    end
  end

  @impl true
  def handle_in("matchmaking:cancel", _payload, socket) do
    with :ok <- check_ws_rate_limit(socket) do
      :ok = Matchmaking.cancel(socket.assigns.user_id)
      {:reply, {:ok, %{status: "cancelled"}}, socket}
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

    case PayloadDelta.payload_delta(last_payload, payload) do
      nil ->
        {:noreply, socket}

      delta_payload ->
        push(socket, "updated", delta_payload)
        {:noreply, assign(socket, :last_user_payload, payload)}
    end
  end

  @impl true
  def handle_out("friend_updated", payload, socket) do
    user_id = friend_user_id(payload)

    if is_nil(user_id) do
      {:noreply, socket}
    else
      key = to_string(user_id)
      last_friend_payloads = Map.get(socket.assigns, :last_friend_payloads, %{})
      last_payload = Map.get(last_friend_payloads, key)
      payload = preserve_friendship_id(last_payload, payload)

      case friend_payload_delta(last_payload, payload) do
        nil ->
          {:noreply, socket}

        delta_payload ->
          push(socket, "friend_updated", %{friends: %{key => delta_payload}})

          {:noreply,
           assign(socket, :last_friend_payloads, Map.put(last_friend_payloads, key, payload))}
      end
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
      case Accounts.set_user_online(user.id) do
        {:ok, updated_user} ->
          payload = Accounts.serialize_user_payload(updated_user)
          push(socket, "updated", payload)
          broadcast_member_presence(updated_user.id, true)
          assign(socket, :last_user_payload, payload)

        _ ->
          payload = Accounts.serialize_user_payload(user)
          push(socket, "updated", payload)
          assign(socket, :last_user_payload, payload)
      end

    # Subscribe to notifications PubSub
    Notifications.subscribe(user.id)

    socket = push_initial_friend_update(socket, user.id)

    # Push all existing (undeleted) notifications in chronological order
    push_existing_notifications(socket, user.id)

    # Start periodic presence refresh so the StalePresenceSweeper doesn't
    # mark this user offline while the WebSocket is still open.
    Process.send_after(self(), :refresh_presence, @presence_refresh_interval)

    {:noreply, socket}
  end

  # ── Periodic presence refresh ───────────────────────────────────────────────

  @impl true
  def handle_info(:refresh_presence, socket) do
    user_id = socket.assigns[:user_id]

    if user_id do
      Accounts.touch_last_seen_by_id(user_id)
    end

    Process.send_after(self(), :refresh_presence, @presence_refresh_interval)
    {:noreply, socket}
  end

  # ── KV PubSub events ────────────────────────────────────────────────────────

  @impl true
  def handle_info({:kv_updated, payload}, socket) do
    key = Map.get(payload, :key)
    user_id = Map.get(payload, :user_id)
    lobby_id = Map.get(payload, :lobby_id)

    if is_binary(key) and kv_read_allowed?(socket, key, user_id, lobby_id) do
      push(socket, "kv_updated", payload)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:kv_deleted, payload}, socket) do
    key = Map.get(payload, :key)
    user_id = Map.get(payload, :user_id)
    lobby_id = Map.get(payload, :lobby_id)

    if is_binary(key) and kv_read_allowed?(socket, key, user_id, lobby_id) do
      push(socket, "kv_deleted", payload)
    end

    {:noreply, socket}
  end

  # ── Notification PubSub events ──────────────────────────────────────────────

  @impl true
  def handle_info({:new_notification, notification}, socket) do
    push(socket, "notification", Serializers.serialize_notification(notification))
    {:noreply, socket}
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
    push(socket, "achievement_unlocked", Serializers.serialize_user_achievement(user_achievement))
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

      # Cancel matchmaking tickets
      GameServer.Matchmaking.cancel(user_id)

      # Only mark offline if no other user_channel processes remain for this user
      # (excludes self, which is still registered until this process fully exits).
      other_channels = GameServerWeb.ConnectionTracker.count_other_user_channels(user_id)

      if other_channels == 0 do
        case Accounts.set_user_offline(user_id) do
          {:ok, _} ->
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

  # Replay only the most recent notifications on connect (oldest-first) so a
  # user with a large history doesn't generate hundreds of frames per connect;
  # older ones are fetched via the REST notifications API.
  @initial_notification_window 50

  defp push_existing_notifications(socket, user_id) do
    notifications = Notifications.list_recent_notifications(user_id, @initial_notification_window)

    Enum.each(notifications, fn notification ->
      push(socket, "notification", Serializers.serialize_notification(notification))
    end)
  end

  defp push_initial_friend_update(socket, user_id) do
    friend_payloads =
      user_id
      |> Friends.list_friends_with_friendship(page: 1, page_size: 1000)
      |> Map.new(fn friendship ->
        payload = serialize_friend_update(friendship)
        {to_string(payload.user_id), payload}
      end)

    push(socket, "friend_updated", %{friends: friend_payloads})
    assign(socket, :last_friend_payloads, friend_payloads)
  end

  defp serialize_friend_update(%{friendship_id: friendship_id, user: %User{} = user}) do
    user
    |> User.serialize_brief()
    |> Map.put(:user_id, user.id)
    |> Map.put(:friendship_id, friendship_id)
  end

  defp friend_user_id(payload) when is_map(payload) do
    Map.get(payload, :user_id) || Map.get(payload, "user_id") || Map.get(payload, :id) ||
      Map.get(payload, "id")
  end

  defp friend_user_id(_payload), do: nil

  defp friend_payload_delta(nil, new_payload), do: new_payload

  defp friend_payload_delta(old_payload, new_payload) do
    case PayloadDelta.payload_delta(old_payload, new_payload) do
      nil ->
        nil

      delta ->
        delta
        |> Map.drop([:id, "id", :user_id, "user_id"])
        |> empty_map_to_nil()
    end
  end

  defp empty_map_to_nil(map) when map_size(map) == 0, do: nil
  defp empty_map_to_nil(map), do: map

  defp preserve_friendship_id(nil, payload), do: payload

  defp preserve_friendship_id(last_payload, payload) do
    cond do
      Map.has_key?(payload, :friendship_id) or Map.has_key?(payload, "friendship_id") ->
        payload

      friendship_id =
          Map.get(last_payload, :friendship_id) || Map.get(last_payload, "friendship_id") ->
        Map.put(payload, :friendship_id, friendship_id)

      true ->
        payload
    end
  end

  defp kv_read_allowed?(socket, key, user_id, lobby_id) do
    caller = fresh_current_scope(socket)

    case Hooks.internal_call(:before_kv_get, [key, %{user_id: user_id, lobby_id: lobby_id}],
           caller: caller
         ) do
      {:ok, access} -> kv_access_allowed?(access, caller, user_id, lobby_id)
      {:error, _} -> false
    end
  end

  defp fresh_current_scope(socket) do
    user = Accounts.get_user(socket.assigns.user_id) || socket.assigns.current_scope.user
    Scope.for_user(user)
  end

  defp kv_subscribe_reply(key, user_id, lobby_id, payload) do
    reply = %{subscribed: true, key: key, user_id: user_id, lobby_id: lobby_id}

    case KV.get(key, user_id: user_id, lobby_id: lobby_id) do
      {:ok, %{value: value, metadata: metadata}} ->
        reply
        |> Map.put(:data, value)
        |> Map.put(:metadata, metadata)
        |> kv_reply_payload(payload)

      :error ->
        reply
        |> Map.put(:missing, true)
        |> kv_reply_payload(payload)
    end
  end

  defp kv_reply_payload(reply, %{"_request_id" => request_id}) when is_binary(request_id),
    do: Map.put(reply, :_request_id, request_id)

  defp kv_reply_payload(reply, %{_request_id: request_id}) when is_binary(request_id),
    do: Map.put(reply, :_request_id, request_id)

  defp kv_reply_payload(reply, _payload), do: reply

  defp kv_access_allowed?(:public, _caller, _user_id, _lobby_id), do: true

  defp kv_access_allowed?(:owner_only, caller, user_id, _lobby_id),
    do: caller_owns?(caller, user_id)

  defp kv_access_allowed?(:lobby_members_only, caller, _user_id, lobby_id),
    do: caller_in_lobby?(caller, lobby_id)

  defp kv_access_allowed?(:owner_or_lobby_member, caller, user_id, lobby_id),
    do: caller_owns?(caller, user_id) or caller_in_lobby?(caller, lobby_id)

  defp kv_access_allowed?(:admin_only, caller, _user_id, _lobby_id), do: caller_admin?(caller)
  defp kv_access_allowed?(:server_only, _caller, _user_id, _lobby_id), do: false
  defp kv_access_allowed?(_access, _caller, _user_id, _lobby_id), do: false

  defp caller_owns?(%Scope{user: %{id: caller_id}}, user_id),
    do: is_binary(user_id) and caller_id == user_id

  defp caller_owns?(_caller, _user_id), do: false

  defp caller_in_lobby?(%Scope{user: %{lobby_id: caller_lobby_id}}, lobby_id),
    do: is_binary(lobby_id) and caller_lobby_id == lobby_id

  defp caller_in_lobby?(_caller, _lobby_id), do: false

  defp caller_admin?(%Scope{user: %{is_admin: true}}), do: true
  defp caller_admin?(_caller), do: false

  defp parse_optional_id(value), do: GameServer.UUIDv7.cast_or_nil(value)

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

  # ── WebSocket rate limiting ────────────────────────────────────────────────

  defp check_ws_rate_limit(socket) do
    config = Application.get_env(:game_server_web, GameServerWeb.Plugs.RateLimiter, [])

    if Keyword.get(config, :enabled, true) do
      user_id = socket.assigns.user_id
      limit = Keyword.get(config, :ws_limit, @default_ws_rate_limit)
      window = Keyword.get(config, :ws_window, @default_ws_rate_window)

      case GameServerWeb.RateLimit.hit("ws:#{user_id}", window, limit) do
        {:allow, _count} ->
          :ok

        {:deny, _retry_after} ->
          Logger.warning("UserChannel: rate limit exceeded for user=#{user_id}")
          {:stop, :normal, {:error, %{error: "rate_limited"}}, socket}
      end
    else
      :ok
    end
  end

  defp check_webrtc_enabled do
    webrtc_config = Application.get_env(:game_server_web, :webrtc, [])

    if Keyword.get(webrtc_config, :enabled, true) do
      :ok
    else
      {:error, %{error: "webrtc_disabled"}}
    end
  end

  # Separate ICE candidate rate limit — prevents ICE flooding from consuming
  # the entire WS rate budget and starving other events.
  defp check_ice_rate_limit(socket) do
    config = Application.get_env(:game_server_web, GameServerWeb.Plugs.RateLimiter, [])

    if Keyword.get(config, :enabled, true) do
      user_id = socket.assigns.user_id
      limit = Keyword.get(config, :ice_limit, @default_ice_rate_limit)
      window = Keyword.get(config, :ice_window, @default_ice_rate_window)

      case GameServerWeb.RateLimit.hit("ice:#{user_id}", window, limit) do
        {:allow, _count} ->
          :ok

        {:deny, _retry_after} ->
          Logger.warning("UserChannel: ICE rate limit exceeded for user=#{user_id}")
          {:reply, {:error, %{error: "ice_rate_limited"}}, socket}
      end
    else
      :ok
    end
  end

  defp stop_existing_peer(socket) do
    case Map.get(socket.assigns, :webrtc_peer) do
      nil -> :ok
      peer -> if Process.alive?(peer), do: GameServerWeb.WebRTCPeer.close(peer)
    end
  end

  # ── Matchmaking Helpers ────────────────────────────────────────────────

  defp parse_match_params(nil), do: %{}

  defp parse_match_params(payload) when is_map(payload) do
    Map.get(payload, "match_params", %{})
  end

  defp parse_match_params(_payload), do: %{}

  defp parse_optional_int(nil), do: nil
  defp parse_optional_int(value) when is_integer(value), do: value

  defp parse_optional_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _rest} -> int
      _ -> nil
    end
  end

  defp parse_optional_int(_value), do: nil

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
