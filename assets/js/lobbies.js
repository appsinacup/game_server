import {Socket} from "phoenix"

let _token = null
let _socket = null

export function setAuthToken(token) {
  _token = token
  // if a socket exists, disconnect and re-create with the new token
  if (_socket) {
    try { _socket.disconnect() } catch(e) {}
    _socket = null
  }
}

export function _ensureSocket() {
  if (!_socket) {
    const params = _token ? {token: _token} : {}
    _socket = new Socket('/socket', {params})
    _socket.connect()
  }
  return _socket
}

export async function apiRequest(method, path, body) {
  const headers = { 'Content-Type': 'application/json' }
  if (_token) headers['Authorization'] = `Bearer ${_token}`

  const res = await fetch(path, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
    credentials: 'same-origin'
  })

  if (!res.ok) {
    const err = await res.json().catch(() => ({error: 'unexpected'}))
    throw { status: res.status, body: err }
  }

  return res.json()
}

// API helpers
export function listLobbies(q = null, page = 1, page_size = 25) {
  const params = new URLSearchParams()
  if (q) params.set('q', q)
  if (page) params.set('page', String(page))
  if (page_size) params.set('page_size', String(page_size))
  return apiRequest('GET', `/api/v1/lobbies?${params.toString()}`)
}

export function createLobby(attrs = {}) {
  return apiRequest('POST', `/api/v1/lobbies`, attrs)
}

export function joinLobby(lobbyId, opts = {}) {
  return apiRequest('POST', `/api/v1/lobbies/${lobbyId}/join`, opts)
}

export function leaveLobby(lobbyId) {
  return apiRequest('POST', `/api/v1/lobbies/${lobbyId}/leave`, {})
}

export function updateLobby(lobbyId, attrs) {
  return apiRequest('PATCH', `/api/v1/lobbies/${lobbyId}`, attrs)
}

export function kickUser(lobbyId, targetUserId) {
  return apiRequest('POST', `/api/v1/lobbies/${lobbyId}/kick`, {target_user_id: targetUserId})
}

// Channels: create/join lobby channel
export function joinLobbyChannel(lobbyId, handlers = {}) {
  const socket = _ensureSocket()
  const channel = socket.channel(`lobby:${lobbyId}`, {})

  if (handlers.onMessage) channel.on('event', handlers.onMessage)
  if (handlers.onClose) socket.onClose(handlers.onClose)

  return new Promise((resolve, reject) => {
    channel.join()
      .receive('ok', resp => resolve({channel, resp}))
      .receive('error', resp => reject(resp))
  })
}

export default {
  setAuthToken,
  listLobbies,
  createLobby,
  joinLobby,
  leaveLobby,
  updateLobby,
  kickUser,
  joinLobbyChannel,
}
