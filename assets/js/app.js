import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import ClipboardJS from 'clipboard'
import Toastify from 'toastify-js'
import topbar from "topbar"

topbar.config({barColors: {0: "rgb(67, 56, 202)"}, shadowColor: "rgba(0, 0, 0, .3)", className: "topbar"})
window.addEventListener("phx:page-loading-start", info => topbar.show())
window.addEventListener("phx:page-loading-stop", info => topbar.hide())
window.addEventListener("phx:success", (e) => {
  Toastify({
    text: e.detail.msg,
    className: "toast__container--success",
  }).showToast();
})
window.addEventListener("phx:error", (e) => {
  Toastify({
    text: e.detail.msg,
    className: "toast__container--error",
  }).showToast();
})

let Hooks = {}
Hooks.IndexPage = {
  mounted() {
    var clipboard = new ClipboardJS(this.el.querySelectorAll('.cell__copy'));

    clipboard.on('success', function(e) {
      Toastify({
        text: e.trigger.dataset.message,
        className: "toast__container",
      }).showToast();
    });
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {hooks: Hooks, params: {_csrf_token: csrfToken}})

// Connect if there are any LiveViews on the page
liveSocket.connect()

if (ENV == "dev") {
  liveSocket.enableDebug()
  liveSocket.enableLatencySim(1000)
}

window.liveSocket = liveSocket
