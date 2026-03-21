if Code.ensure_loaded?(ExWebRTC.PeerConnection) do
  defmodule GameServerWeb.WebRTCPeer do
    @moduledoc """
    Manages a server-side WebRTC PeerConnection for a single user.

    This GenServer owns an `ExWebRTC.PeerConnection` process and acts as the
    bridge between the Phoenix Channel (signaling) and the WebRTC DataChannels
    (game data transport).

    ## Lifecycle

    1. Started by `UserChannel` when the client sends a `"webrtc:offer"` event.
    2. Linked to the channel process — auto-terminates when WebSocket disconnects.
    3. Handles SDP offer/answer exchange and ICE candidate relay.
    4. Forwards incoming DataChannel messages to the channel process.
    5. Provides `send_data/3` for the channel to push data to the client.

    ## Messages sent to the controlling channel process

    - `{:webrtc_answer, answer_json}` — SDP answer to send to client
    - `{:webrtc_ice, candidate_json}` — ICE candidate to send to client
    - `{:webrtc_data, channel_label, binary}` — data received from client
    - `{:webrtc_channel_open, ref, label}` — DataChannel opened
    - `{:webrtc_channel_closed, ref}` — DataChannel closed
    - `{:webrtc_connection_state, state}` — connection state change
    """

    use GenServer
    require Logger

    alias ExWebRTC.{
      ICECandidate,
      PeerConnection,
      SessionDescription
    }

    # ── Public API ────────────────────────────────────────────────────────────

    @doc """
    Starts a WebRTCPeer linked to the calling process (typically a channel).

    ## Options

    - `:user_id` — the authenticated user's ID (required)
    - `:ice_servers` — list of ICE server configs (optional, defaults to config)
    """
    def start_link(opts) do
      GenServer.start_link(__MODULE__, opts)
    end

    @doc """
    Handles an incoming SDP offer from the client.
    Sends `{:webrtc_answer, answer_json}` back to the controlling process.
    """
    def handle_offer(pid, offer_json) do
      GenServer.cast(pid, {:offer, offer_json})
    end

    @doc """
    Adds a remote ICE candidate received from the client.
    """
    def add_ice_candidate(pid, candidate_json) do
      GenServer.cast(pid, {:ice_candidate, candidate_json})
    end

    @doc """
    Sends data to the client over a named DataChannel.
    Returns `:ok` or `{:error, reason}`.
    """
    def send_data(pid, channel_label, data) do
      GenServer.call(pid, {:send_data, channel_label, data})
    end

    @doc """
    Returns the current connection state.
    """
    def connection_state(pid) do
      GenServer.call(pid, :connection_state)
    end

    @doc """
    Closes the WebRTC peer connection and stops this process.
    """
    def close(pid) do
      GenServer.stop(pid, :normal)
    end

    # ── GenServer callbacks ───────────────────────────────────────────────────

    @impl true
    def init(opts) do
      user_id = Keyword.fetch!(opts, :user_id)
      channel_pid = Keyword.get(opts, :channel_pid, self())

      ice_servers =
        Keyword.get_lazy(opts, :ice_servers, fn ->
          webrtc_config = Application.get_env(:game_server_web, :webrtc, [])
          Keyword.get(webrtc_config, :ice_servers, [%{urls: "stun:stun.l.google.com:19302"}])
        end)

      {:ok, pc} = PeerConnection.start_link(ice_servers: ice_servers)

      state = %{
        peer_connection: pc,
        channel_pid: channel_pid,
        user_id: user_id,
        # %{ref => label} for open DataChannels
        channels: %{},
        # %{label => ref} reverse lookup for sending by label
        channels_by_label: %{}
      }

      GameServerWeb.ConnectionTracker.register(:webrtc_peer, %{user_id: user_id})
      Logger.info("WebRTCPeer started for user=#{user_id}")
      {:ok, state}
    end

    @impl true
    def handle_cast({:offer, offer_json}, state) do
      offer = SessionDescription.from_json(offer_json)
      :ok = PeerConnection.set_remote_description(state.peer_connection, offer)

      {:ok, answer} = PeerConnection.create_answer(state.peer_connection)
      :ok = PeerConnection.set_local_description(state.peer_connection, answer)

      answer_json = SessionDescription.to_json(answer)
      send(state.channel_pid, {:webrtc_answer, answer_json})

      {:noreply, state}
    end

    @impl true
    def handle_cast({:ice_candidate, candidate_json}, state) do
      candidate = ICECandidate.from_json(candidate_json)
      :ok = PeerConnection.add_ice_candidate(state.peer_connection, candidate)
      {:noreply, state}
    end

    @impl true
    def handle_call({:send_data, channel_label, data}, _from, state) do
      case Map.get(state.channels_by_label, channel_label) do
        nil ->
          {:reply, {:error, :channel_not_found}, state}

        ref ->
          :ok = PeerConnection.send_data(state.peer_connection, ref, data)
          {:reply, :ok, state}
      end
    end

    @impl true
    def handle_call(:connection_state, _from, state) do
      conn_state = PeerConnection.get_connection_state(state.peer_connection)
      {:reply, conn_state, state}
    end

    # ── ExWebRTC messages ─────────────────────────────────────────────────────

    @impl true
    def handle_info({:ex_webrtc, _pc, {:ice_candidate, candidate}}, state) do
      candidate_json = ICECandidate.to_json(candidate)
      send(state.channel_pid, {:webrtc_ice, candidate_json})
      {:noreply, state}
    end

    @impl true
    def handle_info({:ex_webrtc, _pc, {:connection_state_change, conn_state}}, state) do
      Logger.info("WebRTCPeer user=#{state.user_id} connection_state=#{conn_state}")
      send(state.channel_pid, {:webrtc_connection_state, conn_state})

      if conn_state == :failed do
        {:stop, {:shutdown, :connection_failed}, state}
      else
        {:noreply, state}
      end
    end

    @impl true
    def handle_info(
          {:ex_webrtc, _pc, {:data_channel, %ExWebRTC.DataChannel{ref: ref, label: label}}},
          state
        ) do
      Logger.info("WebRTCPeer user=#{state.user_id} DataChannel opened: #{label}")
      send(state.channel_pid, {:webrtc_channel_open, ref, label})

      state = %{
        state
        | channels: Map.put(state.channels, ref, label),
          channels_by_label: Map.put(state.channels_by_label, label, ref)
      }

      {:noreply, state}
    end

    @impl true
    def handle_info(
          {:ex_webrtc, _pc, {:data_channel_state_change, _ref, :open}},
          state
        ) do
      # Channel is now fully open — already tracked from :data_channel message
      {:noreply, state}
    end

    @impl true
    def handle_info(
          {:ex_webrtc, _pc, {:data_channel_state_change, ref, :closed}},
          state
        ) do
      label = Map.get(state.channels, ref)
      Logger.info("WebRTCPeer user=#{state.user_id} DataChannel closed: #{inspect(label)}")
      send(state.channel_pid, {:webrtc_channel_closed, ref})

      state = %{
        state
        | channels: Map.delete(state.channels, ref),
          channels_by_label:
            if(label, do: Map.delete(state.channels_by_label, label), else: state.channels_by_label)
      }

      {:noreply, state}
    end

    @impl true
    def handle_info({:ex_webrtc, _pc, {:data, ref, data}}, state) do
      label = Map.get(state.channels, ref, "unknown")
      send(state.channel_pid, {:webrtc_data, label, data})
      {:noreply, state}
    end

    # Ignore other ExWebRTC messages (ICE gathering state, signaling state, etc.)
    @impl true
    def handle_info({:ex_webrtc, _pc, _msg}, state) do
      {:noreply, state}
    end

    @impl true
    def handle_info({:EXIT, pc, reason}, %{peer_connection: pc} = state) do
      Logger.info(
        "WebRTCPeer user=#{state.user_id} PeerConnection exited: #{inspect(reason)}"
      )

      {:stop, {:shutdown, :pc_exited}, state}
    end

    @impl true
    def handle_info(_msg, state) do
      {:noreply, state}
    end

    @impl true
    def terminate(reason, state) do
      Logger.info("WebRTCPeer user=#{state.user_id} terminating: #{inspect(reason)}")

      try do
        if Process.alive?(state.peer_connection) do
          PeerConnection.close(state.peer_connection)
          PeerConnection.stop(state.peer_connection)
        end
      catch
        kind, error ->
          Logger.warning(
            "WebRTCPeer user=#{state.user_id} cleanup error: #{inspect(kind)} #{inspect(error)}"
          )
      end

      :ok
    end
  end
end
