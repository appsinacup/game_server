// `node --test apps/gamend_web/assets/js/test/` — no dependencies. Also run by
// `test/gamend_web/js_test.exs`, so `mix test` covers it.
import {test, beforeEach, afterEach, mock} from "node:test"
import assert from "node:assert/strict"

import {startConnectionState, CONNECTION_GRACE_MS} from "../connection_state.js"

let listeners, events, socket

// A fresh page per test: <html>, window listeners, a socket to open and close.
beforeEach(() => {
  mock.timers.enable({apis: ["setTimeout"]})
  listeners = {}
  events = []
  globalThis.window = {
    addEventListener: (type, fn) => (listeners[type] ||= []).push(fn),
    dispatchEvent: (event) => events.push(event.detail.offline),
  }
  globalThis.document = {documentElement: {dataset: {}}}
  Object.defineProperty(globalThis, "navigator", {value: {onLine: true}, configurable: true})

  const callbacks = {open: [], close: []}
  socket = {
    onOpen: (fn) => callbacks.open.push(fn),
    onClose: (fn) => callbacks.close.push(fn),
    open: () => callbacks.open.forEach((fn) => fn()),
    close: () => callbacks.close.forEach((fn) => fn()),
  }
})

afterEach(() => mock.timers.reset())

const flag = () => document.documentElement.dataset.connection
const fire = (type) => (listeners[type] || []).forEach((fn) => fn())

test("a drop that reconnects inside the grace period shows nothing", () => {
  startConnectionState(socket)
  socket.close()
  mock.timers.tick(CONNECTION_GRACE_MS - 1)
  socket.open()
  mock.timers.tick(CONNECTION_GRACE_MS)

  assert.equal(flag(), undefined)
  assert.deepEqual(events, [])
})

test("a drop that lasts is flagged at the grace period, once", () => {
  startConnectionState(socket)
  socket.close()
  mock.timers.tick(CONNECTION_GRACE_MS - 1)
  assert.equal(flag(), undefined)

  mock.timers.tick(1)
  assert.equal(flag(), "offline")

  // Failed retries close the socket again; the notice is already up.
  socket.close()
  mock.timers.tick(CONNECTION_GRACE_MS * 3)
  assert.deepEqual(events, [true])
})

test("the same handler clears it on the way back", () => {
  startConnectionState(socket)
  socket.close()
  mock.timers.tick(CONNECTION_GRACE_MS)
  socket.open()

  assert.equal(flag(), undefined)
  assert.deepEqual(events, [true, false])
})

test("the browser going offline counts on its own", () => {
  startConnectionState(socket)
  fire("offline")
  mock.timers.tick(CONNECTION_GRACE_MS)
  assert.equal(flag(), "offline")

  fire("online")
  assert.equal(flag(), undefined)
})

test("the network coming back does not clear it while the socket is still down", () => {
  startConnectionState(socket)
  fire("offline")
  socket.close()
  mock.timers.tick(CONNECTION_GRACE_MS)

  fire("online")
  assert.equal(flag(), "offline")

  socket.open()
  assert.equal(flag(), undefined)
})

test("a page loaded offline is flagged without waiting for an event", () => {
  navigator.onLine = false
  startConnectionState(socket)
  mock.timers.tick(CONNECTION_GRACE_MS)

  assert.equal(flag(), "offline")
})
