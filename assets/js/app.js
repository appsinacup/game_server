// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Theme switcher & card collapse/expand (previously inline in root.html.heex)
import "./theme.js"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/game_server_web"
import "./lobbies"
import topbar from "../vendor/topbar"

// Custom hooks
const Hooks = {
  /**
   * SiteBanner — dismissible site-wide announcement banner.
   *
   * Reads `data-message-hash` to identify the current message. Dismissed hashes
   * are stored in localStorage so the banner stays hidden across page loads.
   * When the message changes (hash differs), the banner re-appears.
   */
  SiteBanner: {
    mounted() {
      const STORAGE_KEY = "dismissed_site_banners"
      const hash = this.el.dataset.messageHash
      if (!hash) return

      // Read dismissed set from localStorage
      const dismissed = JSON.parse(localStorage.getItem(STORAGE_KEY) || "[]")

      if (dismissed.includes(hash)) {
        // Already dismissed — stay hidden
        return
      }

      // Not dismissed — reveal the banner
      this.el.classList.remove("hidden")

      // Wire up dismiss button
      const btn = this.el.querySelector("[data-dismiss-banner]")
      if (btn) {
        btn.addEventListener("click", () => {
          // Slide up animation
          this.el.style.maxHeight = this.el.scrollHeight + "px"
          requestAnimationFrame(() => {
            this.el.style.overflow = "hidden"
            this.el.style.maxHeight = "0"
            this.el.style.paddingTop = "0"
            this.el.style.paddingBottom = "0"
          })

          // Persist after animation completes
          setTimeout(() => {
            this.el.style.display = "none"
            // Keep only the last 50 dismissed hashes to avoid unbounded growth
            const current = JSON.parse(localStorage.getItem(STORAGE_KEY) || "[]")
            const updated = [...current.slice(-49), hash]
            localStorage.setItem(STORAGE_KEY, JSON.stringify(updated))
          }, 300)
        })
      }
    }
  },
  Fullscreen: {
    mounted() {
      // Only show button on devices that support the Fullscreen API
      if (!document.fullscreenEnabled && !document.webkitFullscreenEnabled) return
      this.el.classList.remove("hidden")

      this.el.addEventListener("click", () => {
        const target = document.getElementById(this.el.dataset.target)
        if (!target) return

        if (document.fullscreenElement) {
          document.exitFullscreen()
        } else {
          target.requestFullscreen().catch(() => {
            // Fallback for Safari/iOS
            if (target.webkitRequestFullscreen) target.webkitRequestFullscreen()
          })
        }
      })

      // Update button icon when fullscreen state changes (including Esc key)
      this.onFSChange = () => {
        const isFS = !!document.fullscreenElement
        this.el.setAttribute("data-fullscreen", isFS)
      }
      document.addEventListener("fullscreenchange", this.onFSChange)
      document.addEventListener("webkitfullscreenchange", this.onFSChange)
    },
    destroyed() {
      document.removeEventListener("fullscreenchange", this.onFSChange)
      document.removeEventListener("webkitfullscreenchange", this.onFSChange)
    }
  },
  GameAuth: {
    mounted() {
      const access = this.el.dataset.accessToken
      const refresh = this.el.dataset.refreshToken
      if (access) localStorage.setItem("gamend_access_token", access)
      if (refresh) localStorage.setItem("gamend_refresh_token", refresh)
      // Clear tokens when not authenticated
      if (!access) localStorage.removeItem("gamend_access_token")
      if (!refresh) localStorage.removeItem("gamend_refresh_token")
    }
  },
  GameViewport: {
    mounted() {
      // Prevent mobile browsers from zooming when the virtual keyboard opens.
      // We swap the viewport meta to disable user scaling while the game is
      // visible, and restore it when the LiveView is destroyed.
      const meta = document.querySelector('meta[name="viewport"]')
      if (meta) {
        this._origViewport = meta.getAttribute("content")
        meta.setAttribute(
          "content",
          "width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no"
        )
      }

      // Prevent scroll drift when virtual keyboard opens/closes
      const vv = window.visualViewport
      if (vv) {
        this._onResize = () => window.scrollTo(0, 0)
        vv.addEventListener("resize", this._onResize)
        vv.addEventListener("scroll", this._onResize)
      }
    },
    destroyed() {
      // Restore original viewport meta
      const meta = document.querySelector('meta[name="viewport"]')
      if (meta && this._origViewport) {
        meta.setAttribute("content", this._origViewport)
      }

      const vv = window.visualViewport
      if (vv && this._onResize) {
        vv.removeEventListener("resize", this._onResize)
        vv.removeEventListener("scroll", this._onResize)
      }
    }
  },
  ScrollToBottom: {
    mounted() {
      this.el.scrollTop = this.el.scrollHeight
    },
    updated() {
      this.el.scrollTop = this.el.scrollHeight
    }
  },
  AutoClose: {
    mounted() {
      let seconds = 3
      this.el.innerText = `This window will close in ${seconds}s...`
      
      this.interval = setInterval(() => {
        seconds -= 1
        if (seconds <= 0) {
          clearInterval(this.interval)
          this.el.innerText = "Closing..."
          window.close()
        } else {
          this.el.innerText = `This window will close in ${seconds}s...`
        }
      }, 1000)
    },
    destroyed() {
      if (this.interval) clearInterval(this.interval)
    }
  },
  ReconnectNotice: {
    mounted() {
      this.delayMs = parseInt(this.el.dataset.delayMs || "5000", 10)
      this.timer = null
      this.hide()

      this.onDisconnected = () => {
        this.clearTimer()
        this.timer = setTimeout(() => this.show(), this.delayMs)
      }

      this.onConnected = () => {
        this.clearTimer()
        this.hide()
      }

      this.el.addEventListener("gs:lv-disconnected", this.onDisconnected)
      this.el.addEventListener("gs:lv-connected", this.onConnected)
    },
    destroyed() {
      this.clearTimer()
      this.el.removeEventListener("gs:lv-disconnected", this.onDisconnected)
      this.el.removeEventListener("gs:lv-connected", this.onConnected)
    },
    clearTimer() {
      if (this.timer) {
        clearTimeout(this.timer)
        this.timer = null
      }
    },
    show() {
      this.el.removeAttribute("hidden")
    },
    hide() {
      this.el.setAttribute("hidden", "")
    }
  },
  NavbarAutohide: {
    mounted() {
      const targetId = this.el.dataset.target || "main-navbar"
      this.navbar = document.getElementById(targetId)
      if (!this.navbar) return

      this.isHidden = false
      this.delay = parseInt(this.el.dataset.autohideDelay || "5000", 10)

      // Create dismiss button inside the navbar (visible while navbar is shown)
      this.dismissBtn = document.createElement("button")
      this.dismissBtn.className =
        "btn btn-ghost btn-circle btn-sm ml-1 opacity-60 hover:opacity-100 transition-opacity"
      this.dismissBtn.setAttribute("aria-label", "Hide navigation")
      this.dismissBtn.innerHTML = `<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"/></svg>`
      this.dismissBtn.addEventListener("click", (e) => {
        e.stopPropagation()
        this.hideNavbar()
      })
      this.navbar.appendChild(this.dismissBtn)

      // Create the toggle button (visible when navbar is hidden)
      this.toggleBtn = document.createElement("button")
      this.toggleBtn.className =
        "fixed top-3 right-3 z-[60] btn btn-circle btn-sm bg-base-100/60 backdrop-blur-sm border-base-content/10 shadow-md opacity-0 pointer-events-none transition-opacity duration-300"
      this.toggleBtn.setAttribute("aria-label", "Show navigation")
      this.toggleBtn.innerHTML = `<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/></svg>`
      this.toggleBtn.addEventListener("click", () => this.showNavbar())
      document.body.appendChild(this.toggleBtn)

      // Start the autohide timer
      this.timer = setTimeout(() => this.hideNavbar(), this.delay)
    },
    destroyed() {
      if (this.timer) clearTimeout(this.timer)
      if (this.dismissBtn && this.dismissBtn.parentNode) {
        this.dismissBtn.parentNode.removeChild(this.dismissBtn)
      }
      if (this.toggleBtn && this.toggleBtn.parentNode) {
        this.toggleBtn.parentNode.removeChild(this.toggleBtn)
      }
    },
    hideNavbar() {
      if (!this.navbar) return
      this.isHidden = true
      if (this.timer) clearTimeout(this.timer)
      this.navbar.style.transition = "opacity 0.5s ease, transform 0.5s ease"
      this.navbar.style.opacity = "0"
      this.navbar.style.transform = "translateY(-100%)"
      this.navbar.style.pointerEvents = "none"
      // Show the toggle button
      this.toggleBtn.style.opacity = "1"
      this.toggleBtn.style.pointerEvents = "auto"
    },
    showNavbar() {
      if (!this.navbar) return
      this.isHidden = false
      this.navbar.style.transition = "opacity 0.3s ease, transform 0.3s ease"
      this.navbar.style.opacity = "1"
      this.navbar.style.transform = "translateY(0)"
      this.navbar.style.pointerEvents = "auto"
      // Hide the toggle button
      this.toggleBtn.style.opacity = "0"
      this.toggleBtn.style.pointerEvents = "none"
      // Re-start autohide timer
      if (this.timer) clearTimeout(this.timer)
      this.timer = setTimeout(() => this.hideNavbar(), this.delay)
    }
  },

  /**
   * AutoScroll — keeps a scrollable container pinned to the bottom
   * as new content is added (e.g. live log viewer).
   */
  AutoScroll: {
    mounted() {
      this._scroll = () => {
        this.el.scrollTop = this.el.scrollHeight
      }
      this._observer = new MutationObserver(this._scroll)
      this._observer.observe(this.el, { childList: true, subtree: true })
      this._scroll()
    },
    updated() {
      this._scroll()
    },
    destroyed() {
      if (this._observer) this._observer.disconnect()
    }
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...Hooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

