class_name GamendApi
extends Node2D

var health : HealthApi
var authenticate: AuthenticationApi
var users: UsersApi
var config := ApiApiConfigClient.new()

const PROVIDER_DISCORD = "discord"
const PROVIDER_APPLE = "apple"
const PROVIDER_FACEBOOK = "facebook"
const PROVIDER_GOOGLE = "google"

func _init(host: String = "127.0.0.1", port: int = 4000):
	config.host = host
	config.port = port
	health = HealthApi.new(config)
	authenticate = AuthenticationApi.new(config)
	users = UsersApi.new(config)

func health_index() -> GamendResult:
	var result = GamendResult.new()
	health.index(
		func(response: ApiApiResponseClient):
			result.response = response
			result.finished.emit(result)
			,
		func(error):
			result.error = error
			result.finished.emit(result)
			,
	)
	return result

func users_get_user(authorization: String):
	var result = GamendResult.new()
	users.get_current_user(
		func(response: ApiApiResponseClient):
			result.response = response
			result.finished.emit(result)
			,
		func(error):
			result.error = error
			result.finished.emit(result)
			,
	)
	return result

func authorize(access_token: String):
	config.headers_base["Authorization"] = "Bearer " + access_token
	health = HealthApi.new(config)
	authenticate = AuthenticationApi.new(config)
	users = UsersApi.new(config)

func authenticate_login(login_request: LoginRequest):
	var result = GamendResult.new()
	authenticate.login(
		login_request,
		func(response: ApiApiResponseClient):
			result.response = response
			result.finished.emit(result)
			,
		func(error):
			result.error = error
			result.finished.emit(result)
			,
	)
	return result

func authenticate_logout():
	var result = GamendResult.new()
	authenticate.logout(
		func(response: ApiApiResponseClient):
			result.response = response
			result.finished.emit(result)
			,
		func(error):
			result.error = error
			result.finished.emit(result)
			,
	)
	return result

func authenticate_oauth_check_request(session_id: String):
	var result = GamendResult.new()
	authenticate.oauth_session_status(
		session_id,
		func(response: ApiApiResponseClient):
			result.response = response
			result.finished.emit(result)
			,
		func(error):
			result.error = error
			result.finished.emit(result)
			,
	)
	return result

func authenticate_oauth_request(session_id: String):
	var result = GamendResult.new()
	authenticate.oauth_request(
		session_id,
		func(response: ApiApiResponseClient):
			result.response = response
			result.finished.emit(result)
			,
		func(error):
			result.error = error
			result.finished.emit(result)
			,
	)
	return result
