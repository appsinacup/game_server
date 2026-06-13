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
var _channels := {}
var _payload_cache := {}
const LOG_REDACTED := "[redacted]"
const DELTA_UPDATE_KEY := "u"
const DELTA_REMOVE_KEY := "r"
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
func _init(token_provider: Callable, endpoint: String = PhoenixSocket.DEFAULT_BASE_ENDPOINT) -> void:
	_token_provider = token_provider
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
	_payload_cache.clear()
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
	var channel = socket.channel(topic, _socket_params(), null, _socket_params)
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
	_clear_payload_cache_for_topic(topic)
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
func _channel_on_event(event, payload: Dictionary, status, topic: String):
	var expanded_payload := _expand_payload_delta(topic, event, payload)
	if enable_logs:
		print("Channel on event ", topic, " ", event, " ", _redact_for_log(expanded_payload), " ", _redact_for_log(status))
	channel_event.emit(event, expanded_payload, status, topic)
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
	_clear_payload_cache_for_topic(topic)
	if topic.begins_with("user:"):
		user_channel_closed.emit()

func _get_user_channel() -> PhoenixChannel:
	for topic in _channels:
		if topic.begins_with("user:"):
			return _channels[topic]
	return null

func _socket_params() -> Dictionary:
	return {"token": _token_provider.call()}

func _expand_payload_delta(topic: String, event: String, payload: Dictionary) -> Dictionary:
	_update_payload_cache_for_related_events(topic, event, payload)

	if not _supports_payload_delta(topic, event):
		return payload

	var cache_key := _payload_cache_key(topic, event, payload)
	if cache_key == "":
		return payload

	if not _is_payload_delta(payload):
		var full_payload := payload.duplicate(true)
		_payload_cache[cache_key] = full_payload.duplicate(true)
		return full_payload

	var merged_payload := _cached_payload(cache_key, payload)
	if payload.get(DELTA_UPDATE_KEY, null) is Dictionary:
		_apply_delta_updates(merged_payload, payload[DELTA_UPDATE_KEY] as Dictionary)
	if payload.get(DELTA_REMOVE_KEY, null) is Dictionary:
		_apply_delta_removes(merged_payload, payload[DELTA_REMOVE_KEY] as Dictionary)

	_payload_cache[cache_key] = merged_payload.duplicate(true)
	return merged_payload

func _update_payload_cache_for_related_events(topic: String, event: String, payload: Dictionary) -> void:
	if topic == "lobbies" and event == "lobby_created":
		_cache_payload(topic, "lobby_updated", payload)
	elif topic == "groups" and event == "group_created":
		_cache_payload(topic, "group_updated", payload)
	elif topic == "lobbies" and event == "lobby_deleted":
		_erase_payload_cache(topic, "lobby_updated", payload)
	elif topic == "groups" and event == "group_deleted":
		_erase_payload_cache(topic, "group_updated", payload)

func _supports_payload_delta(topic: String, event: String) -> bool:
	if event == "updated" or event == "member_updated":
		return topic.begins_with("user:") or topic.begins_with("lobby:") or topic.begins_with("party:") or topic.begins_with("group:")
	return (topic == "lobbies" and event == "lobby_updated") or (topic == "groups" and event == "group_updated")

func _is_payload_delta(payload: Dictionary) -> bool:
	return payload.get(DELTA_UPDATE_KEY, null) is Dictionary or payload.get(DELTA_REMOVE_KEY, null) is Dictionary

func _cache_payload(topic: String, event: String, payload: Dictionary) -> void:
	var cache_key := _payload_cache_key(topic, event, payload)
	if cache_key != "":
		_payload_cache[cache_key] = payload.duplicate(true)

func _erase_payload_cache(topic: String, event: String, payload: Dictionary) -> void:
	var cache_key := _payload_cache_key(topic, event, payload)
	if cache_key != "":
		_payload_cache.erase(cache_key)

func _cached_payload(cache_key: String, payload: Dictionary) -> Dictionary:
	if _payload_cache.has(cache_key) and _payload_cache[cache_key] is Dictionary:
		return (_payload_cache[cache_key] as Dictionary).duplicate(true)
	return _identity_payload(payload)

func _payload_cache_key(topic: String, event: String, payload: Dictionary) -> String:
	var identity := _payload_identity(payload)
	if identity == "":
		return ""
	return "%s|%s|%s" % [topic, event, identity]

func _payload_identity(payload: Dictionary) -> String:
	if payload.has("id"):
		return "id:" + _identity_value(payload["id"])
	if payload.has("user_id"):
		return "user_id:" + _identity_value(payload["user_id"])
	return ""

func _identity_value(value: Variant) -> String:
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return str(int(value))
	return str(value)

func _identity_payload(payload: Dictionary) -> Dictionary:
	var identity := {}
	if payload.has("id"):
		identity["id"] = payload["id"]
	if payload.has("user_id"):
		identity["user_id"] = payload["user_id"]
	return identity

func _apply_delta_updates(target: Dictionary, updates: Dictionary) -> void:
	for key in updates:
		var update_value = updates[key]
		if target.get(key, null) is Dictionary and update_value is Dictionary:
			_apply_delta_updates(target[key] as Dictionary, update_value as Dictionary)
		else:
			target[key] = _duplicate_payload_value(update_value)

func _apply_delta_removes(target: Dictionary, removes: Dictionary) -> void:
	for key in removes:
		var remove_value = removes[key]
		if target.get(key, null) is Dictionary and remove_value is Dictionary:
			_apply_delta_removes(target[key] as Dictionary, remove_value as Dictionary)
		else:
			target.erase(key)

func _duplicate_payload_value(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value

func _clear_payload_cache_for_topic(topic: String) -> void:
	var prefix := topic + "|"
	for cache_key in _payload_cache.keys():
		if str(cache_key).begins_with(prefix):
			_payload_cache.erase(cache_key)

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
