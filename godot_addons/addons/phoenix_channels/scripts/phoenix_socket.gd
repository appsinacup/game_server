class_name PhoenixSocket
extends Node

#
# Signals
#

signal on_open(params)
signal on_error(data)
signal on_close()
signal on_connecting(is_connecting)
signal latency_updated(latency_ms: int)

#
# Socket Members
#

const DEFAULT_TIMEOUT_MS := 10000
const DEFAULT_HEARTBEAT_INTERVAL_MS := 30000
const DEFAULT_BASE_ENDPOINT := "ws://localhost:4000/socket"
const DEFAULT_RECONNECT_AFTER_MS := [1000, 2000, 5000, 10000]
const TRANSPORT := "websocket"

const WRITE_MODE := WebSocketPeer.WRITE_MODE_TEXT

const TOPIC_PHOENIX := "phoenix"
const EVENT_HEARTBEAT := "heartbeat"
const EMPTY_REF := "-1"

const STATUS = {
	ok = "ok",
	error = "error",
	timeout = "timeout"
}

var _socket := WebSocketPeer.new()
var _channels := []
var _settings := {} : get = get_settings
var _is_https := false
var _endpoint_url := ""
var _last_status := -1
var _connected_at := -1
var _last_connected_at := -1
var _requested_disconnect := false
var _last_close_reason := {}
var _params_provider: Callable  ## If set, called to get fresh params dict before each connect

var _last_heartbeat_at := 0
var _pending_heartbeat_ref := EMPTY_REF
var _heartbeat_sent_at := 0
var latency_ms: int = -1

## Latency ping (separate from connection health heartbeat)
const LATENCY_PING_INTERVAL_MS := 5000
var _last_latency_ping_at := 0
var _latency_ping_ref := EMPTY_REF
var _latency_ping_sent_at := 0

var _last_reconnect_try_at := -1
var _should_reconnect := false
var _reconnect_after_pos := 0

# TODO: refactor as SocketStates, just like ChannelStates
@export var is_connected := false : get = get_is_connected
@export var is_connecting := false : get = get_is_connecting

# Events / Messages
var _ref := 0

#
# Godot lifecycle for PhoenixSocket
#

func _init(endpoint,opts = {}):
	_settings = {
		heartbeat_interval = PhoenixUtils.get_key_or_default(opts, "heartbeat_interval", DEFAULT_HEARTBEAT_INTERVAL_MS),
		timeout = PhoenixUtils.get_key_or_default(opts, "timeout", DEFAULT_TIMEOUT_MS),
		reconnect_after = PhoenixUtils.get_key_or_default(opts, "reconnect_after", DEFAULT_RECONNECT_AFTER_MS),
		params = PhoenixUtils.get_key_or_default(opts, "params", {}),
		tls_options = PhoenixUtils.get_key_or_default(opts, "tls_options", null)
	}
	var provider = PhoenixUtils.get_key_or_default(opts, "params_provider", Callable())
	if provider.is_valid():
		_params_provider = provider
	
	set_endpoint(endpoint)	

func _ready():
	set_process(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		# User alt-tabbed back — reset reconnection backoff so the next
		# reconnect attempt happens immediately (triggered externally after
		# the access token has been verified/refreshed).
		if _should_reconnect and not is_connected and not is_connecting:
			_last_reconnect_try_at = -1
			_reconnect_after_pos = 0
	
func _process(_delta):
	var status = _socket.get_ready_state()

	if status != _last_status:
		if status == WebSocketPeer.STATE_CLOSED:
			var code = _socket.get_close_code()
			var reason = _socket.get_close_reason()
			_last_close_reason = {
				message = "WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1]
			}
			print(_last_close_reason)

			_on_socket_closed()
			is_connected = false
			_last_connected_at = _connected_at
			_connected_at = -1
		
		if status == WebSocketPeer.STATE_CONNECTING:
			emit_signal("on_connecting", true)
			is_connecting = true
		else:
			if is_connecting: emit_signal("on_connecting", false)
			is_connecting = false
			
	if status == WebSocketPeer.STATE_OPEN:
		if _last_status == WebSocketPeer.STATE_CONNECTING:
			_on_socket_connected()
			
		var current_ticks = Time.get_ticks_msec()		
		
		if (current_ticks - _last_heartbeat_at >= _settings.heartbeat_interval) and (current_ticks - _connected_at >= _settings.heartbeat_interval):
			_heartbeat(current_ticks)
		
		# Latency ping (more frequent, doesn't affect connection health)
		if current_ticks - _last_latency_ping_at >= LATENCY_PING_INTERVAL_MS and _latency_ping_ref == EMPTY_REF:
			_latency_ping(current_ticks)
			
		while _socket.get_available_packet_count():
			var packet = _socket.get_packet()
			_on_socket_data_received(packet)
			
	_last_status = status
	
	if status == WebSocketPeer.STATE_CLOSED: 
		_retry_reconnect(Time.get_ticks_msec())
		return

	_socket.poll()
	
func _enter_tree():
	if not get_tree().is_connected("node_removed", _on_node_removed):
		var _error = get_tree().connect("node_removed", _on_node_removed)
	
func _exit_tree():
	if get_tree().is_connected("node_removed", _on_node_removed):
		get_tree().disconnect("node_removed", _on_node_removed)
	var payload = {message = "exit tree"}
	_close(true, payload)
	
	"""
	Closing the socket with _socket() leads to the chain of events that eventually call on_close,
	but then in this specific case of exiting the tree, the event is not called, because
	the tree is freed, so force call it from here.
	"""	
	emit_signal("on_close", payload)
	
#
# Public
#

func shutdown() -> void:
	set_process(false)
	_should_reconnect = false
	for channel in _channels.duplicate():
		channel.close({message = "socket shutdown"}, false)
		channel.queue_free()
	_channels.clear()
	if _socket != null:
		if _socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
			_socket.close()
		_socket = null

func connect_socket():
	if is_connected:
		return
	if _socket == null:
		_socket = WebSocketPeer.new()
	
	# Refresh params from provider before connecting (ensures fresh tokens on reconnect)
	if _params_provider.is_valid():
		_settings.params = _params_provider.call()

	# Channel protocol V2 (array frames + binary frame support).
	var url_params = _settings.params.duplicate()
	url_params["vsn"] = "2.0.0"
	_endpoint_url = PhoenixUtils.add_url_params(_settings.endpoint, url_params)
	
	if _settings.tls_options:
		_socket.connect_to_url(_endpoint_url, _settings.tls_options)
	else:
		_socket.connect_to_url(_endpoint_url)
	
func disconnect_socket():	
	_close(true, {message = "disconnect requested"})

func get_is_connected() -> bool:
	return is_connected
	
func get_is_connecting() -> bool:
	return is_connecting
	
func get_settings():
	return _settings
	
func set_endpoint(endpoint : String):
	_settings.endpoint = PhoenixUtils.add_trailing_slash(endpoint if endpoint else DEFAULT_BASE_ENDPOINT) + TRANSPORT
	_is_https = _settings.endpoint.begins_with("wss")
	
func set_params(params : Dictionary = {}):
	_settings.params = params
	
func can_push(_event : String) -> bool:
	return is_connected
	
func channel(topic : String, params : Dictionary = {}, presence = null, params_provider: Callable = Callable()) -> PhoenixChannel:
	var channel : PhoenixChannel = PhoenixChannel.new(self, topic, params, presence)
	if params_provider.is_valid():
		channel._params_provider = params_provider
	
	_channels.push_back(channel)
	add_child(channel)
	return channel
	
func compose_message(event : String, payload := {}, topic := TOPIC_PHOENIX, ref := "", join_ref := PhoenixMessage.GLOBAL_JOIN_REF) -> PhoenixMessage:	
	if event == EVENT_HEARTBEAT:
		join_ref = PhoenixMessage.GLOBAL_JOIN_REF

	ref = ref if ref != "" else make_ref()
	topic = topic if topic else TOPIC_PHOENIX
	
	return PhoenixMessage.new(topic, event, ref, join_ref, payload)
	
func push(message : PhoenixMessage):
	var dict = message.to_dictionary()

	if can_push(dict.event):
		# V2 frame: [join_ref, ref, topic, event, payload]
		var join_ref = dict.join_ref if dict.join_ref != PhoenixMessage.GLOBAL_JOIN_REF else null
		var ref = dict.ref if dict.ref != PhoenixMessage.NO_REPLY_REF else null
		var frame = [join_ref, ref, dict.topic, dict.event, dict.payload]
		var _error = _socket.send_text(JSON.new().stringify(frame))
		
func make_ref() -> String:
	_ref = _ref + 1
	return str(_ref)

#
# Implementation 
#

func _trigger_channel_error(channel : PhoenixChannel, payload := {}):
	channel.raw_trigger(PhoenixChannel.CHANNEL_EVENTS.error, payload)

func _close(requested := false, reason := {}):
	if _socket == null:
		return
	if not is_connected:
		return
		
	_last_close_reason = reason
	_requested_disconnect = requested
	_socket.close()	

func _reset_reconnection():
	_last_reconnect_try_at = -1
	_should_reconnect = false
	_reconnect_after_pos = 0

func _retry_reconnect(current_time):
	if _should_reconnect:
		# Just started the reconnection timer, set time as now, so the
		# first _reconnect_after_pos amount will be subtracted from now
		if _last_reconnect_try_at == -1:
			_last_reconnect_try_at = current_time
		else:
			var reconnect_after = _settings.reconnect_after[_reconnect_after_pos]
							
			if current_time - _last_reconnect_try_at >= reconnect_after:
				_last_reconnect_try_at = current_time
				
				# Move to the next reconnect time (or keep the last one)
				if _reconnect_after_pos < reconnect_after - 1 and _reconnect_after_pos < _settings.reconnect_after.size() - 1: 
					_reconnect_after_pos += 1
					
				connect_socket()
	
func _heartbeat(time):
	if get_is_connected():
		# There is still a pending heartbeat, which means it timed out
		if _pending_heartbeat_ref != EMPTY_REF:
			_close(false, {message = "heartbeat timeout"})
		else:
			_pending_heartbeat_ref = make_ref()
			_heartbeat_sent_at = time
			push(compose_message(EVENT_HEARTBEAT, {}, TOPIC_PHOENIX, _pending_heartbeat_ref))
			_last_heartbeat_at = time

func _latency_ping(time):
	if get_is_connected():
		_latency_ping_ref = make_ref()
		_latency_ping_sent_at = time
		push(compose_message(EVENT_HEARTBEAT, {}, TOPIC_PHOENIX, _latency_ping_ref))
		_last_latency_ping_at = time
	
func _find_and_remove_channel(channel : PhoenixChannel):	
	var pos = _channels.find(channel)
	if pos != -1:
		_channels.remove_at(pos)
		
#
# Listeners
#

func _on_socket_connected():	
	_connected_at = Time.get_ticks_msec()
	_last_close_reason = {}
	_pending_heartbeat_ref = EMPTY_REF
	_last_heartbeat_at = 0
	_latency_ping_ref = EMPTY_REF
	_last_latency_ping_at = 0
	_requested_disconnect = false
	_reset_reconnection()
	
	is_connected = true	
	emit_signal("on_open", {})
	
func _on_socket_error(reason = null):
	if not is_connected or (_connected_at == -1 and _last_connected_at != -1):
		_should_reconnect = true

	_last_close_reason = reason if reason else {message = "connection error"}
	
	emit_signal("on_error", _last_close_reason)
		
func _on_socket_closed():
	if not _requested_disconnect:
		_should_reconnect = true	
	
	_last_close_reason = {message = "connection lost"} if _last_close_reason.is_empty() else _last_close_reason
	
	var payload = {
		was_requested = _requested_disconnect,
		will_reconnect = not _requested_disconnect,
		reason = _last_close_reason
	}	
	
	for channel in _channels:
		channel.close(payload, _should_reconnect)

	emit_signal("on_close", payload)	
	
func _on_socket_data_received(packet):
	var message : PhoenixMessage
	if _socket.was_string_packet():
		message = _parse_text_frame(packet)
	else:
		message = _parse_binary_frame(packet)

	if message == null:
		return

	var ref = message.get_ref()

	if message.get_topic() == TOPIC_PHOENIX:
		if ref == _pending_heartbeat_ref:
			var now_ms := Time.get_ticks_msec()
			if _heartbeat_sent_at > 0:
				latency_ms = now_ms - _heartbeat_sent_at
				latency_updated.emit(latency_ms)
			_pending_heartbeat_ref = EMPTY_REF
		elif ref == _latency_ping_ref:
			var now_ms := Time.get_ticks_msec()
			latency_ms = now_ms - _latency_ping_sent_at
			latency_updated.emit(latency_ms)
			_latency_ping_ref = EMPTY_REF
	else:
		for channel in _channels:
			if channel.is_member(message.get_topic(), message.get_join_ref()):
				channel.trigger(message)

# V2 text frame: [join_ref, ref, topic, event, payload]
func _parse_text_frame(packet) -> PhoenixMessage:
	var json_conv = JSON.new()
	if json_conv.parse(packet.get_string_from_utf8()) != OK:
		return null
	var frame = json_conv.get_data()
	if not (frame is Array) or frame.size() != 5:
		return null

	var join_ref = frame[0] if frame[0] != null else PhoenixMessage.GLOBAL_JOIN_REF
	var ref = frame[1] if frame[1] != null else PhoenixMessage.NO_REPLY_REF
	return PhoenixMessage.new(frame[2], frame[3], ref, join_ref, frame[4])

# V2 binary frames (server -> client), used for e.g. protobuf payloads:
#   push:      0 | join_ref_len | topic_len | event_len | join_ref topic event | payload
#   reply:     1 | join_ref_len | ref_len | topic_len | status_len | join_ref ref topic status | payload
#   broadcast: 2 | topic_len | event_len | topic event | payload
func _parse_binary_frame(packet : PackedByteArray) -> PhoenixMessage:
	if packet.size() < 1:
		return null

	match packet[0]:
		0:
			if packet.size() < 4: return null
			var join_ref_len = packet[1]
			var topic_len = packet[2]
			var event_len = packet[3]
			var pos = 4
			var join_ref = packet.slice(pos, pos + join_ref_len).get_string_from_utf8(); pos += join_ref_len
			var topic = packet.slice(pos, pos + topic_len).get_string_from_utf8(); pos += topic_len
			var event = packet.slice(pos, pos + event_len).get_string_from_utf8(); pos += event_len
			return PhoenixMessage.new(topic, event, PhoenixMessage.NO_REPLY_REF, join_ref, packet.slice(pos))
		1:
			if packet.size() < 5: return null
			var join_ref_len = packet[1]
			var ref_len = packet[2]
			var topic_len = packet[3]
			var status_len = packet[4]
			var pos = 5
			var join_ref = packet.slice(pos, pos + join_ref_len).get_string_from_utf8(); pos += join_ref_len
			var ref = packet.slice(pos, pos + ref_len).get_string_from_utf8(); pos += ref_len
			var topic = packet.slice(pos, pos + topic_len).get_string_from_utf8(); pos += topic_len
			var status = packet.slice(pos, pos + status_len).get_string_from_utf8(); pos += status_len
			var payload = {status = status, response = packet.slice(pos)}
			return PhoenixMessage.new(topic, "phx_reply", ref, join_ref, payload)
		2:
			if packet.size() < 3: return null
			var topic_len = packet[1]
			var event_len = packet[2]
			var pos = 3
			var topic = packet.slice(pos, pos + topic_len).get_string_from_utf8(); pos += topic_len
			var event = packet.slice(pos, pos + event_len).get_string_from_utf8(); pos += event_len
			return PhoenixMessage.new(topic, event, PhoenixMessage.NO_REPLY_REF, PhoenixMessage.GLOBAL_JOIN_REF, packet.slice(pos))
		_:
			return null

func _on_node_removed(node : Node):
	var channel = node as PhoenixChannel
	if channel:
		_find_and_remove_channel(channel)
