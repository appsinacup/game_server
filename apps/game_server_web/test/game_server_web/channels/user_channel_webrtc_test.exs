defmodule GameServerWeb.UserChannelWebRTCTest do
  @moduledoc """
  Integration tests for WebRTC signaling over UserChannel.

  These tests verify the signaling protocol between client and server.
  They do NOT test actual WebRTC media exchange (which would require
  a full PeerConnection on each side), but they test:

  - Offer handling, answer generation, ICE relay
  - Config-driven enable/disable
  - Cleanup on close and terminate
  - Error cases (no session, invalid payloads)

  Note: ExWebRTC's DTLS transport NIF may crash on close. Tests trap exits
  and use safe cleanup helpers to handle this gracefully.
  """

  use ExUnit.Case, async: false
  import Phoenix.ChannelTest

  alias GameServer.AccountsFixtures
  alias GameServerWeb.Auth.Guardian

  @endpoint GameServerWeb.Endpoint

  setup tags do
    GameServer.DataCase.setup_sandbox(tags)
    # Trap exits so NIF crashes during PeerConnection cleanup don't kill tests
    Process.flag(:trap_exit, true)

    user = AccountsFixtures.user_fixture() |> AccountsFixtures.set_password()
    {:ok, token, _claims} = Guardian.encode_and_sign(user)
    {:ok, socket} = connect(GameServerWeb.UserSocket, %{"token" => token})
    {:ok, _, socket} = subscribe_and_join(socket, "user:#{user.id}", %{})

    # Consume the initial "updated" push
    assert_push "updated", _initial_payload

    %{socket: socket, user: user}
  end

  # Safe cleanup: stop PeerConnection without crashing the test
  defp safe_stop_pc(pc) do
    try do
      if Process.alive?(pc) do
        ExWebRTC.PeerConnection.close(pc)
      end
    catch
      _, _ -> :ok
    end

    try do
      if Process.alive?(pc) do
        ExWebRTC.PeerConnection.stop(pc)
      end
    catch
      _, _ -> :ok
    end

    # Drain any EXIT messages from linked PeerConnection processes
    receive do
      {:EXIT, ^pc, _} -> :ok
    after
      100 -> :ok
    end
  end

  # Create a client PeerConnection with a data channel, generate an offer
  defp create_test_offer do
    {:ok, pc} = ExWebRTC.PeerConnection.start_link(ice_servers: [])
    {:ok, _ref} = ExWebRTC.PeerConnection.create_data_channel(pc, "events")
    {:ok, offer} = ExWebRTC.PeerConnection.create_offer(pc)
    :ok = ExWebRTC.PeerConnection.set_local_description(pc, offer)
    offer_json = ExWebRTC.SessionDescription.to_json(offer)
    {pc, offer_json}
  end

  describe "webrtc:offer" do
    test "accepts a valid SDP offer and returns ok", %{socket: socket} do
      {_client_pc, offer_json} = create_test_offer()

      ref = push(socket, "webrtc:offer", offer_json)
      assert_reply ref, :ok, %{}, 5000

      # Server should push an SDP answer back
      assert_push "webrtc:answer", _answer_payload, 5000
    end

    test "returns error when WebRTC is disabled via config", %{socket: socket} do
      # Temporarily disable WebRTC
      original = Application.get_env(:game_server_web, :webrtc, [])
      Application.put_env(:game_server_web, :webrtc, Keyword.put(original, :enabled, false))

      ref = push(socket, "webrtc:offer", %{"sdp" => "fake", "type" => "offer"})
      assert_reply ref, :error, %{error: "webrtc_disabled"}

      # Restore
      Application.put_env(:game_server_web, :webrtc, original)
    end

    test "re-offer replaces existing peer", %{socket: socket} do
      {client_pc1, offer1_json} = create_test_offer()

      ref1 = push(socket, "webrtc:offer", offer1_json)
      assert_reply ref1, :ok, %{}, 5000
      assert_push "webrtc:answer", _answer1, 5000

      # Second offer (re-negotiate)
      {client_pc2, offer2_json} = create_test_offer()

      ref2 = push(socket, "webrtc:offer", offer2_json)
      assert_reply ref2, :ok, %{}, 5000
      assert_push "webrtc:answer", _answer2, 5000

      safe_stop_pc(client_pc1)
      safe_stop_pc(client_pc2)
    end
  end

  describe "webrtc:ice" do
    test "returns error when no WebRTC session exists", %{socket: socket} do
      ref =
        push(socket, "webrtc:ice", %{
          "candidate" => "fake",
          "sdpMid" => "0",
          "sdpMLineIndex" => 0
        })

      assert_reply ref, :error, %{error: "no_webrtc_session"}
    end

    test "accepts ICE candidate after offer", %{socket: socket} do
      {client_pc, offer_json} = create_test_offer()

      ref = push(socket, "webrtc:offer", offer_json)
      assert_reply ref, :ok, %{}, 5000
      assert_push "webrtc:answer", _answer, 5000

      ice_ref =
        push(socket, "webrtc:ice", %{
          "candidate" => "candidate:1 1 UDP 2122252543 10.0.0.1 12345 typ host",
          "sdpMid" => "0",
          "sdpMLineIndex" => 0
        })

      assert_reply ice_ref, :ok, %{}

      safe_stop_pc(client_pc)
    end
  end

  describe "webrtc:send" do
    test "returns error when no WebRTC session exists", %{socket: socket} do
      ref = push(socket, "webrtc:send", %{"channel" => "events", "data" => "hello"})
      assert_reply ref, :error, %{error: "no_webrtc_session"}
    end

    test "returns error when channel not found", %{socket: socket} do
      {client_pc, offer_json} = create_test_offer()

      ref = push(socket, "webrtc:offer", offer_json)
      assert_reply ref, :ok, %{}, 5000
      assert_push "webrtc:answer", _answer, 5000

      send_ref = push(socket, "webrtc:send", %{"channel" => "nonexistent", "data" => "hello"})
      assert_reply send_ref, :error, %{error: "channel_not_found"}

      safe_stop_pc(client_pc)
    end
  end

  describe "webrtc:close" do
    test "returns ok when no session exists", %{socket: socket} do
      ref = push(socket, "webrtc:close", %{})
      assert_reply ref, :ok, %{}
    end

    test "closes existing session", %{socket: socket} do
      {client_pc, offer_json} = create_test_offer()

      ref = push(socket, "webrtc:offer", offer_json)
      assert_reply ref, :ok, %{}, 5000
      assert_push "webrtc:answer", _answer, 5000

      # Close — give extra time since PeerConnection cleanup can be slow
      close_ref = push(socket, "webrtc:close", %{})
      assert_reply close_ref, :ok, %{}, 500

      # After close, sending should fail
      send_ref = push(socket, "webrtc:send", %{"channel" => "events", "data" => "hello"})
      assert_reply send_ref, :error, %{error: "no_webrtc_session"}

      safe_stop_pc(client_pc)
    end
  end

  describe "WebRTCPeer GenServer" do
    test "start_link and close lifecycle" do
      {:ok, peer} =
        GameServerWeb.WebRTCPeer.start_link(
          user_id: 1,
          channel_pid: self()
        )

      assert Process.alive?(peer)
      assert GameServerWeb.WebRTCPeer.connection_state(peer) == :new

      # close/1 calls GenServer.stop which may trigger NIF crash
      try do
        GameServerWeb.WebRTCPeer.close(peer)
      catch
        :exit, _ -> :ok
      end

      # Give time for process to terminate
      Process.sleep(50)
      refute Process.alive?(peer)
    end

    test "handle_offer sends answer back to controlling process" do
      {:ok, peer} =
        GameServerWeb.WebRTCPeer.start_link(
          user_id: 2,
          channel_pid: self()
        )

      {client_pc, offer_json} = create_test_offer()

      GameServerWeb.WebRTCPeer.handle_offer(peer, offer_json)

      # Should receive answer message
      assert_receive {:webrtc_answer, answer_json}, 5000
      assert is_map(answer_json)
      assert answer_json["type"] == "answer"
      assert is_binary(answer_json["sdp"])

      try do
        GameServerWeb.WebRTCPeer.close(peer)
      catch
        :exit, _ -> :ok
      end

      safe_stop_pc(client_pc)
    end

    test "send_data returns error when channel does not exist" do
      {:ok, peer} =
        GameServerWeb.WebRTCPeer.start_link(
          user_id: 3,
          channel_pid: self()
        )

      assert {:error, :channel_not_found} =
               GameServerWeb.WebRTCPeer.send_data(peer, "nonexistent", "data")

      try do
        GameServerWeb.WebRTCPeer.close(peer)
      catch
        :exit, _ -> :ok
      end
    end
  end
end
