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
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

/**
 * ProgressChart hook — renders a Chart.js line chart from data passed
 * via the `data-chart` attribute. Expects JSON with `labels`, `values`,
 * and `y_label` keys. Updates automatically when the attribute changes.
 */
const ProgressChart = {
  mounted() {
    this.renderChart()
  },
  updated() {
    if (this.chart) this.chart.destroy()
    this.renderChart()
  },
  renderChart() {
    const data = JSON.parse(this.el.dataset.chart)
    const canvas = this.el.querySelector("canvas")
    if (!canvas || !window.Chart) return

    this.chart = new Chart(canvas, {
      type: "line",
      data: {
        labels: data.labels,
        datasets: [{
          label: data.y_label,
          data: data.values,
          borderColor: "rgb(220, 38, 38)",
          backgroundColor: "rgba(220, 38, 38, 0.1)",
          tension: 0.3,
          fill: true,
        }]
      },
      options: {
        responsive: true,
        scales: {
          y: { title: { display: true, text: data.y_label } },
          x: { title: { display: true, text: "Date" } }
        }
      }
    })
  },
  destroyed() {
    if (this.chart) this.chart.destroy()
  }
}

/**
 * FlashAutoDismiss hook — auto-hides flash messages after 5 seconds.
 * Uses phx-click="clear_flash" to let the LiveView clear the flash,
 * which prevents stale messages on reconnect.
 */
const FlashAutoDismiss = {
  mounted() {
    this.timer = setTimeout(() => {
      this.el.style.display = "none"
    }, 5000)
  },
  destroyed() {
    if (this.timer) clearTimeout(this.timer)
  }
}

/**
 * MobileBottomNav hook — keeps the active tab in sync with the current URL.
 * The root layout only renders once per live_session, so @conn.request_path
 * goes stale on live navigation. This hook listens for phx:navigated and
 * updates the active classes / icons client-side.
 *
 * Expects the <nav> to have data-tabs='[{"path":"/client","icon":"hero-home","activeIcon":"hero-home-solid","label":"Home","fab":false}, ...]'
 */
const MobileBottomNav = {
  mounted() {
    this._updateActive()
    this._unsub = [
      listen("phx:navigated", () => this._updateActive()),
      listen("popstate", () => this._updateActive()),
    ]
  },
  destroyed() {
    (this._unsub || []).forEach(fn => fn())
  },
  _updateActive() {
    const path = window.location.pathname
    const tabs = JSON.parse(this.el.dataset.tabs || "[]")

    // Build the list of link elements inside the nav
    const links = this.el.querySelectorAll("a[href]")

    links.forEach((link) => {
      const href = link.getAttribute("href")
      const tab = tabs.find(t => t.path === href)
      if (!tab) return

      const isActive = tabActive(path, tab.path)
      // Update icon: swap between solid and outline
      const icon = link.querySelector("svg, .hero-icon")
      if (icon && tab.activeIcon && tab.icon) {
        const current = icon.getAttribute("class") || ""
        // Heroicon class names follow the pattern hero-<name>
        const newName = isActive ? tab.activeIcon : tab.icon
        const replaced = current.replace(/hero-[a-z-]+(-solid)?/i, newName)
        if (replaced !== current) icon.setAttribute("class", replaced)
      }

      // Update link styling
      if (tab.fab) return // FAB buttons don't have active state

      if (isActive) {
        link.classList.remove("text-base-content/40", "text-gray-500")
        link.classList.add("text-base-content", "text-primary")
        link.style.transform = "scale(1.08)"
        // Add active dot if not present
        const dot = link.querySelector(".nav-active-dot")
        if (!dot) {
          const d = document.createElement("span")
          d.className = "w-1 h-1 rounded-full bg-primary mt-0.5 nav-active-dot"
          link.appendChild(d)
        }
      } else {
        link.classList.remove("text-base-content", "text-primary")
        link.classList.add("text-base-content/40", "text-gray-500")
        link.style.transform = ""
        // Remove active dot
        const dot = link.querySelector(".nav-active-dot")
        if (dot) dot.remove()
      }
    })
  }
}

function tabActive(currentPath, tabPath) {
  if (["/client", "/trainer", "/admin", "/users/settings"].includes(tabPath)) {
    return currentPath === tabPath
  }
  return currentPath === tabPath || currentPath.startsWith(tabPath + "/")
}

function listen(event, fn) {
  window.addEventListener(event, fn)
  return () => window.removeEventListener(event, fn)
}

const Hooks = { ProgressChart, FlashAutoDismiss, MobileBottomNav }

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks,
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
    window.addEventListener("keyup", _e => keyDown = null)
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

