## Open source game server with authentication, users, lobbies, server scripting and an admin portal
##
## Game + Backend = Gamend
class_name GamendApi
extends Node2D

var _health : HealthApi
var _authenticate: AuthenticationApi
var _users: UsersApi
var _friends: FriendsApi
var _lobbies: LobbiesApi
var _hooks: HooksApi
var _config := ApiApiConfigClient.new()

const PROVIDER_DISCORD = "discord"
const PROVIDER_APPLE = "apple"
const PROVIDER_FACEBOOK = "facebook"
const PROVIDER_GOOGLE = "google"
const PROVIDER_STEAM = "steam"

func _init(host: String = "127.0.0.1", port: int = 4000):
	_config.host = host
	_config.port = port
	_create_apis()

func _create_apis():
	_health = HealthApi.new(_config)
	_authenticate = AuthenticationApi.new(_config)
	_users = UsersApi.new(_config)
	_friends = FriendsApi.new(_config)
	_lobbies = LobbiesApi.new(_config)
	_hooks = HooksApi.new(_config)

func _call_api(api: ApiApiBeeClient, method_name: String, params: Array = []) -> GamendResult:
	var result = GamendResult.new()
	var callables = [
		func(response: ApiApiResponseClient):
			result.response = response
			result.finished.emit(result)
			,
		func(error):
			result.error = error
			result.finished.emit(result)]
	params.append_array(callables)
	api.callv(method_name, params)
	return result

## Authorize with access token
func authorize(access_token: String):
	_config.headers_base["Authorization"] = "Bearer " + access_token
	_create_apis()

### HEALTH

## Health check
func health_index() -> GamendResult:
	return _call_api(_health, "index")

### HOOKS

## Invoke a hook function
func hooks_call_hook(hook_request: CallHookRequest) -> GamendResult:
	return _call_api(_hooks, "call_hook", [hook_request])

## List available hook functions
func hooks_list_hooks() -> GamendResult:
	return _call_api(_hooks, "list_hooks", [])

### USERS

## Delete current user
func user_delete_current_user():
	return _call_api(_users, "delete_current_user")

## Get current user info
func users_get_current_user():
	return _call_api(_users, "get_current_user")

## Update current user's display name
func user_update_current_user_display_name(display_name: String):
	return _call_api(_users, "update_current_user_display_name", [display_name])

## Update current user's password
func user_update_current_user_password(password: String):
	return _call_api(_users, "update_current_user_password", [password])

## Search users by id/email/display_name
func users_search_users(query = "", page = 0, pageSize = 25):
	return _call_api(_users, "search_users", [query, page, pageSize])

## Get a user by id
func users_get_user(id: String):
	return _call_api(_users, "get_user", [id])


### AUTHENTICATION

## Get OAuth session status
func authenticate_oauth_session_status(session_id: String):
	return _call_api(_authenticate, "oauth_session_status", [session_id])

## Initiate API OAuth
func authenticate_oauth_request(provider: String):
	return _call_api(_authenticate, "oauth_request", [provider])

## API Callback / Code Exchange
func authenticate_oauth_api_callback(provider: String, callback_request: OauthApiCallbackRequest):
	return _call_api(_authenticate, "oauth_api_callback", [provider, callback_request])

## Login
func authenticate_login(login_request: LoginRequest):
	return _call_api(_authenticate, "login", [login_request])

## Device login
func authenticate_device_login(device_id: DeviceLoginRequest):
	return _call_api(_authenticate, "device_login", [device_id])

## Logout
func authenticate_logout():
	return _call_api(_authenticate, "logout")

## Unlink OAuth provider
func authenticate_unlink_provider(provider: String):
	return _call_api(_authenticate, "unlink_provider", [provider])

## Refresh access token
func authenticate_refresh_token(refresh_token: RefreshTokenRequest):
	return _call_api(_authenticate, "refresh_token", [refresh_token])

### FRIENDS

## Send a friend request
func friends_create_friend_request(friend_request: CreateFriendRequestRequest):
	return _call_api(_friends, "create_friend_request", [friend_request])

## Remove/cancel a friendship or request
func friends_remove_friendship(id: int):
	return _call_api(_friends, "remove_friendship", [id])

## Accept a friend request
func friends_accept_friend_request(id: int):
	return _call_api(_friends, "accept_friend_request", [id])

## Block a friend request / user
func friends_block_friend_request(id: int):
	return _call_api(_friends, "block_friend_request", [id])

## Reject a friend request
func friends_reject_friend_request(id: int):
	return _call_api(_friends, "reject_friend_request", [id])

## Unblock a previously-blocked friendship
func friends_unblock_friend(id: int):
	return _call_api(_friends, "unblock_friend", [id])

## List users you've blocked
func friends_list_blocked_friends(page = 0, page_size = 0):
	_friends.list_blocked_friends()
	return _call_api(_friends, "list_blocked_friends", [page, page_size])

## List pending friend requests (incoming and outgoing)
func friends_list_friend_requests(page = 0, page_size = 0):
	return _call_api(_friends, "list_friend_requests", [page, page_size])

## List current user's friends (returns a paginated set of user objects)
func friends_list_friends(page = 0, page_size = 0):
	return _call_api(_friends, "list_friends", [page, page_size])

### LOBBIES

## List lobbies
func lobbies_list_lobbies(
	query = "",
	page = null,
	page_size = null,
	metadata_key = "",
	metadata_value = ""):
	return _call_api(_lobbies, "list_lobbies", [query, page, page_size, metadata_key, metadata_value])

## Update lobby (host only)
func lobbies_update_lobby(update_request: UpdateLobbyRequest):
	return _call_api(_lobbies, "update_lobby", [update_request])

## Create a lobby
func lobbies_create_lobby(create_request: CreateLobbyRequest):
	return _call_api(_lobbies, "create_lobby", [create_request])

## Kick a user from the lobby (host only)
func lobbies_kick_user(kick_request: KickUserRequest):
	return _call_api(_lobbies, "kick_user", [kick_request])

## Leave the current lobby
func lobbies_leave_lobby():
	return _call_api(_lobbies, "leave_lobby")

## Join a lobby
func lobbies_join_lobby(id: int, join_request: JoinLobbyRequest = null):
	return _call_api(_lobbies, "join_lobby", [id, join_request])
