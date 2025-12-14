## Open source game server with authentication, users, lobbies, server scripting and an admin portal
##
## Game + Backend = Gamend
class_name GamendApi
extends Node

signal user_updated(user: Dictionary)

var _config := ApiApiConfigClient.new()
var _realtime: GamendRealtime
var enable_logs := true
var enable_ssl := false

const PROVIDER_DISCORD = "discord"
const PROVIDER_APPLE = "apple"
const PROVIDER_FACEBOOK = "facebook"
const PROVIDER_GOOGLE = "google"
const PROVIDER_STEAM = "steam"

var _access_token := ""
var _refresh_token := ""
var _user_id = -1

func _init(host: String = "127.0.0.1", port: int = 4000, enable_ssl := false):
	_config.host = host
	_config.tls_enabled = enable_ssl
	_config.log_level = ApiApiConfigClient.LogLevel.INFO
	_config.port = port

func _call_api(api: ApiApiBeeClient, method_name: String, params: Array = []) -> GamendResult:
	var result = GamendResult.new()
	var callables = [
		func(response: ApiApiResponseClient):
			result.response = response
			_verify_login_result(method_name, response.data)
			if enable_logs:
				print(api._bzz_name, " ", method_name, " ", response.body)
			result.finished.emit(result)
			,
		func(error):
			result.error = error
			if enable_logs:
				print(api._bzz_name, " ", method_name, " ", result.error)
			result.finished.emit(result)]
	params.append_array(callables)
	api.callv(method_name, params)
	return result

func is_authenticated():
	return _access_token != ""

func _verify_login_result(method_name: String, data):
	if data && method_name in ["oauth_session_status", "oauth_api_callback", "login", "device_login", "refresh_token"]:
		data = data.bzz_normalize().get("data").bzz_normalize()
		if data.get("access_token"):
			_access_token = data["access_token"]
		if data.get("refresh_token"):
			_refresh_token = data["refresh_token"]
		if data.get("user_id"):
			_user_id = data["user_id"]
		authorize()
	if method_name == "logout":
		_access_token = ""
		_refresh_token = ""
		_user_id = -1
		authorize()

func realtime_start():
	realtime_stop()
	var result := GamendResult.new()
	var protocol = "ws://"
	if _config.tls_enabled:
		protocol = "wss://"
	_realtime = GamendRealtime.new(_access_token, protocol + _config.host + ":" + str(_config.port) + "/socket")
	_realtime.enable_logs = enable_logs
	_realtime.socket_opened.connect(func (): if result: result.finished.emit())
	_realtime.socket_closed.connect(func (): if result: result.finished.emit())
	_realtime.socket_errored.connect(func (): if result: result.finished.emit())
	add_child(_realtime)
	return result

func realtime_stop():
	if _realtime:
		_realtime.queue_free()
	_realtime = null

func listen_to_user():
	_realtime.add_channel("user:" + str(int(_user_id)))
	_realtime.channel_event.connect(_on_channel_event)


func _on_channel_event(event: String, payload: Dictionary, status, topic: String):
	if topic.begins_with("user") && event == "updated":
		user_updated.emit(payload)

## Authorize with access token
func authorize():
	_config.headers_base["Authorization"] = "Bearer " + _access_token

### HEALTH

## Health check
func health_index() -> GamendResult:
	return _call_api(HealthApi.new(_config), "index")

### HOOKS

## Invoke a hook function
func hooks_call_hook(hook_request: CallHookRequest) -> GamendResult:
	return _call_api(HooksApi.new(_config), "call_hook", [hook_request])

## List available hook functions
func hooks_list_hooks() -> GamendResult:
	return _call_api(HooksApi.new(_config), "list_hooks", [])

### USERS

## Delete current user
func user_delete_current_user():
	return _call_api(UsersApi.new(_config), "delete_current_user")

## Get current user info
func users_get_current_user():
	return _call_api(UsersApi.new(_config), "get_current_user")

## Update current user's display name
func user_update_current_user_display_name(display_name: String):
	var request := UpdateCurrentUserDisplayNameRequest.new()
	request.display_name = display_name
	return _call_api(UsersApi.new(_config), "update_current_user_display_name", [request])

## Update current user's password
func user_update_current_user_password(password: String):
	return _call_api(UsersApi.new(_config), "update_current_user_password", [password])

## Search users by id/email/display_name
func users_search_users(query = "", page = 1, pageSize = 25):
	return _call_api(UsersApi.new(_config), "search_users", [query, page, pageSize])

## Get a user by id
func users_get_user(id: String):
	return _call_api(UsersApi.new(_config), "get_user", [id])


### AUTHENTICATION

## Get OAuth session status
func authenticate_oauth_session_status(session_id: String):
	return _call_api(AuthenticationApi.new(_config), "oauth_session_status", [session_id])

## Initiate API OAuth
func authenticate_oauth_request(provider: String):
	return _call_api(AuthenticationApi.new(_config), "oauth_request", [provider])

## API Callback / Code Exchange
func authenticate_oauth_api_callback(provider: String, callback_request: OauthApiCallbackRequest):
	return _call_api(AuthenticationApi.new(_config), "oauth_api_callback", [provider, callback_request])

## Login
func authenticate_login(login_request: LoginRequest):
	return _call_api(AuthenticationApi.new(_config), "login", [login_request])

## Device login
func authenticate_device_login(device_id: String):
	var device_login := DeviceLoginRequest.new()
	device_login.device_id = device_id
	return _call_api(AuthenticationApi.new(_config), "device_login", [device_login])

## Logout
func authenticate_logout():
	return _call_api(AuthenticationApi.new(_config), "logout")

## Unlink OAuth provider
func authenticate_unlink_provider(provider: String):
	return _call_api(AuthenticationApi.new(_config), "unlink_provider", [provider])

## Unlink device
func authenticate_unlink_device():
	return _call_api(AuthenticationApi.new(_config), "unlink_device", [])

## Link device
func authenticate_link_device(device_id: String):
	var linkDeviceRequest:= LinkDeviceRequest.new()
	linkDeviceRequest.device_id = device_id
	return _call_api(AuthenticationApi.new(_config), "link_device", [linkDeviceRequest])

## Refresh access token
func authenticate_refresh_token(refresh_token: String):
	var refresh_param:= RefreshTokenRequest.new()
	refresh_param.refresh_token = refresh_token
	return _call_api(AuthenticationApi.new(_config), "refresh_token", [refresh_param])

### FRIENDS

## Send a friend request
func friends_create_friend_request(friend_request: CreateFriendRequestRequest):
	return _call_api(FriendsApi.new(_config), "create_friend_request", [friend_request])

## Remove/cancel a friendship or request
func friends_remove_friendship(id: int):
	return _call_api(FriendsApi.new(_config), "remove_friendship", [id])

## Accept a friend request
func friends_accept_friend_request(id: int):
	return _call_api(FriendsApi.new(_config), "accept_friend_request", [id])

## Block a friend request / user
func friends_block_friend_request(id: int):
	return _call_api(FriendsApi.new(_config), "block_friend_request", [id])

## Reject a friend request
func friends_reject_friend_request(id: int):
	return _call_api(FriendsApi.new(_config), "reject_friend_request", [id])

## Unblock a previously-blocked friendship
func friends_unblock_friend(id: int):
	return _call_api(FriendsApi.new(_config), "unblock_friend", [id])

## List users you've blocked
func friends_list_blocked_friends(page = 1, page_size = 25):
	return _call_api(FriendsApi.new(_config), "list_blocked_friends", [page, page_size])

## List pending friend requests (incoming and outgoing)
func friends_list_friend_requests(page = 1, page_size = 25):
	return _call_api(FriendsApi.new(_config), "list_friend_requests", [page, page_size])

## List current user's friends (returns a paginated set of user objects)
func friends_list_friends(page = 1, page_size = 25):
	return _call_api(FriendsApi.new(_config), "list_friends", [page, page_size])

### LOBBIES

## List lobbies
func lobbies_list_lobbies(
	query = "",
	page = null,
	page_size = null,
	metadata_key = "",
	metadata_value = ""):
	return _call_api(LobbiesApi.new(_config), "list_lobbies", [query, page, page_size, metadata_key, metadata_value])

## Update lobby (host only)
func lobbies_update_lobby(update_request: UpdateLobbyRequest):
	return _call_api(LobbiesApi.new(_config), "update_lobby", [update_request])

## Create a lobby
func lobbies_create_lobby(create_request: CreateLobbyRequest):
	return _call_api(LobbiesApi.new(_config), "create_lobby", [create_request])

## Kick a user from the lobby (host only)
func lobbies_kick_user(kick_request: KickUserRequest):
	return _call_api(LobbiesApi.new(_config), "kick_user", [kick_request])

## Leave the current lobby
func lobbies_leave_lobby():
	return _call_api(LobbiesApi.new(_config), "leave_lobby")

## Quick-join or create a lobby
func lobbies_quick_join(quick_request: QuickJoinRequest):
	return _call_api(LobbiesApi.new(_config), "quick_join", [quick_request])

## Join a lobby
func lobbies_join_lobby(id: int, join_request: JoinLobbyRequest = null):
	return _call_api(LobbiesApi.new(_config), "join_lobby", [id, join_request])

### LEADERBOARDS

## List leaderboard records
func leaderboards_list_leaderboard_records(id: int, page = 1, page_size = 25):
	return _call_api(LeaderboardsApi.new(_config), "list_leaderboard_records", [id, page, page_size])

## List leaderboards
func leaderboards_list_leaderboards(slug = "", active = "", order_by = "ends_at", starts_after = null, starts_before = null, ends_after = null, ends_before = null, page = 1, page_size = 25):
	return _call_api(LeaderboardsApi.new(_config), "list_leaderboards", [slug, active, order_by, starts_after, starts_before, ends_after, ends_before, page, page_size])

## Get current user's record
func leaderboards_get_my_record(id: int):
	return _call_api(LeaderboardsApi.new(_config), "get_my_record", [id])

## List records around a user
func leaderboards_list_records_around_user(id: int, user_id: int, limit = 11):
	return _call_api(LeaderboardsApi.new(_config), "list_records_around_user", [id, user_id, limit])
