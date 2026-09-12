// One handler for going offline and coming back.
//
// Two signals, and either one down counts: the browser's `offline`/`online`
// events, which fire the moment the network drops but know nothing about the
// server, and the LiveView socket, which knows the server but only notices a
// dead network at its next heartbeat. Nothing changes for the first 5 s —
// most drops reconnect inside that — then `<html data-connection="offline">`
// is set and `gs:connection` fires. Coming back clears both the same way.
//
// The flag lives on <html>, outside every LiveView container, so no DOM patch
// can put it back or take it away. The notice in `flash_group` is shown by
// CSS off it; a page that needs to react (the Tests page locks its answer
// sheet) reads it or listens for the event. LiveView drops every event sent
// while disconnected, so a page left looking live is a page eating input.
//
// Its own module, with no imports, so `test/connection_state.test.mjs` can
// run it under plain Node.
export const CONNECTION_GRACE_MS = 5000

export function startConnectionState(socket) {
  const root = document.documentElement
  let socketDown = false
  let networkDown = navigator.onLine === false
  let timer = null

  const apply = (offline) => {
    if ((root.dataset.connection === "offline") === offline) return
    if (offline) root.dataset.connection = "offline"
    else delete root.dataset.connection
    window.dispatchEvent(new CustomEvent("gs:connection", {detail: {offline}}))
  }

  const update = () => {
    if (!socketDown && !networkDown) {
      clearTimeout(timer)
      timer = null
      apply(false)
    } else if (timer === null && root.dataset.connection !== "offline") {
      timer = setTimeout(() => {
        timer = null
        apply(true)
      }, CONNECTION_GRACE_MS)
    }
  }

  window.addEventListener("offline", () => { networkDown = true; update() })
  window.addEventListener("online", () => { networkDown = false; update() })
  socket.onOpen(() => { socketDown = false; update() })
  socket.onClose(() => { socketDown = true; update() })
  update()
}
