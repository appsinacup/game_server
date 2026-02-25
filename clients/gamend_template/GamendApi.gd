## Open source game server with authentication, users, lobbies, server scripting and an admin portal
##
## Game + Backend = Gamend
class_name GamendApi
extends Node

signal notification_emitted(content: Dictionary)
signal user_updated(user: Dictionary)
signal lobby_updated(lobby: Dictionary)

var _config := ApiApiConfigClient.new()
var _realtime: GamendRealtime
var enable_logs := true
var enable_ssl := false
var TIME_TO_WAIT_RECONNECT = 5000
@export var http_client_pool_size := 4

const PROVIDER_DISCORD = "discord"
const PROVIDER_APPLE = "apple"
const PROVIDER_FACEBOOK = "facebook"
const PROVIDER_GOOGLE = "google"
const PROVIDER_STEAM = "steam"

var _access_token := ""
var _refresh_token := ""
var _expires_at_ms := -1
var _user_id = -1
var _lobby_id = -1
var _refreshing_token = false
var _http_clients: Array = []
var _http_clients_in_flight: Array = []
var _http_client_pool_index := 0

func _init(host: String = "127.0.0.1", port: int = 4000, enable_ssl := false):
	_config.host = host
	_config.tls_enabled = enable_ssl
	_config.log_level = ApiApiConfigClient.LogLevel.INFO
	_config.port = port
	_config.polling_interval_ms = 1
	_config.headers_override["Connection"] = "keep-alive"
	_ensure_http_client_pool()

func _ensure_http_client_pool() -> void:
	var desired := max(1, int(http_client_pool_size))
	if _http_clients.size() != desired:
		_http_clients.clear()
		_http_clients_in_flight.clear()
		for i in range(desired):
			_http_clients.append(HTTPClient.new())
			_http_clients_in_flight.append(false)
		_http_client_pool_index = 0

func _acquire_http_client() -> int:
	_ensure_http_client_pool()
	var size := _http_clients.size()
	while true:
		for offset in range(size):
			var idx := (_http_client_pool_index + offset) % size
			if not _http_clients_in_flight[idx]:
				_http_clients_in_flight[idx] = true
				_http_client_pool_index = (idx + 1) % size
				return idx
		await get_tree().process_frame
	return -1

func _release_http_client(idx: int) -> void:
	if idx >= 0 and idx < _http_clients_in_flight.size():
		_http_clients_in_flight[idx] = false

func _verify_token_expired():
	# Only one refreshes at a time
	var started_wait = Time.get_ticks_msec()
	while _refreshing_token && Time.get_ticks_msec() - started_wait < TIME_TO_WAIT_RECONNECT:
		await get_tree().create_timer(0.5).timeout
	# If the access token expired, refresh it
	if _refresh_token && Time.get_ticks_msec() > _expires_at_ms:
		_refreshing_token = true
		var result :GamendResult= await authenticate_refresh_token(_refresh_token)
		if result.error:
			# Can't refresh token, return to login screen.
			get_tree().reload_current_scene()
		_refreshing_token = false

func _call_api(api: ApiApiBeeClient, method_name: String, params: Array = []) -> GamendResult:
	# Check if it's close to expiring first, if so make a refresh_call if we already have access token
	var start_request_time = Time.get_ticks_msec()
	if enable_logs:
		print("Requesting: ", api._bzz_name, " ", method_name, " ", params)
	if method_name != "refresh_token":
		await _verify_token_expired()
	api._bzz_keep_alive = true
	var client_idx := await _acquire_http_client()
	if client_idx >= 0:
		api._bzz_client = _http_clients[client_idx]
	var result = GamendResult.new()
	var callables = [
		func(response: ApiApiResponseClient):
			_release_http_client(client_idx)
			result.response = response
			_verify_login_result(method_name, response.data)
			if enable_logs:
				print(api._bzz_name, " ", method_name, " ", response.body, " t: ", (Time.get_ticks_msec() - start_request_time) / 1000.0)
			result.finished.emit(result)
			,
		func(error):
			_release_http_client(client_idx)
			if error.response_code == 401:
				# Expire the token now.
				_expires_at_ms = -1
			result.error = error
			if enable_logs:
				print(api._bzz_name, " ", method_name, " ", result.error, " t: ", (Time.get_ticks_msec() - start_request_time) / 1000.0)
			result.finished.emit(result)]
	params.append_array(callables)
	api.callv(method_name, params)
	return await result.finished

func is_authenticated():
	return _access_token != ""

func _verify_login_result(method_name: String, data):
	if data && method_name in ["oauth_session_status", "oauth_api_callback", "login", "device_login", "refresh_token", "oauth_callback_api_apple_ios"]:
		data = data.bzz_normalize().get("data").bzz_normalize()
		if data.get("access_token"):
			_access_token = data["access_token"]
		if data.get("refresh_token"):
			_refresh_token = data["refresh_token"]
		if data.get("expires_in"):
			_expires_at_ms = Time.get_ticks_msec() + data.get("expires_in") * 1000
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
	_realtime.channel_event.connect(_on_channel_event)
	add_child(_realtime)
	return await result.finished

func realtime_stop():
	if _realtime:
		_realtime.queue_free()
	_realtime = null

func listen_to_user():
	_realtime.add_channel("user:" + str(int(_user_id)))

func liste_to_lobby():
	_realtime.add_channel("lobby:" + str(int(_lobby_id)))

func _on_channel_event(event: String, payload: Dictionary, status, topic: String):
	if topic.begins_with("user") && event == "updated":
		var lobby_id = payload.get("lobby_id")
		# Listen to the lobby
		if _lobby_id != lobby_id && lobby_id != -1:
			_lobby_id = lobby_id
			liste_to_lobby()
		_lobby_id = lobby_id
		user_updated.emit(payload)
	if topic.begins_with("lobby") && event == "updated":
		lobby_updated.emit(payload)
	if topic.begins_with("user") && event == "notification":
		notification_emitted.emit(payload)
		
## Authorize with access token
func authorize():
	_config.headers_base["Authorization"] = "Bearer " + _access_token

### HEALTH

## Health check
func health_index() -> GamendResult:
	return await _call_api(HealthApi.new(_config), "index")

### HOOKS

## Invoke a hook function
func hooks_call_hook(hook_request: CallHookRequest) -> GamendResult:
	return await _call_api(HooksApi.new(_config), "call_hook", [hook_request])

## List available hook functions
func hooks_list_hooks() -> GamendResult:
	return await _call_api(HooksApi.new(_config), "list_hooks", [])

### USERS

## Delete current user
func user_delete_current_user() -> GamendResult:
	return await _call_api(UsersApi.new(_config), "delete_current_user")

## Get current user info
func users_get_current_user() -> GamendResult:
	return await _call_api(UsersApi.new(_config), "get_current_user")

## Update current user's display name
func user_update_current_user_display_name(display_name: String) -> GamendResult:
	var request := UpdateCurrentUserDisplayNameRequest.new()
	request.display_name = display_name
	return await _call_api(UsersApi.new(_config), "update_current_user_display_name", [request])

## Update current user's password
func user_update_current_user_password(password: String) -> GamendResult:
	return await _call_api(UsersApi.new(_config), "update_current_user_password", [password])

## Search users by id/email/display_name
func users_search_users(query = "", page = 1, pageSize = 25) -> GamendResult:
	return await _call_api(UsersApi.new(_config), "search_users", [query, page, pageSize])

## Get a user by id
func users_get_user(id: String) -> GamendResult:
	return await _call_api(UsersApi.new(_config), "get_user", [id])


### AUTHENTICATION

## Get OAuth session status
func authenticate_oauth_session_status(session_id: String) -> GamendResult:
	return await _call_api(AuthenticationApi.new(_config), "oauth_session_status", [session_id])

## Initiate API OAuth
func authenticate_oauth_request(provider: String) -> GamendResult:
	return await _call_api(AuthenticationApi.new(_config), "oauth_request", [provider])

## API Callback / Code Exchange
func authenticate_oauth_api_callback(provider: String, callback_request: OauthApiCallbackRequest) -> GamendResult:
	return await _call_api(AuthenticationApi.new(_config), "oauth_api_callback", [provider, callback_request])

## Apple Callback (native iOS)
func authenticate_oauth_callback_api_apple_ios(ios_request: OauthCallbackApiAppleIosRequest) -> GamendResult:
	return await _call_api(AuthenticationApi.new(_config), "oauth_callback_api_apple_ios", [ios_request])

## Login
func authenticate_login(login_request: LoginRequest) -> GamendResult:
	return await _call_api(AuthenticationApi.new(_config), "login", [login_request])

## Device login
func authenticate_device_login(device_id: String) -> GamendResult:
	var device_login := DeviceLoginRequest.new()
	device_login.device_id = device_id
	return await _call_api(AuthenticationApi.new(_config), "device_login", [device_login])

## Logout
func authenticate_logout() -> GamendResult:
	return await _call_api(AuthenticationApi.new(_config), "logout")

## Unlink OAuth provider
func authenticate_unlink_provider(provider: String) -> GamendResult:
	return await _call_api(AuthenticationApi.new(_config), "unlink_provider", [provider])

## Unlink device
func authenticate_unlink_device() -> GamendResult:
	return await _call_api(AuthenticationApi.new(_config), "unlink_device", [])

## Link device
func authenticate_link_device(device_id: String) -> GamendResult:
	var linkDeviceRequest:= LinkDeviceRequest.new()
	linkDeviceRequest.device_id = device_id
	return await _call_api(AuthenticationApi.new(_config), "link_device", [linkDeviceRequest])

## Refresh access token
func authenticate_refresh_token(refresh_token: String) -> GamendResult:
	var refresh_param:= RefreshTokenRequest.new()
	refresh_param.refresh_token = refresh_token
	return await _call_api(AuthenticationApi.new(_config), "refresh_token", [refresh_param])

### FRIENDS

## Send a friend request
func friends_create_friend_request(friend_request: CreateFriendRequestRequest) -> GamendResult:
	return await _call_api(FriendsApi.new(_config), "create_friend_request", [friend_request])

## Remove/cancel a friendship or request
func friends_remove_friendship(id: int) -> GamendResult:
	return await _call_api(FriendsApi.new(_config), "remove_friendship", [id])

## Accept a friend request
func friends_accept_friend_request(id: int) -> GamendResult:
	return await _call_api(FriendsApi.new(_config), "accept_friend_request", [id])

## Block a friend request / user
func friends_block_friend_request(id: int) -> GamendResult:
	return await _call_api(FriendsApi.new(_config), "block_friend_request", [id])

## Reject a friend request
func friends_reject_friend_request(id: int) -> GamendResult:
	return await _call_api(FriendsApi.new(_config), "reject_friend_request", [id])

## Unblock a previously-blocked friendship
func friends_unblock_friend(id: int) -> GamendResult:
	return await _call_api(FriendsApi.new(_config), "unblock_friend", [id])

## List users you've blocked
func friends_list_blocked_friends(page = 1, page_size = 25) -> GamendResult:
	return await _call_api(FriendsApi.new(_config), "list_blocked_friends", [page, page_size])

## List pending friend requests (incoming and outgoing)
func friends_list_friend_requests(page = 1, page_size = 25) -> GamendResult:
	return await _call_api(FriendsApi.new(_config), "list_friend_requests", [page, page_size])

## List current user's friends (returns a paginated set of user objects)
func friends_list_friends(page = 1, page_size = 25) -> GamendResult:
	return await _call_api(FriendsApi.new(_config), "list_friends", [page, page_size])

### LOBBIES

## List lobbies

func lobbies_list_lobbies(
	title = "",
	isPassworded = null,
	isLocked = null,
	minUsers = null,
	maxUsers = null,
	page = null,
	pageSize = null,
	metadataKey = "",
	metadataValue = "") -> GamendResult:
	return await _call_api(LobbiesApi.new(_config), "list_lobbies", [title, isPassworded, isLocked, minUsers, maxUsers, page, pageSize, metadataKey, metadataValue])

## Update lobby (host only)
func lobbies_update_lobby(update_request: UpdateLobbyRequest) -> GamendResult:
	return await _call_api(LobbiesApi.new(_config), "update_lobby", [update_request])

## Create a lobby
func lobbies_create_lobby(create_request: CreateLobbyRequest) -> GamendResult:
	return await _call_api(LobbiesApi.new(_config), "create_lobby", [create_request])

## Kick a user from the lobby (host only)
func lobbies_kick_user(kick_request: KickUserRequest) -> GamendResult:
	return await _call_api(LobbiesApi.new(_config), "kick_user", [kick_request])

## Leave the current lobby
func lobbies_leave_lobby() -> GamendResult:
	return await _call_api(LobbiesApi.new(_config), "leave_lobby")

## Quick-join or create a lobby
func lobbies_quick_join(quick_request: QuickJoinRequest) -> GamendResult:
	return await _call_api(LobbiesApi.new(_config), "quick_join", [quick_request])

## Join a lobby
func lobbies_join_lobby(id: int, join_request: JoinLobbyRequest = null) -> GamendResult:
	return await _call_api(LobbiesApi.new(_config), "join_lobby", [id, join_request])

### LEADERBOARDS

## List leaderboard records
func leaderboards_list_leaderboard_records(id: int, page = 1, page_size = 25) -> GamendResult:
	return await _call_api(LeaderboardsApi.new(_config), "list_leaderboard_records", [id, page, page_size])

## List leaderboards
func leaderboards_list_leaderboards(slug = "", active = null, orderBy = "ends_at", startsAfter = null, startsBefore = null, endsAfter = null, endsBefore = null, page = 1, pageSize = 25) -> GamendResult:
	return await _call_api(LeaderboardsApi.new(_config), "list_leaderboards", [slug, active, orderBy, startsAfter, startsBefore, endsAfter, endsBefore, page, pageSize])

## Get current user's record
func leaderboards_get_my_record(id: int) -> GamendResult:
	return await _call_api(LeaderboardsApi.new(_config), "get_my_record", [id])

## List records around a user
func leaderboards_list_records_around_user(id: int, user_id: int, limit = 11) -> GamendResult:
	return await _call_api(LeaderboardsApi.new(_config), "list_records_around_user", [id, user_id, limit])

## KV

## Get a key/value entry 
func kv_get_kv(key: String, user_id = null, lobby_id = null) -> GamendResult:
	return await _call_api(KVApi.new(_config), "get_kv", [key, user_id, lobby_id])

## NOTIFICATIONS

## Delete notifications by IDs
func notifications_delete_notifications(deleteNotificationsRequest: DeleteNotificationsRequest) -> GamendResult:
	return await _call_api(NotificationsApi.new(_config), "delete_notifications", [deleteNotificationsRequest])

## List own notifications
func notifications_list_notifications(
	# page: int   Eg: 56
	# Page number (1-based)
	page = null,
	# pageSize: int   Eg: 56
	# Page size (max results per page)
	pageSize = null) -> GamendResult:
	return await _call_api(NotificationsApi.new(_config), "list_notifications", [page, pageSize])

## Send a notification to a friend
func notifications_send_notification(sendNotificationRequest: SendNotificationRequest) -> GamendResult:
	return await _call_api(NotificationsApi.new(_config), "send_notification", [sendNotificationRequest])

## GROUPS

## Accept a group invitation
func groups_accept_group_invite(id: int):
	return await _call_api(GroupsApi.new(_config), "accept_group_invite", [id])

## Approve a join request (admin only)
func groups_approve_join_request(
	# id: int   Eg: 56
	# Group ID
	id: int,
	# requestId: int   Eg: 56
	# Join request ID
	requestId: int,):
	return await _call_api(GroupsApi.new(_config), "approve_join_request", [id, requestId])

## Cancel a sent group invitation
func groups_cancel_group_invite(inviteId: int):
	return await _call_api(GroupsApi.new(_config), "cancel_group_invite", [inviteId])

## Cancel your own pending join request
func groups_cancel_join_request(
	# id: int   Eg: 56
	# Group ID
	id: int,
	# requestId: int   Eg: 56
	# Join request ID
	requestId: int,):
	return await _call_api(GroupsApi.new(_config), "cancel_join_request", [id, requestId])

## Create a group
func groups_create_group(createGroupRequest: CreateGroupRequest):
	return await _call_api(GroupsApi.new(_config), "create_group", [createGroupRequest])

## Demote admin to member
func groups_demote_group_member(
	# id: int   Eg: 56
	# Group ID
	id: int,
	# demoteGroupMemberRequest: DemoteGroupMemberRequest
	# Demote parameters
	demoteGroupMemberRequest: DemoteGroupMemberRequest,):
	return await _call_api(GroupsApi.new(_config), "demote_group_member", [id, demoteGroupMemberRequest])

## Get group details
func groups_get_group(
	# id: int   Eg: 56
	# Group ID
	id: int,):
	return await _call_api(GroupsApi.new(_config), "get_group", [id])

## Invite a user to a hidden group (admin only)
func groups_invite_to_group(
	# id: int   Eg: 56
	# Group ID
	id: int,
	inviteToGroupRequest: InviteToGroupRequest):
	return await _call_api(GroupsApi.new(_config), "invite_to_group", [id, inviteToGroupRequest])

## Join a group
func groups_join_group(
	# id: int   Eg: 56
	# Group ID
	id: int,):
	return await _call_api(GroupsApi.new(_config), "join_group", [id])

## Kick a member (admin only)
func groups_kick_group_member(
	# id: int   Eg: 56
	# Group ID
	id: int,
	kickGroupMemberRequest: KickGroupMemberRequest):
	return await _call_api(GroupsApi.new(_config), "kick_group_member", [id, kickGroupMemberRequest])

## Leave a group
func groups_leave_group(
	# id: int   Eg: 56
	# Group ID
	id: int,):
	return await _call_api(GroupsApi.new(_config), "leave_group", [id])

## List my group invitations
func groups_list_group_invitations(
	# page: int   Eg: 56
	# Page number (default: 1)
	page = null,
	# pageSize: int   Eg: 56
	# Items per page (default: 25)
	pageSize = null,):
	return await _call_api(GroupsApi.new(_config), "list_group_invitations", [page, pageSize])

## List group members
func groups_list_group_members(
	# id: int   Eg: 56
	# Group ID
	id: int,
	# page: int   Eg: 56
	# Page number (default: 1)
	page = null,
	# pageSize: int   Eg: 56
	# Items per page (default: 25)
	pageSize = null,):
	return await _call_api(GroupsApi.new(_config), "list_group_members", [id, page, pageSize])

## List groups
func groups_list_groups(
	# title: String = ""   Eg: title_example
	# Search by title (prefix)
	title = "",
	# type: String = ""   Eg: type_example
	# Filter by group type
	type = "",
	# minMembers: int   Eg: 56
	# Minimum max_members to include
	minMembers = null,
	# maxMembers: int   Eg: 56
	# Maximum max_members to include
	maxMembers = null,
	# metadataKey: String = ""   Eg: metadataKey_example
	# Metadata key to filter by
	metadataKey = "",
	# metadataValue: String = ""   Eg: metadataValue_example
	# Metadata value to match (with metadata_key)
	metadataValue = "",
	# page: int   Eg: 56
	# Page number
	page = null,
	# pageSize: int   Eg: 56
	# Page size
	pageSize = null,):
	return await _call_api(GroupsApi.new(_config), "list_groups", [title, type, minMembers, maxMembers, metadataKey, metadataValue, page, pageSize])

## List pending join requests (admin only)
func groups_list_join_requests(
	# id: int   Eg: 56
	# Group ID
	id: int,
	# page: int   Eg: 56
	# Page number
	page = null,
	# pageSize: int   Eg: 56
	# Page size
	pageSize = null,):
	return await _call_api(GroupsApi.new(_config), "list_join_requests", [id, page, pageSize])

## List groups I belong to
func groups_list_my_groups(
	# page: int   Eg: 56
	# Page number (default: 1)
	page = null,
	# pageSize: int   Eg: 56
	# Items per page (default: 25)
	pageSize = null,):
	return await _call_api(GroupsApi.new(_config), "list_my_groups", [page, pageSize])

## List group invitations I have sent
func groups_list_sent_invitations(
	# page: int   Eg: 56
	# Page number (default: 1)
	page = null,
	# pageSize: int   Eg: 56
	# Items per page (default: 25)
	pageSize = null,):
	return await _call_api(GroupsApi.new(_config), "list_sent_invitations", [page, pageSize])

## Send a notification to all group members
func groups_notify_group(
	# id: int   Eg: 56
	# Group ID
	id: int,
	notifyGroupRequest: NotifyGroupRequest):
	return await _call_api(GroupsApi.new(_config), "notify_group", [id, notifyGroupRequest])

## Promote member to admin
func groups_promote_group_member(
	# id: int   Eg: 56
	# Group ID
	id: int,
	promoteGroupMemberRequest: PromoteGroupMemberRequest):
	return await _call_api(GroupsApi.new(_config), "promote_group_member", [id, promoteGroupMemberRequest])

## Reject a join request (admin only)
func groups_reject_join_request(
	# id: int   Eg: 56
	# Group ID
	id: int,
	# requestId: int   Eg: 56
	# Join request ID
	requestId: int,):
	return await _call_api(GroupsApi.new(_config), "reject_join_request", [id, requestId])

## Update a group (admin only)
func groups_update_group(
	# id: int   Eg: 56
	# Group ID
	id: int,
	updateGroupRequest: UpdateGroupRequest):
	return await _call_api(GroupsApi.new(_config), "update_group", [id, updateGroupRequest])

## ADMIN SESSIONS

# Delete session token by id (admin)
func admin_sessions_admin_delete_session(id: int) -> GamendResult:
	return await _call_api(AdminSessionsApi.new(_config), "admin_delete_session", [id])

## List sessions (admin)
func admin_sessions_admin_list_sessions(page = 1, page_size = 25) -> GamendResult:
	return await _call_api(AdminSessionsApi.new(_config), "admin_list_sessions", [page, page_size])

## Delete all session tokens for a user (admin)
func admin_sessions_admin_delete_user_sessions(user_id) -> GamendResult:
	return await _call_api(AdminSessionsApi.new(_config), "admin_delete_user_sessions", [user_id])

## ADMIN USERS

# Delete user (admin)
func admin_users_admin_delete_user(id: int) -> GamendResult:
	return await _call_api(AdminUsersApi.new(_config), "admin_delete_user", [id])
	
# Update user (admin)
func admin_users_admin_update_user(id: int, admin_update_user_request: AdminUpdateUserRequest) -> GamendResult:
	return await _call_api(AdminUsersApi.new(_config), "admin_update_user", [id, admin_update_user_request])

## ADMIN LOBBIES

# List all lobbies (admin)
func admin_lobbies_admin_list_lobbies(title = "", isHidden = null, isLocked = null, hasPassword = null, minUsers = null, maxUsers = null, page = 1, pageSize = 25) -> GamendResult:
	return await _call_api(AdminLobbiesApi.new(_config), "admin_list_lobbies", [title, isHidden, isLocked, hasPassword, minUsers, maxUsers, page, pageSize])

# Delete lobby (admin)
func admin_lobbies_admin_delete_lobby(id: int) -> GamendResult:
	return await _call_api(AdminLobbiesApi.new(_config), "admin_delete_lobby", [id])

# Update lobby (admin)
func admin_lobbies_admin_update_lobby(id: int, adminUpdateLobbyRequest: AdminUpdateLobbyRequest) -> GamendResult:
	return await _call_api(AdminLobbiesApi.new(_config), "admin_update_lobby", [id, adminUpdateLobbyRequest])

## ADMIN LEADERBOARDS

## End leaderboard (admin)
func admin_leaderboards_admin_end_leaderboard(id: int) -> GamendResult:
	return await _call_api(AdminLeaderboardsApi.new(_config), "admin_end_leaderboard", [id])

## Submit score (admin)
func admin_leaderboards_admin_submit_leaderboard_score(id: int, adminSubmitLeaderboardScoreRequest: AdminSubmitLeaderboardScoreRequest) -> GamendResult:
	return await _call_api(AdminLeaderboardsApi.new(_config), "admin_submit_leaderboard_score", [id, adminSubmitLeaderboardScoreRequest])

## Delete leaderboard record (admin)
func admin_leaderboards_admin_delete_leaderboard_record(id: int, recordId: int) -> GamendResult:
	return await _call_api(AdminLeaderboardsApi.new(_config), "admin_delete_leaderboard_record", [id, recordId])

## Update leaderboard record (admin)
func admin_leaderboards_admin_update_leaderboard_record(id: int, recordId: int, adminUpdateLeaderboardRecordRequest: AdminUpdateLeaderboardRecordRequest) -> GamendResult:
	return await _call_api(AdminLeaderboardsApi.new(_config), "admin_update_leaderboard_record", [id, recordId, adminUpdateLeaderboardRecordRequest])

## Create leaderboard (admin)
func admin_leaderboards_admin_create_leaderboard(adminCreateLeaderboardRequest: AdminCreateLeaderboardRequest) -> GamendResult:
	return await _call_api(AdminLeaderboardsApi.new(_config), "admin_create_leaderboard", [adminCreateLeaderboardRequest])

## Delete a user's record (admin)
func admin_leaderboards_admin_delete_leaderboard_user_record(id: int, userId: int) -> GamendResult:
	return await _call_api(AdminLeaderboardsApi.new(_config), "admin_delete_leaderboard_user_record", [id, userId])
	
## Delete leaderboard (admin)
func admin_leaderboards_admin_delete_leaderboard(id: int) -> GamendResult:
	return await _call_api(AdminLeaderboardsApi.new(_config), "admin_delete_leaderboard", [id])

## Update leaderboard (admin)
func admin_leaderboards_admin_update_leaderboard(id: int, adminUpdateLeaderboardRequest: AdminUpdateLeaderboardRequest) -> GamendResult:
	return await _call_api(AdminLeaderboardsApi.new(_config), "admin_update_leaderboard", [id, adminUpdateLeaderboardRequest])

## ADMIN KV

## List KV entries (admin)
func admin_kv_admin_list_kv_entries(page = 1, pageSize = 25, key = "", userId = null, lobbyId = null, globalOnly = null) -> GamendResult:
	return await _call_api(AdminKVApi.new(_config), "admin_list_kv_entries", [page, pageSize, key, userId, lobbyId, globalOnly])

## Create KV entry (admin)
func admin_kv_admin_create_kv_entry(adminCreateKvEntryRequest: AdminCreateKvEntryRequest) -> GamendResult:
	return await _call_api(AdminKVApi.new(_config), "admin_create_kv_entry", [adminCreateKvEntryRequest])

## Delete KV entry by id (admin)
func admin_kv_admin_delete_kv_entry(id: int) -> GamendResult:
	return await _call_api(AdminKVApi.new(_config), "admin_delete_kv_entry", [id])

## Update KV entry by id (admin)
func admin_kv_admin_update_kv_entry(id: int, adminUpdateKvEntryRequest: AdminUpdateKvEntryRequest) -> GamendResult:
	return await _call_api(AdminKVApi.new(_config), "admin_update_kv_entry", [id, adminUpdateKvEntryRequest])

## Delete KV by key (admin)
func admin_kv_admin_delete_kv(key: String, user_id = null, lobby_id = null) -> GamendResult:
	return await _call_api(AdminKVApi.new(_config), "admin_delete_kv", [key, user_id, lobby_id])

## Upsert KV by key (admin)
func admin_kv_admin_upsert_kv(adminCreateKvEntryRequest: AdminCreateKvEntryRequest) -> GamendResult:
	return await _call_api(AdminKVApi.new(_config), "admin_upsert_kv", [adminCreateKvEntryRequest])

## ADMIN NOTIFICATIONS

## Create a notification (admin)
func admin_notifications_admin_create_notification(adminCreateNotificationRequest: AdminCreateNotificationRequest) -> GamendResult:
	return await _call_api(AdminNotificationsApi.new(_config), "admin_create_notification", [adminCreateNotificationRequest])

## Delete a notification (admin)
func admin_notifications_admin_delete_notification(id: int) -> GamendResult:
	return await _call_api(AdminNotificationsApi.new(_config), "admin_delete_notification", [id])

## List all notifications (admin)
func admin_notifications_admin_list_notifications(
	# userId: int   Eg: 56
	# Filter by recipient user ID
	userId = null,
	# senderId: int   Eg: 56
	# Filter by sender user ID
	senderId = null,
	# title: String = ""   Eg: title_example
	# Filter by title (partial match)
	title = "",
	# page: int   Eg: 56
	# Page number (1-based)
	page = null,
	# pageSize: int   Eg: 56
	# Page size
	pageSize = null,) -> GamendResult:
	return await _call_api(AdminNotificationsApi.new(_config), "admin_list_notifications", [userId, senderId, title, page, pageSize])

## ADMIN GROUPS

## Delete a group (admin)
func admin_groups_admin_delete_group(id: int) -> GamendResult:
	return await _call_api(AdminGroupsApi.new(_config), "admin_delete_group", [id])

## Update a group (admin)
func admin_groups_admin_update_group(id: int, adminUpdateGroupRequest: AdminUpdateGroupRequest) -> GamendResult:
	return await _call_api(AdminGroupsApi.new(_config), "admin_update_group", [id, adminUpdateGroupRequest])

## List all groups (admin)
func admin_groups_admin_list_groups(
	# title: String = ""   Eg: title_example
	title = "",
	# type: String = ""   Eg: type_example
	type = "",
	# minMembers: int   Eg: 56
	minMembers = null,
	# maxMembers: int   Eg: 56
	maxMembers = null,
	# sortBy: String = ""   Eg: sortBy_example
	sortBy = "",
	# page: int   Eg: 56
	page = null,
	# pageSize: int   Eg: 56
	pageSize = null,) -> GamendResult:
	return await _call_api(AdminGroupsApi.new(_config), "admin_list_groups", [title, type, minMembers, maxMembers, sortBy, page, pageSize])
