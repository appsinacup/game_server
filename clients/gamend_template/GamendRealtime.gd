class_name GamendRealtime
extends Node

signal channel_event(event: String, payload: Dictionary, status, topic: String)
signal socket_opened()
signal socket_errored()
signal socket_closed()
signal latency_updated(latency_ms: int)
signal debug_message(severity: String, category: String, message: String)
signal user_channel_joined()
signal user_channel_closed()
signal user_channel_error()
signal channel_join_failed(topic: String, reason: String, payload: Dictionary)

var socket : PhoenixSocket
var enable_logs := false
var _token_provider: Callable
var _format := "json"
var _channels := {}
var _request_seq := 0
const LOG_REDACTED := "[redacted]"
const EVENT_LOG_MAX_CHARS := 768
const SENSITIVE_LOG_KEYS := {
	"access_token": true,
	"authorization": true,
	"cookie": true,
	"password": true,
	"refresh_token": true,
	"set-cookie": true,
	"token": true,
}

# Called when the node enters the scene tree for the first time.
# format: "json" (default) or "protobuf" — with "protobuf" the server sends
# mapped events as binary protobuf frames (decoded transparently before
# channel_event is emitted; timestamps arrive as unix-ms ints).
func _init(token_provider: Callable, endpoint: String = PhoenixSocket.DEFAULT_BASE_ENDPOINT, format: String = "json") -> void:
	_token_provider = token_provider
	_format = "protobuf" if format == "protobuf" else "json"
	socket = PhoenixSocket.new(endpoint, {
		"params": _socket_params(),
		"params_provider": _socket_params
	})
	socket.on_close.connect(_socket_on_close)
	socket.on_connecting.connect(_socket_on_connecting)
	socket.on_error.connect(_socket_on_error)
	socket.on_open.connect(_socket_on_open)
	socket.latency_updated.connect(_socket_latency_updated)
	add_child(socket)
	socket.connect_socket()

func shutdown() -> void:
	for topic in _channels.keys():
		var channel: PhoenixChannel = _channels[topic]
		channel.close({message = "shutdown"}, false)
		channel.queue_free()
	_channels.clear()
	if socket != null:
		socket.shutdown()

func add_channel(topic: String):
	if _channels.has(topic):
		return _channels[topic]
	var channel = socket.channel(topic, _socket_params(), null)
	_channels[topic] = channel
	channel.on_close.connect(_channel_on_close.bind(channel.get_topic()))
	channel.on_event.connect(_channel_on_event.bind(channel.get_topic()))
	channel.on_error.connect(_channel_on_error.bind(channel.get_topic()))
	channel.on_join_result.connect(_channel_on_join_result.bind(channel.get_topic()))
	channel.join()
	debug_message.emit("info", "network", "Channel joining: %s" % topic)
	return channel

## Gracefully leave and remove a channel so it won't try to rejoin.
func remove_channel(topic: String) -> void:
	if not _channels.has(topic):
		return
	var channel: PhoenixChannel = _channels[topic]
	_channels.erase(topic)
	channel.leave()
	debug_message.emit("info", "network", "Channel left: %s" % topic)
	channel.queue_free()

func call_hook(plugin: String, fn_name: String, args: Array = [], topic: String = "") -> bool:
	return push("call_hook", {"plugin": plugin, "fn": fn_name, "args": args}, topic)

func push(event: String, payload: Dictionary = {}, topic: String = "") -> bool:
	var ch: PhoenixChannel
	if topic == "":
		ch = _get_user_channel()
	elif _channels.has(topic):
		ch = _channels[topic]
	if ch == null:
		push_warning("GamendRealtime: no channel found for push")
		return false
	return ch.push(event, payload)

func request(event: String, payload: Dictionary = {}, topic: String = "", timeout_sec: float = 15.0) -> Dictionary:
	var ch: PhoenixChannel
	var reply_topic := topic
	if topic == "":
		ch = _get_user_channel()
		if ch != null:
			reply_topic = ch.get_topic()
	elif _channels.has(topic):
		ch = _channels[topic]
	if ch == null:
		return _request_error("no_channel", "No channel found for request")

	var request_id := _next_request_id()
	var request_payload := payload.duplicate(true)
	request_payload["_request_id"] = request_id
	var state := {
		"done": false,
		"payload": {},
		"status": "error",
	}
	var handler := func(reply_event: String, reply_payload: Dictionary, status, event_topic: String) -> void:
		if reply_event != event or event_topic != reply_topic:
			return
		if str(reply_payload.get("_request_id", "")) != request_id:
			return
		state["done"] = true
		state["payload"] = reply_payload.duplicate(true)
		state["status"] = str(status)

	channel_event.connect(handler)
	var pushed := ch.push(event, request_payload)
	if not pushed:
		if channel_event.is_connected(handler):
			channel_event.disconnect(handler)
		return _request_error("push_failed", "Channel rejected request")

	var tree := get_tree()
	if tree == null:
		if channel_event.is_connected(handler):
			channel_event.disconnect(handler)
		return _request_error("no_scene_tree", "Cannot wait for channel reply")

	var started_ms := Time.get_ticks_msec()
	var timeout_ms := int(max(0.1, timeout_sec) * 1000.0)
	while not bool(state["done"]) and Time.get_ticks_msec() - started_ms < timeout_ms:
		await tree.process_frame

	if channel_event.is_connected(handler):
		channel_event.disconnect(handler)
	if bool(state["done"]):
		return {"status": state["status"], "payload": state["payload"]}
	return _request_error("timeout", "Channel request timed out")

func _socket_on_open(params):
	if enable_logs:
		print("Socket Open ", _redact_for_log(params))
	debug_message.emit("info", "network", "WebSocket connected")
	socket_opened.emit()
func _socket_on_error(data):
	if enable_logs:
		print("Socket Error ", _redact_for_log(data))
	debug_message.emit("err", "network", "WebSocket error: %s" % _redact_for_log(str(data)))
	socket_errored.emit()
func _socket_on_close(params):
	if enable_logs:
		print("Socket Closed")
	debug_message.emit("warn", "network", "WebSocket closed")
	socket_closed.emit()
func _socket_on_connecting(is_connecting):
	if enable_logs:
		print("Socket Connecting... ", is_connecting)

func _socket_latency_updated(ms: int) -> void:
	latency_updated.emit(ms)

func _channel_on_join_result(event, payload, topic):
	if enable_logs:
		print("Channel on join ", topic, " ", event, " ", _redact_for_log(payload))
	var event_name := str(event)
	var payload_dict: Dictionary = {}
	if payload is Dictionary:
		payload_dict = (payload as Dictionary).duplicate(true)
	if event_name != "ok":
		var reason := str(payload_dict.get("reason", event_name))
		debug_message.emit("err", "network", "Channel join failed: %s reason=%s" % [topic, _redact_for_log(reason)])
		channel_join_failed.emit(topic, reason, payload_dict)
		if topic.begins_with("user:"):
			user_channel_error.emit()
		return
	debug_message.emit("info", "network", "Channel joined: %s event=%s" % [topic, event])
	if topic.begins_with("user:"):
		user_channel_joined.emit()
func _channel_on_event(event, payload, status, topic: String):
	if payload is PackedByteArray:
		var decoded = GamendProto.decode_event(topic, event, payload)
		if decoded == null:
			# No protobuf mapping: deliver the raw frame as-is.
			channel_event.emit(event, payload, status, topic)
			return
		payload = decoded
	if enable_logs:
		print("Channel on event ", topic, " ", event, " ", _format_log_value(payload), " ", _format_log_value(status))
	channel_event.emit(event, payload, status, topic)
func _channel_on_error(error, topic):
	if enable_logs:
		print("Channel on error ", topic, " ", _redact_for_log(error))
	debug_message.emit("err", "network", "Channel error: %s \u2013 %s" % [topic, _redact_for_log(str(error))])
	if topic.begins_with("user:"):
		user_channel_error.emit()
func _channel_on_close(params, topic):
	if enable_logs:
		print("Channel on close ", topic, " ", _redact_for_log(params))
	if _channels.has(topic):
		_channels.erase(topic)
	if topic.begins_with("user:"):
		user_channel_closed.emit()

func _get_user_channel() -> PhoenixChannel:
	for topic in _channels:
		if topic.begins_with("user:"):
			return _channels[topic]
	return null

func _socket_params() -> Dictionary:
	var params := {"token": _token_provider.call()}
	if _format == "protobuf":
		params["format"] = "protobuf"
	return params

func _next_request_id() -> String:
	_request_seq += 1
	return "%s:%d:%d" % [str(get_instance_id()), Time.get_ticks_msec(), _request_seq]

func _request_error(error_name: String, message: String) -> Dictionary:
	return {
		"status": "error",
		"payload": {
			"error": error_name,
			"message": message,
		},
	}

func _redact_for_log(value: Variant, depth: int = 0) -> Variant:
	if depth > 8:
		return "<max-depth>"
	match typeof(value):
		TYPE_DICTIONARY:
			var redacted := {}
			for key in value:
				if _is_sensitive_log_key(str(key)):
					redacted[key] = LOG_REDACTED
				else:
					redacted[key] = _redact_for_log(value[key], depth + 1)
			return redacted
		TYPE_ARRAY:
			var redacted_array := []
			for item in value:
				redacted_array.append(_redact_for_log(item, depth + 1))
			return redacted_array
		TYPE_STRING:
			var text := value as String
			var stripped := text.strip_edges()
			if stripped.begins_with("{") or stripped.begins_with("["):
				var parsed := JSON.parse_string(stripped)
				if parsed != null:
					return JSON.stringify(_redact_for_log(parsed, depth + 1))
			if stripped.begins_with("Bearer "):
				return "Bearer " + LOG_REDACTED
			return text
		_:
			return value

func _is_sensitive_log_key(key: String) -> bool:
	var normalized := key.to_lower()
	if SENSITIVE_LOG_KEYS.has(normalized):
		return true
	return normalized.ends_with("_token") or normalized.contains("password")

func _format_log_value(value: Variant, limit: int = EVENT_LOG_MAX_CHARS) -> String:
	var safe := _redact_for_log(value)
	var text := safe if safe is String else JSON.stringify(safe)
	return text if text.length() <= limit else text.left(limit) + "... (%d chars truncated)" % (text.length() - limit)
