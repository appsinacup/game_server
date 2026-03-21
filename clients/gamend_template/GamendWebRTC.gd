## GamendWebRTC — Godot WebRTC DataChannel client for game_server.
##
## Uses an existing PhoenixChannel (UserChannel) for SDP/ICE signaling.
## Once connected, named DataChannels carry game data alongside the WebSocket.
##
## Usage:
##   var realtime = GamendRealtime.new(token)
##   var user_channel = realtime.add_channel("user:123")
##   # wait for channel join...
##
##   var webrtc = GamendWebRTC.new(user_channel)
##   webrtc.data_received.connect(_on_data_received)
##   webrtc.channel_opened.connect(_on_channel_opened)
##   webrtc.connection_state_changed.connect(_on_state_changed)
##   add_child(webrtc)
##   webrtc.connect_webrtc()
##
##   webrtc.send_data("events", "hello".to_utf8_buffer())
##
##   func _on_data_received(label: String, data: PackedByteArray):
##       print("Received on %s: %s" % [label, data.get_string_from_utf8()])
##

class_name GamendWebRTC
extends Node

## Emitted when data arrives on a DataChannel.
signal data_received(label: String, data: PackedByteArray)
## Emitted when a DataChannel opens.
signal channel_opened(label: String)
## Emitted when a DataChannel closes.
signal channel_closed(label: String)
## Emitted when the WebRTC connection state changes.
signal connection_state_changed(state: String)
## Emitted when the WebRTC connection is fully established.
signal connected()
## Emitted on error.
signal errored(message: String)

## The Phoenix channel used for signaling (must be joined already).
var _channel: PhoenixChannel
## The WebRTCPeerConnection instance.
var _peer: WebRTCPeerConnection
## Map of label → WebRTCDataChannel for open channels.
var _data_channels: Dictionary = {}
## ICE servers configuration.
var _ice_servers: Array = [{"urls": ["stun:stun.l.google.com:19302"]}]
## DataChannel definitions: Array of {label, ordered, max_retransmits}.
var _channel_defs: Array = [
	{"label": "events", "ordered": true},
	{"label": "state", "ordered": false, "maxRetransmits": 0},
]
## Whether we are currently connected.
var _is_connected: bool = false
## Enable debug logging.
var enable_logs: bool = false


func _init(channel: PhoenixChannel, opts: Dictionary = {}) -> void:
	_channel = channel
	if opts.has("ice_servers"):
		_ice_servers = opts["ice_servers"]
	if opts.has("data_channels"):
		_channel_defs = opts["data_channels"]
	if opts.has("enable_logs"):
		enable_logs = opts["enable_logs"]


func _ready() -> void:
	# Listen for signaling events from the server via the Phoenix channel
	_channel.on_event.connect(_on_channel_event)


## Start the WebRTC connection negotiation.
func connect_webrtc() -> void:
	# Create WebRTCPeerConnection
	_peer = WebRTCPeerConnection.new()

	var config := {"iceServers": _ice_servers}
	var err := _peer.initialize(config)
	if err != OK:
		_log("Failed to initialize WebRTCPeerConnection: %s" % err)
		errored.emit("Failed to initialize WebRTCPeerConnection")
		return

	# Connect signals
	_peer.ice_candidate_created.connect(_on_ice_candidate_created)
	_peer.session_description_created.connect(_on_session_description_created)

	# Create DataChannels (client-initiated)
	for def in _channel_defs:
		var label: String = def["label"]
		var opts := {}
		if def.has("ordered"):
			opts["ordered"] = def["ordered"]
		if def.has("maxRetransmits"):
			opts["maxRetransmits"] = def["maxRetransmits"]
		if def.has("maxPacketLifeTime"):
			opts["maxPacketLifeTime"] = def["maxPacketLifeTime"]

		var dc := _peer.create_data_channel(label, opts)
		if dc == null:
			_log("Failed to create DataChannel: %s" % label)
			errored.emit("Failed to create DataChannel: %s" % label)
			continue

		_data_channels[label] = dc
		_log("Created DataChannel: %s" % label)

	# Create offer
	_peer.create_offer()


## Send data over a named DataChannel.
func send_data(label: String, data: PackedByteArray) -> Error:
	if not _data_channels.has(label):
		return ERR_DOES_NOT_EXIST

	var dc: WebRTCDataChannel = _data_channels[label]
	if dc.get_ready_state() != WebRTCDataChannel.STATE_OPEN:
		return ERR_UNAVAILABLE

	return dc.put_packet(data)


## Send a string over a named DataChannel.
func send_text(label: String, text: String) -> Error:
	return send_data(label, text.to_utf8_buffer())


## Check if a specific DataChannel is open.
func is_channel_open(label: String) -> bool:
	if not _data_channels.has(label):
		return false
	var dc: WebRTCDataChannel = _data_channels[label]
	return dc.get_ready_state() == WebRTCDataChannel.STATE_OPEN


## Check if the WebRTC connection is established.
func is_connected_webrtc() -> bool:
	return _is_connected


## Close the WebRTC connection and all DataChannels.
func close_webrtc() -> void:
	_is_connected = false

	for label in _data_channels:
		var dc: WebRTCDataChannel = _data_channels[label]
		dc.close()
	_data_channels.clear()

	if _peer:
		_peer.close()
		_peer = null

	# Notify server
	_channel.push("webrtc:close", {})
	connection_state_changed.emit("closed")


func _process(_delta: float) -> void:
	if _peer == null:
		return

	# Poll the peer connection
	_peer.poll()

	# Check connection state
	var state := _peer.get_connection_state()
	if state == WebRTCPeerConnection.STATE_CONNECTED and not _is_connected:
		_is_connected = true
		_log("WebRTC connected")
		connection_state_changed.emit("connected")
		connected.emit()
	elif state == WebRTCPeerConnection.STATE_FAILED:
		_log("WebRTC connection failed")
		connection_state_changed.emit("failed")
		errored.emit("WebRTC connection failed")
		close_webrtc()
	elif state == WebRTCPeerConnection.STATE_CLOSED and _is_connected:
		_is_connected = false
		connection_state_changed.emit("closed")

	# Poll DataChannels and read incoming data
	for label in _data_channels:
		var dc: WebRTCDataChannel = _data_channels[label]
		dc.poll()

		# Check for state changes
		if dc.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
			while dc.get_available_packet_count() > 0:
				var packet := dc.get_packet()
				data_received.emit(label, packet)


## Handle signaling events from the server via the Phoenix channel.
func _on_channel_event(event: String, payload: Dictionary, _status, _topic: String) -> void:
	match event:
		"webrtc:answer":
			if _peer and payload.has("sdp") and payload.has("type"):
				_log("Received SDP answer")
				_peer.set_remote_description(payload["type"], payload["sdp"])

		"webrtc:ice":
			if _peer and payload.has("candidate"):
				var mid: String = payload.get("sdpMid", "")
				var idx: int = payload.get("sdpMLineIndex", 0)
				var candidate: String = payload["candidate"]
				_log("Received ICE candidate: %s" % candidate.substr(0, 40))
				_peer.add_ice_candidate(mid, idx, candidate)

		"webrtc:state":
			var state_str: String = payload.get("state", "unknown")
			_log("Server reports state: %s" % state_str)
			# We track this locally via polling, but log the server perspective

		"webrtc:channel_open":
			var label: String = payload.get("channel", "")
			_log("Server confirms channel open: %s" % label)
			channel_opened.emit(label)

		"webrtc:channel_closed":
			_log("Server reports channel closed")


## Called when the PeerConnection generates an ICE candidate.
func _on_ice_candidate_created(mid: String, index: int, candidate: String) -> void:
	_log("Sending ICE candidate")
	_channel.push("webrtc:ice", {
		"candidate": candidate,
		"sdpMid": mid,
		"sdpMLineIndex": index,
	})


## Called when the PeerConnection generates a session description (offer/answer).
func _on_session_description_created(type: String, sdp: String) -> void:
	_log("SDP created: %s" % type)
	_peer.set_local_description(type, sdp)

	if type == "offer":
		_channel.push("webrtc:offer", {
			"sdp": sdp,
			"type": type,
		})


func _log(msg: String) -> void:
	if enable_logs:
		print("[GamendWebRTC] ", msg)


func _exit_tree() -> void:
	if _peer:
		close_webrtc()
	if _channel and _channel.on_event.is_connected(_on_channel_event):
		_channel.on_event.disconnect(_on_channel_event)
