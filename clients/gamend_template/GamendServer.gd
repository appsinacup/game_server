class_name GamendServer
extends Node

func _after_startup() -> void:
	pass

func _before_stop() -> void:
	pass
	
func _after_user_register(_user: Dictionary) -> void:
	pass

func _after_user_login(_user: Dictionary) -> void:
	pass

func _before_lobby_create(attrs: Dictionary) -> Dictionary:
	return attrs

func _after_lobby_create(_lobby: Dictionary) -> void:
	pass

func _before_lobby_join(user: Dictionary, lobby: Dictionary, opts: Dictionary) -> Array:
	return [user, lobby, opts]

func _after_lobby_join(_user: Dictionary, _lobby: Dictionary) -> void:
	pass

func _before_lobby_leave(user: Dictionary, lobby: Dictionary) -> Array:
	return [user, lobby]

func _after_lobby_leave(_user: Dictionary, _lobby: Dictionary) -> void:
	pass

func _before_lobby_update(_lobby: Dictionary, attrs: Dictionary) -> Dictionary:
	return attrs

func _after_lobby_update(_lobby: Dictionary) -> void:
	pass

func _before_lobby_delete(lobby: Dictionary) -> Dictionary:
	return lobby

func _after_lobby_delete(_lobby: Dictionary) -> void:
	pass

func _before_user_kicked(host: Dictionary, target: Dictionary, lobby: Dictionary):
	return [host, target, lobby]

func _after_user_kicked(_host: Dictionary, _target: Dictionary, _lobby: Dictionary) -> void:
	pass

func _before_kv_get(_key: String, _opts: Dictionary) -> String:
	return "public"

func _after_lobby_host_change(_lobby: Dictionary, _new_host_id: String) -> void:
	pass

var websocket_server: WebSocketServer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	websocket_server = WebSocketServer.new()
	add_child(websocket_server)
	websocket_server.message_received.connect(_message_received)
	websocket_server.client_connected.connect(_client_connected)
	websocket_server.client_disconnected.connect(_client_disconnected)
	print("Gamend Server Godot Started")
	for i in 50:
		var err = websocket_server.listen(4010)
		if err != OK:
			print("Errored: ", str(err))
		else:
			break
		await get_tree().create_timer(1.0).timeout

func _send_result(peer_id: int, request_id, result):
	# Return all registered functions
	var result_with_request_id = {
		"request_id": request_id, "result": result
	}
	websocket_server.send(peer_id, JSON.stringify(result_with_request_id))
	

func _message_received(peer_id: int, message: String):
	var json = JSON.parse_string(message)
	#print(json)
	#print("Messaged: ", peer_id, " ", json)
	var args :Array= json.get("args", [])
	#print(json.get("meta", {}).get("caller"))
	#print(json.get("at"))
	var hook = json.get("hook")
	var request_id = json.get("request_id")
	#print("Hook: ", hook, " ", "args: ", args)
	match hook:
		"after_startup":
			_after_startup()
			_send_result(peer_id, request_id, _get_custom_hooks())
		"before_stop":
			_before_stop()
		"after_user_register":
			_after_user_register.callv(args)
		"after_user_login":
			_after_user_login.callv(args)
		"before_lobby_create":
			_send_result(peer_id, request_id, _before_lobby_create.callv(args))
		"after_lobby_create":
			_after_lobby_create.callv(args)
		"before_lobby_join":
			_send_result(peer_id, request_id, _before_lobby_join.callv(args))
		"after_lobby_join":
			_after_lobby_join.callv(args)
		"before_lobby_leave":
			_send_result(peer_id, request_id, _before_lobby_leave.callv(args))
		"after_lobby_leave":
			_after_lobby_leave.callv(args)
		"before_lobby_update":
			_send_result(peer_id, request_id, _before_lobby_update.callv(args))
		"after_lobby_update":
			_after_lobby_update.callv(args)
		"before_lobby_delete":
			_send_result(peer_id, request_id, _before_lobby_delete.callv(args))
		"after_lobby_delete":
			_after_lobby_delete.callv(args)
		"before_user_kicked":
			_send_result(peer_id, request_id, _before_user_kicked.callv(args))
		"after_user_kicked":
			_after_user_kicked.callv(args)
		"before_kv_get":
			_send_result(peer_id, request_id, _before_kv_get.callv(args))
		"after_lobby_host_change":
			_after_lobby_host_change.callv(args)
		"on_custom_hook":
			var hook_name = args[0]
			var params = args[1]
			if has_method(hook_name):
				var result = callv(hook_name, params)
				var result_with_request_id = {
					"request_id": request_id, "result": result
				}
				websocket_server.send(peer_id, JSON.stringify(result_with_request_id))
			else:
				var result_with_request_id = {
					"request_id": request_id, "error": "Cannot find method"
				}
				websocket_server.send(peer_id, JSON.stringify(result_with_request_id))
			
# Automatically collect all hooks
func _get_custom_hooks():
	var hooks: Array = []
	
	var script :Script= get_script()
	var methods = script.get_script_method_list()
	
	for method in methods:
		var hook_name: String = method["name"]
		if hook_name in ["after_startup",
			"before_stop",
			"after_user_register",
			"after_user_login",
			"on_custom_hook"] || \
			hook_name.begins_with("_"):
			continue
		var args: Array[Dictionary] = []
		
		for arg in method["args"]:
			var arg_type = ""
			match arg["type"]:
				TYPE_STRING:
					arg_type = "string"
				TYPE_BOOL:
					arg_type = "bool"
				TYPE_DICTIONARY:
					arg_type = "object"
				TYPE_ARRAY:
					arg_type = "array"
				TYPE_FLOAT:
					arg_type = "number"
				TYPE_INT:
					arg_type = "integer"
			args.append({
				"name": arg["name"],
				"type": arg_type
			})
		
		hooks.append({
			"hook": hook_name,
			"meta": {
				"description": "",
				"args": args
			}
		})
	return hooks

func _client_connected(peer_id: int):
	print("Client Connected: ", peer_id)
func _client_disconnected(peer_id: int):
	print("Client Disconnected: ", peer_id)
