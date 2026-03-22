/**
 * GameWebRTC — Browser WebRTC DataChannel client for game_server.
 *
 * Uses an existing Phoenix channel (e.g. from GameRealtime.joinUserChannel)
 * for SDP/ICE signaling. Once connected, named DataChannels carry game data
 * alongside the WebSocket at lower latency.
 *
 * Requires a browser with native WebRTC support (RTCPeerConnection).
 * Does NOT work in Node.js without a WebRTC polyfill.
 *
 * Usage:
 *
 *   import { GameRealtime, GameWebRTC } from '@ughuuu/game_server'
 *
 *   const realtime = new GameRealtime('https://your-server.com', token)
 *   const userChannel = realtime.joinUserChannel(userId)
 *
 *   const webrtc = new GameWebRTC(userChannel, {
 *     dataChannels: [
 *       { label: 'events', ordered: true },
 *       { label: 'state',  ordered: false, maxRetransmits: 0 },
 *     ],
 *     onData:         (label, data)  => console.log('data', label, data),
 *     onChannelOpen:  (label)        => console.log('channel open', label),
 *     onChannelClose: (label)        => console.log('channel close', label),
 *     onStateChange:  (state)        => console.log('state', state),
 *   })
 *
 *   await webrtc.connect()
 *   webrtc.send('events', JSON.stringify({ type: 'player_move', x: 10, y: 20 }))
 *   webrtc.close()
 */

/**
 * Default DataChannel definitions.
 * - "events": reliable, ordered — important game events
 * - "state":  unreliable, unordered — high-frequency position/state sync
 */
const DEFAULT_DATA_CHANNELS = [
  { label: 'events', ordered: true },
  { label: 'state',  ordered: false, maxRetransmits: 0 },
]

const DEFAULT_ICE_SERVERS = [
  { urls: 'stun:stun.l.google.com:19302' },
]

export class GameWebRTC {
  /**
   * @param {Object} channel — A joined Phoenix channel (e.g. from GameRealtime.joinUserChannel)
   * @param {Object} opts
   * @param {Array}    opts.dataChannels   — Array of {label, ordered, maxRetransmits?} definitions
   * @param {Array}    opts.iceServers     — RTCIceServer configs (default: Google STUN)
   * @param {Function} opts.onData        — (label: string, data: ArrayBuffer|string) => void
   * @param {Function} opts.onChannelOpen  — (label: string) => void
   * @param {Function} opts.onChannelClose — (label: string) => void
   * @param {Function} opts.onStateChange  — (state: string) => void
   * @param {Function} opts.onError        — (error: Error) => void
   */
  constructor(channel, opts = {}) {
    this.channel = channel
    this.opts = opts
    this.iceServers = opts.iceServers || DEFAULT_ICE_SERVERS
    this.dataChannelDefs = opts.dataChannels || DEFAULT_DATA_CHANNELS

    /** @type {RTCPeerConnection|null} */
    this.pc = null
    /** @type {Map<string, RTCDataChannel>} label → RTCDataChannel */
    this.channels = new Map()
    /** @type {string} */
    this.connectionState = 'new'

    this._resolveConnect = null
    this._rejectConnect = null

    this._setupChannelListeners()
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /**
   * Initiate the WebRTC connection.
   * Creates an RTCPeerConnection, opens DataChannels, sends an SDP offer
   * over the Phoenix channel, and exchanges ICE candidates.
   *
   * @returns {Promise<void>} Resolves when at least one DataChannel is open.
   */
  async connect() {
    this.pc = new RTCPeerConnection({ iceServers: this.iceServers })

    this.pc.onicecandidate = (event) => this._onIceCandidate(event)
    this.pc.onconnectionstatechange = () => this._onConnectionStateChange()

    // Create DataChannels on the client side (client-initiated)
    for (const def of this.dataChannelDefs) {
      const dcOpts = { ordered: def.ordered !== false }
      if (def.maxRetransmits !== undefined) dcOpts.maxRetransmits = def.maxRetransmits
      if (def.maxPacketLifeTime !== undefined) dcOpts.maxPacketLifeTime = def.maxPacketLifeTime

      const dc = this.pc.createDataChannel(def.label, dcOpts)
      this._wireDataChannel(dc)
      this.channels.set(def.label, dc)
    }

    // Create and send SDP offer
    const offer = await this.pc.createOffer()
    await this.pc.setLocalDescription(offer)

    return new Promise((resolve, reject) => {
      this.channel
        .push('webrtc:offer', { sdp: offer.sdp, type: offer.type })
        .receive('ok', () => {
          // Offer accepted — wait for webrtc:answer from server
          this._resolveConnect = resolve
          this._rejectConnect = reject
        })
        .receive('error', (resp) => {
          reject(new Error(resp.error || 'webrtc:offer rejected'))
        })

      // Timeout after 15 seconds
      setTimeout(() => {
        if (this._resolveConnect) {
          this._resolveConnect = null
          reject(new Error('WebRTC connection timed out'))
        }
      }, 15000)
    })
  }

  /**
   * Send data over a named DataChannel.
   * @param {string} label — channel label (e.g. "events" or "state")
   * @param {string|ArrayBuffer|Blob} data
   * @returns {boolean} true if sent, false if channel is not open
   */
  send(label, data) {
    const dc = this.channels.get(label)
    if (!dc || dc.readyState !== 'open') return false
    dc.send(data)
    return true
  }

  /**
   * Check if a specific DataChannel is open.
   * @param {string} label
   * @returns {boolean}
   */
  isChannelOpen(label) {
    const dc = this.channels.get(label)
    return dc ? dc.readyState === 'open' : false
  }

  /**
   * Check if the WebRTC connection is active.
   * @returns {boolean}
   */
  isConnected() {
    return this.pc != null && this.connectionState === 'connected'
  }

  /**
   * Close the WebRTC connection and all DataChannels.
   * Notifies the server via the Phoenix channel.
   */
  close() {
    this._removeChannelListeners()

    // Close all DataChannels
    for (const dc of this.channels.values()) {
      try { dc.close() } catch (_) {}
    }
    this.channels.clear()

    // Close PeerConnection
    if (this.pc) {
      try { this.pc.close() } catch (_) {}
      this.pc = null
    }

    // Notify server
    this.channel.push('webrtc:close', {})
    this.connectionState = 'closed'
  }

  // ── Private: signaling channel listeners ──────────────────────────────────

  _setupChannelListeners() {
    // Server sends SDP answer
    this._answerRef = this.channel.on('webrtc:answer', (payload) => {
      if (this.pc) {
        this.pc.setRemoteDescription(
          new RTCSessionDescription({ sdp: payload.sdp, type: payload.type })
        )
      }
    })

    // Server sends ICE candidate
    this._iceRef = this.channel.on('webrtc:ice', (payload) => {
      if (this.pc && payload.candidate) {
        this.pc.addIceCandidate(new RTCIceCandidate(payload)).catch((err) => this._emitError(err))
      }
    })

    // Server notifies about connection state changes
    this._stateRef = this.channel.on('webrtc:state', (payload) => {
      const cb = this.opts.onStateChange
      if (cb) cb(payload.state)
    })

    // Server relays DataChannel data back via WebSocket (fallback)
    this._dataRef = this.channel.on('webrtc:data', (payload) => {
      const cb = this.opts.onData
      if (cb) cb(payload.channel, payload.data)
    })

    // Server confirms channel open
    this._openRef = this.channel.on('webrtc:channel_open', (payload) => {
      const cb = this.opts.onChannelOpen
      if (cb) cb(payload.channel)
    })
  }

  _removeChannelListeners() {
    if (this._answerRef) this.channel.off('webrtc:answer', this._answerRef)
    if (this._iceRef)   this.channel.off('webrtc:ice', this._iceRef)
    if (this._stateRef) this.channel.off('webrtc:state', this._stateRef)
    if (this._dataRef)  this.channel.off('webrtc:data', this._dataRef)
    if (this._openRef)  this.channel.off('webrtc:channel_open', this._openRef)
  }

  // ── Private: RTCPeerConnection event handlers ─────────────────────────────

  _onIceCandidate(event) {
    if (event.candidate) {
      this.channel.push('webrtc:ice', event.candidate.toJSON())
    }
  }

  _onConnectionStateChange() {
    const state = this.pc.connectionState
    this.connectionState = state

    const cb = this.opts.onStateChange
    if (cb) cb(state)

    if (state === 'connected' && this._resolveConnect) {
      this._resolveConnect()
      this._resolveConnect = null
      this._rejectConnect = null
    }

    if (state === 'failed' && this._rejectConnect) {
      this._rejectConnect(new Error('WebRTC connection failed'))
      this._resolveConnect = null
      this._rejectConnect = null
    }
  }

  // ── Private: DataChannel wiring ───────────────────────────────────────────

  _wireDataChannel(dc) {
    dc.onopen = () => {
      const cb = this.opts.onChannelOpen
      if (cb) cb(dc.label)

      // Resolve connect() promise when the FIRST channel opens
      if (this._resolveConnect) {
        this._resolveConnect()
        this._resolveConnect = null
        this._rejectConnect = null
      }
    }

    dc.onclose = () => {
      const cb = this.opts.onChannelClose
      if (cb) cb(dc.label)
    }

    dc.onmessage = (event) => {
      const cb = this.opts.onData
      if (cb) cb(dc.label, event.data)
    }

    dc.onerror = (event) => {
      this._emitError(event.error || event)
    }
  }

  _emitError(error) {
    const cb = this.opts.onError
    if (cb) cb(error)
  }
}

export default GameWebRTC
