/**
 * GameRealtime — Phoenix WebSocket client for game_server.
 *
 * Wraps Phoenix.Socket to provide helpers for common game_server channel topics.
 * The `phoenix` npm package is included as a dependency.
 *
 * Usage (browser / Node.js with bundler):
 *
 *   import { GameRealtime } from '@ughuuu/game_server'
 *
 *   const realtime = new GameRealtime('https://your-server.com', accessToken)
 *
 *   // Join the authenticated user channel
 *   const userChannel = realtime.joinUserChannel(userId)
 *   userChannel.on('notification', (payload) => console.log('notification:', payload))
 *   userChannel.on('updated', (payload) => console.log('user updated:', payload))
 *
 *   // Join a lobby channel
 *   const lobbyChannel = realtime.joinLobbyChannel(lobbyId)
 *   lobbyChannel.on('updated', (payload) => console.log('lobby event:', payload))
 *
 *   realtime.disconnect()
 *
 * Dependency: `phoenix` (bundled with @ughuuu/game_server)
 */

import { Socket } from 'phoenix'

export class GameRealtime {
  /**
   * @param {string} serverUrl  - Base HTTP(S) or WS(S) server URL,
   *                              e.g. "https://game.example.com" or "wss://game.example.com"
   * @param {string} token      - JWT access token from the REST login endpoints
   * @param {Object} socketOpts - Optional Phoenix.Socket constructor options
   */
  constructor(serverUrl, token, socketOpts = {}) {
    // Normalise URL: strip trailing slash, ensure ws(s):// scheme, append /socket
    const wsUrl =
      serverUrl
        .replace(/\/$/, '')
        .replace(/^http(s?):\/\//, (_m, s) => `ws${s}://`) + '/socket'

    this._token = token
    this._socket = new Socket(wsUrl, { params: { token }, ...socketOpts })
    this._socket.connect()
    /** @type {Map<string, Object>} topic → Phoenix Channel */
    this._channels = new Map()
  }

  // ── Channel helpers ──────────────────────────────────────────────────────

  /**
   * Join the user channel for notifications, presence, and real-time events.
   * Topic: `"user:<userId>"`
   * @param {string|number} userId
   * @param {Object} params - Extra join params merged with the auth token
   * @returns {Object} Phoenix Channel
   */
  joinUserChannel(userId, params = {}) {
    return this._join(`user:${userId}`, params)
  }

  /**
   * Join a lobby channel for in-lobby events (member joins/leaves, updates).
   * Topic: `"lobby:<lobbyId>"`
   * @param {string|number} lobbyId
   * @param {Object} params
   * @returns {Object} Phoenix Channel
   */
  joinLobbyChannel(lobbyId, params = {}) {
    return this._join(`lobby:${lobbyId}`, params)
  }

  /**
   * Join the global lobbies feed (lobby list changes).
   * Topic: `"lobbies"`
   * @param {Object} params
   * @returns {Object} Phoenix Channel
   */
  joinLobbiesChannel(params = {}) {
    return this._join('lobbies', params)
  }

  /**
   * Join a group channel for group events.
   * Topic: `"group:<groupId>"`
   * @param {string|number} groupId
   * @param {Object} params
   * @returns {Object} Phoenix Channel
   */
  joinGroupChannel(groupId, params = {}) {
    return this._join(`group:${groupId}`, params)
  }

  /**
   * Join the global groups feed.
   * Topic: `"groups"`
   * @param {Object} params
   * @returns {Object} Phoenix Channel
   */
  joinGroupsChannel(params = {}) {
    return this._join('groups', params)
  }

  /**
   * Join a party channel for party events.
   * Topic: `"party:<partyId>"`
   * @param {string|number} partyId
   * @param {Object} params
   * @returns {Object} Phoenix Channel
   */
  joinPartyChannel(partyId, params = {}) {
    return this._join(`party:${partyId}`, params)
  }

  /**
   * Join an arbitrary channel topic.
   * @param {string} topic  - Full Phoenix channel topic string
   * @param {Object} params - Join params merged with the auth token
   * @returns {Object} Phoenix Channel
   */
  joinChannel(topic, params = {}) {
    return this._join(topic, params)
  }

  /**
   * Leave and remove a channel by topic.
   * @param {string} topic
   */
  leaveChannel(topic) {
    const ch = this._channels.get(topic)
    if (ch) {
      ch.leave()
      this._channels.delete(topic)
    }
  }

  /**
   * Retrieve an already-joined channel by topic.
   * @param {string} topic
   * @returns {Object|undefined} Phoenix Channel or undefined if not joined
   */
  channel(topic) {
    return this._channels.get(topic)
  }

  /**
   * Access the underlying Phoenix.Socket instance.
   * @returns {Object}
   */
  get socket() {
    return this._socket
  }

  /**
   * Disconnect the socket and leave all channels.
   */
  disconnect() {
    this._channels.forEach((ch) => { try { ch.leave() } catch (_) {} })
    this._channels.clear()
    this._socket.disconnect()
  }

  // ── Private ────────────────────────────────────────────────────────────────

  _join(topic, extraParams = {}) {
    if (this._channels.has(topic)) {
      return this._channels.get(topic)
    }
    const ch = this._socket.channel(topic, { token: this._token, ...extraParams })
    ch.join()
      .receive('error', (err) =>
        console.error(`GameRealtime: failed to join channel "${topic}"`, err)
      )
    this._channels.set(topic, ch)
    return ch
  }
}

export default GameRealtime
