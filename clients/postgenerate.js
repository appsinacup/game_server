#!/usr/bin/env node
/**
 * postgenerate.js
 *
 * Run this after `openapi-generator-cli generate` to inject the handcrafted
 * real-time exports (GameRealtime, GameWebRTC) into the auto-generated
 * src/index.js without touching the rest of the generated code.
 *
 * Called automatically by the `generate` npm script in clients/package.json.
 * This file lives in clients/ (tracked by git) and is NOT inside clients/javascript/.
 */

const fs = require('fs')
const path = require('path')

// This script runs from clients/ directory, so javascript/src/index.js is the target
const indexPath = path.join(__dirname, 'javascript', 'src', 'index.js')

const additions = `
// ── Real-time extensions (handcrafted, not auto-generated) ──────────────────

/**
 * GameRealtime — Phoenix WebSocket channel manager.
 * Wraps Phoenix.Socket; requires the \`phoenix\` npm peer dependency.
 */
export { GameRealtime, GameRealtime as default_GameRealtime } from './realtime';

/**
 * GameWebRTC — WebRTC DataChannel client (browser only).
 * Uses an existing Phoenix channel for SDP/ICE signaling.
 */
export { GameWebRTC, GameWebRTC as default_GameWebRTC } from './webrtc';
`

let content = fs.readFileSync(indexPath, 'utf8')

if (content.includes('GameRealtime')) {
  console.log('postgenerate: real-time exports already present in index.js — skipping')
  process.exit(0)
}

fs.appendFileSync(indexPath, additions)
console.log('postgenerate: injected GameRealtime + GameWebRTC exports into src/index.js')
