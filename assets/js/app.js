import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import ClipboardJS from "clipboard";
import Toastify from "toastify-js";
import topbar from "topbar";

topbar.config({
  barColors: { 0: "rgb(67, 56, 202)" },
  shadowColor: "rgba(0, 0, 0, .3)",
  className: "topbar",
});
window.addEventListener("phx:page-loading-start", (info) => topbar.show());
window.addEventListener("phx:page-loading-stop", () => topbar.hide());
window.addEventListener("phx:success", (e) => {
  Toastify({
    text: e.detail.msg,
    className: "toast__container--success",
  }).showToast();
});
window.addEventListener("phx:error", (e) => {
  Toastify({
    text: e.detail.msg,
    className: "toast__container--error",
  }).showToast();
});

let Hooks = {};

Hooks.EmbedComponent = {
  mounted() {
    this.el.addEventListener("live_admin:move_embed", (e) => {
      const embedEl = e.target.parentElement;
      const indexEl = embedEl.querySelector(".embed__index");
      const fieldEl = embedEl.parentElement;

      const newIndex = +indexEl.value + +e.target.dataset.dir;
      indexEl.value = newIndex;

      const targetEl = fieldEl.querySelectorAll(".embed__index")[newIndex];
      targetEl.value = +targetEl.value + +e.target.dataset.dir * -1;

      indexEl.dispatchEvent(
        new Event("input", { bubbles: true, cancelable: true }),
      );
    });

    this.el.addEventListener("live_admin:embed_add", (e) => {
      const sortInput = e.target.previousElementSibling;
      sortInput.checked = true;
      sortInput.dispatchEvent(
        new Event("input", { bubbles: true, cancelable: true }),
      );
    });

    this.el.addEventListener("live_admin:embed_drop", (e) => {
      e.target.parentElement.classList.add("hidden");
      const deleteInput = e.target.previousElementSibling;
      deleteInput.checked = true;
      deleteInput.dispatchEvent(
        new Event("input", { bubbles: true, cancelable: true }),
      );
    });

    this.el.addEventListener("live_admin:embed_delete", (e) => {
      e.target.parentElement.classList.add("hidden");

      const deleteInput = e.target
        .closest(".embed__group")
        .querySelector('input[value=""]');
      deleteInput.disabled = false;
      deleteInput.dispatchEvent(
        new Event("input", { bubbles: true, cancelable: true }),
      );
    });
  },
};

Hooks.SearchSelect = {
  mounted() {
    this.handleEvent("change", () => {
      this.el
        .querySelector("input")
        .dispatchEvent(new Event("input", { bubbles: true, cancelable: true }));
    });
  },
};

Hooks.ArrayInput = {
  mounted() {
    this.handleEvent("change", () => {
      this.el
        .querySelector("input")
        .dispatchEvent(new Event("input", { bubbles: true, cancelable: true }));
    });
  },
};

Hooks.MapInput = {
  mounted() {
    this.handleEvent("change", () => {
      this.el
        .querySelector("input")
        .dispatchEvent(new Event("input", { bubbles: true, cancelable: true }));
    });
  },
};

Hooks.ViewPage = {
  mounted() {
    this.el.addEventListener("live_admin:action", (e) => {
      if (e.target.tagName === "FORM") {
        const params = [...new FormData(e.target)].reduce(
          (params, [key, val]) => {
            if (key === "args[]") {
              return { ...params, args: [...params.args, val] };
            } else {
              return { ...params, [key]: val };
            }
          },
          { args: [] },
        );

        e.target.reset();

        this.pushEventTo(this.el, "action", params);
      } else {
        this.pushEventTo(this.el, "action", { name: e.target.dataset.action });
      }
    });
  },
};

Hooks.IndexPage = {
  mounted() {
    this.selected = [];

    this.el.addEventListener("live_admin:action", (e) => {
      if (e.target.dataset.action === "delete") {
        this.pushEventTo(this.el, "delete", { ids: this.selected });
      } else if (e.target.tagName === "FORM") {
        const params = [...new FormData(e.target)].reduce(
          (params, [key, val]) => {
            if (key === "args[]") {
              return { ...params, args: [...params.args, val] };
            } else {
              return { ...params, [key]: val };
            }
          },
          { args: [] },
        );

        this.pushEventTo(this.el, "action", { ...params, ids: this.selected });
      } else {
        this.pushEventTo(this.el, "action", {
          name: e.target.dataset.action,
          ids: this.selected,
        });
      }
    });

    this.el.addEventListener("live_admin:toggle_select", (e) => {
      if (e.target.id === "select-all") {
        this.el
          .querySelectorAll(".resource__select")
          .forEach((box) => (box.checked = e.target.checked));
      } else {
        this.el.querySelector("#select-all").checked = false;
      }

      this.selected = Array.from(
        this.el.querySelectorAll("input[data-record-key]:checked"),
        (e) => e.dataset.recordKey,
      );

      if (this.selected.length > 0) {
        document.getElementById("footer-select").style.removeProperty("display");
        document.getElementById("footer-nav").style.display = "none";
      } else {
        document.getElementById("footer-nav").style.removeProperty("display");
        document.getElementById("footer-select").style.display = "none";
      }

      document.getElementById("footer-select").firstElementChild.innerHTML = this.selected.length;
    });
  },
  updated() {
    this.selected = [];

    var clipboard = new ClipboardJS(this.el.querySelectorAll(".cell__copy"), {
      target: function (trigger) {
        return trigger.closest(".resource__cell").firstElementChild;
      },
    });

    clipboard.on("success", function (e) {
      Toastify({
        text: e.trigger.dataset.message,
        className: "toast__container",
      }).showToast();
    });
  },
};

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  hooks: Hooks,
  params: { _csrf_token: csrfToken },
});

// Connect if there are any LiveViews on the page
liveSocket.connect();

if (ENV == "dev") {
  liveSocket.enableDebug();
  liveSocket.enableLatencySim(200 + Math.floor(Math.random() * 1500));
}

window.liveSocket = liveSocket;
