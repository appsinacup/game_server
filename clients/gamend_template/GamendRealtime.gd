class_name GamendRealtime
extends Node

signal channel_event(event: String, payload: Dictionary, status, topic: String)
signal socket_opened()
signal socket_errored()
signal socket_closed()
signal latency_updated(latency_ms: int)
signal debug_message(severity: String, category: String, message: String)

var socket : PhoenixSocket
var enable_logs := true
var _token_provider: Callable
var _channels := {}

# Called when the node enters the scene tree for the first time.
func _init(token_provider: Callable, endpoint: String = PhoenixSocket.DEFAULT_BASE_ENDPOINT) -> void:
	_token_provider = token_provider
	var initial_token: String = _token_provider.call()
	socket = PhoenixSocket.new(endpoint, {
		"params": {"token": initial_token},
		"params_provider": func(): return {"token": _token_provider.call()}
	})
	socket.on_close.connect(_socket_on_close)
	socket.on_connecting.connect(_socket_on_connecting)
	socket.on_error.connect(_socket_on_error)
	socket.on_open.connect(_socket_on_open)
	socket.latency_updated.connect(func(ms: int): latency_updated.emit(ms))
	add_child(socket)
	socket.connect_socket()

func add_channel(topic: String):
	if _channels.has(topic):
		return _channels[topic]
	var channel = socket.channel(topic, {"token": _token_provider.call()},
		null, func(): return {"token": _token_provider.call()})
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

func _socket_on_open(params):
	if enable_logs:
		print("Socket Open ", params)
	debug_message.emit("info", "network", "WebSocket connected")
	socket_opened.emit()
func _socket_on_error(data):
	if enable_logs:
		print("Socket Error ", data)
	debug_message.emit("err", "network", "WebSocket error: %s" % str(data))
	socket_errored.emit()
func _socket_on_close(params):
	if enable_logs:
		print("Socket Closed")
	debug_message.emit("warn", "network", "WebSocket closed")
	socket_closed.emit()
func _socket_on_connecting(is_connecting):
	if enable_logs:
		print("Socket Connecting... ", is_connecting)

func _channel_on_join_result(event, payload, topic):
	if enable_logs:
		print("Channel on join ", topic, " ", event, " ", payload)
	debug_message.emit("info", "network", "Channel joined: %s event=%s" % [topic, event])
func _channel_on_event(event, payload: Dictionary, status, topic: String):
	if enable_logs:
		print("Channel on event ", topic, " ", event, " ", payload, " ", status)
	channel_event.emit(event, payload, status, topic)
func _channel_on_error(error, topic):
	if enable_logs:
		print("Channel on error ", topic, " ", error)
	debug_message.emit("err", "network", "Channel error: %s \u2013 %s" % [topic, str(error)])
func _channel_on_close(params, topic):
	if enable_logs:
		print("Channel on close ", topic, " ", params)
	if _channels.has(topic):
		_channels.erase(topic)
