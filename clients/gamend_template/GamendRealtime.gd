class_name GamendRealtime
extends Node

signal channel_event(event: String, payload: Dictionary, status, topic: String)
signal socket_opened()
signal socket_errored()
signal socket_closed()

var socket : PhoenixSocket
var enable_logs := false
var _token: String

# Called when the node enters the scene tree for the first time.
func _init(token: String, endpoint: String = PhoenixSocket.DEFAULT_BASE_ENDPOINT) -> void:
	_token = token
	socket = PhoenixSocket.new(endpoint, {"params": {
		"token": _token
	}})
	socket.on_close.connect(_socket_on_close)
	socket.on_connecting.connect(_socket_on_connecting)
	socket.on_error.connect(_socket_on_error)
	socket.on_open.connect(_socket_on_open)
	add_child(socket)
	socket.connect_socket()

func add_channel(topic: String):
	var channel = socket.channel(topic, {"token": _token})
	channel.on_close.connect(_channel_on_close.bind(channel.get_topic()))
	channel.on_event.connect(_channel_on_event.bind(channel.get_topic()))
	channel.on_error.connect(_channel_on_error.bind(channel.get_topic()))
	channel.on_join_result.connect(_channel_on_join_result.bind(channel.get_topic()))
	channel.join()

func _socket_on_open(params):
	if enable_logs:
		print("Socket Open ", params)
	socket_opened.emit()
func _socket_on_error(data):
	if enable_logs:
		print("Socket Error ", data)
	socket_errored.emit(data)
func _socket_on_close():
	if enable_logs:
		print("Socket Closed")
	socket_closed.emit()
func _socket_on_connecting(is_connecting):
	if enable_logs:
		print("Socket Connecting... ", is_connecting)

func _channel_on_join_result(event, payload, topic):
	if enable_logs:
		print("Channel on join ", topic, " ", event, " ", payload)
func _channel_on_event(event, payload: Dictionary, status, topic: String):
	if enable_logs:
		print("Channel on event ", topic, " ", event, " ", payload, " ", status)
	channel_event.emit(event, payload, status, topic)
func _channel_on_error(error, topic):
	if enable_logs:
		print("Channel on error ", topic, " ", error)
func _channel_on_close(params, topic):
	if enable_logs:
		print("Channel on close ", topic, " ", params)
