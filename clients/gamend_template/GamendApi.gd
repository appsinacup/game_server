class_name GamendApi
extends Node2D

var _health : HealthApi
var _authenticate: AuthenticationApi
var _users: UsersApi
var _friends: FriendsApi
var _lobbies: LobbiesApi
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

func _call_api(api: ApiApiBeeClient, method_name: String, params: Array = []) -> GamendResult:
	var result = GamendResult.new()
	api.call(method_name,
		func(response: ApiApiResponseClient):
			result.response = response
			result.finished.emit(result)
			,
		func(error):
			result.error = error
			result.finished.emit(result)
			,
			params)
	return result

func authorize(access_token: String):
	_config.headers_base["Authorization"] = "Bearer " + access_token
	_create_apis()

### HEALTH

## Health check
func health_index() -> GamendResult:
	return _call_api(_health, "index")

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

## Login
func authenticate_login(login_request: LoginRequest):
	return _call_api(_authenticate, "login", [login_request])

## Device login
func authenticate_device_login(device_id: DeviceLoginRequest):
	return _call_api(_authenticate, "device_login", [device_id])

## Logout
func authenticate_logout():
	return _call_api(_authenticate, "logout", [])

## Unlink OAuth provider
func authenticate_unlink_provider(provider: String):
	return _call_api(_authenticate, "unlink_provider", [provider])

## Refresh access token
func authenticate_refresh_token(refresh_token: RefreshTokenRequest):
	return _call_api(_authenticate, "refresh_token", [refresh_token])
