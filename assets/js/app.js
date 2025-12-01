import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import ClipboardJS from "clipboard";
import topbar from "topbar";
import {hooks as colocatedHooks} from "phoenix-colocated/live_admin";

topbar.config({
  barColors: { 0: "rgb(67, 56, 202)" },
  shadowColor: "rgba(0, 0, 0, .3)",
  className: "topbar",
});
window.addEventListener("phx:page-loading-start", (info) => topbar.show());
window.addEventListener("phx:page-loading-stop", () => topbar.hide());

let Hooks = {};

Hooks.ArrayInput = {
  mounted() {
    this.el.querySelector("input").addEventListener("input", e => e.stopPropagation());

    this.el.addEventListener("keydown", e => {
      if (e.key === "Enter") {
        e.target.blur()
        e.preventDefault();
      }
    });
  },
  updated() {
    this.el.querySelector("input").addEventListener("input", e => e.stopPropagation());
  }
};

Hooks.Show = {
  setTab(el) {
    const urlHash = window.location.hash || '#main';

    for (tabLink of el.querySelectorAll('.tabs a')) {
      const target = tabLink.getAttribute('href');
      if (target === urlHash) {
        tabLink.classList.add('active');
      } else if (tabLink.getAttribute('href') !== "#main" && el.querySelector(target).querySelector(urlHash) || (el.querySelector(target).parentNode === el.querySelector(urlHash).parentElement && !tabLink.parentNode.querySelector(`:scope > a[href="${urlHash}"]`))) {
        tabLink.classList.add('active');
      } else {
        tabLink.classList.remove('active');
      };
    };

    const currentTabContent = el.querySelector(urlHash)

    for (const fieldSet of el.querySelectorAll('.card-section')) {
      if (fieldSet.parentNode === currentTabContent) {
        fieldSet.style.removeProperty('display')
      } else {
        fieldSet.style.setProperty('display', 'none');
      }
    };

    for (const tabContent of currentTabContent.parentNode.querySelectorAll('.detail-view')) {
      if (tabContent === currentTabContent) {
        tabContent.style.removeProperty('display');
      } else {
       tabContent.style.setProperty('display', 'none');
      }
    };
  },
  mounted() {
    this.setTab(this.el);

    window.addEventListener('hashchange', () => this.setTab(this.el));
  },
}

Hooks.Form = {
  mounted() {
    this.el.addEventListener('dragstart', (e) => {
      e.target.classList.add('dragging');

      for (const btn of this.el.querySelectorAll('.add-section-btn')) {
        btn.style.setProperty('display', 'none');
      };

      for (const zone of this.el.querySelectorAll(`.drop-zone:not([data-idx="${e.target.dataset.idx}"]):not([data-idx="${(+e.target.dataset.idx)+1}"])`)) {
        zone.style.setProperty('display', 'flex');
      };

      e.dataTransfer.setData('text/plain', e.target.dataset.idx);
    });


  this.el.addEventListener('dragend', (e) => {
    e.target.classList.remove('dragging');

    for (const btn of this.el.querySelectorAll('.add-section-btn')) {
      btn.style.removeProperty('display');
    };

    for (const zone of this.el.querySelectorAll('.drop-zone')) {
      zone.style.removeProperty('display');
    };
  });

  this.el.addEventListener("dragover", e => {
    if (e.target.classList.contains('drop-zone')) {
      e.target.style.setProperty('opacity', 1);
      e.preventDefault();
    }
  });

  this.el.addEventListener("dragleave", e => {
    if (e.target.classList.contains('drop-zone')) {
      e.target.style.removeProperty('opacity');
      e.preventDefault();
    }
  });

  this.el.addEventListener("drop", e => {
     if (e.target.classList.contains('drop-zone')) {
       e.preventDefault();
       const embed = e.target.parentNode.querySelector(`.embed-section[data-idx="${e.dataTransfer.getData("text/plain")}"]`)
       e.target.after(embed);

      this.el.querySelector("input").dispatchEvent(new Event("change", { bubbles: true, cancelable: true }));
    };
  });
  }
}

Hooks.SearchSelect = {
  mounted() {
    this.handleEvent("change", () => {
      this.el
        .querySelector("input")
        .dispatchEvent(new Event("input", { bubbles: true, cancelable: true }));
    });
  },
};

Hooks.CopyField = {
  mounted() {
    new ClipboardJS(this.el.querySelectorAll('[data-clipboard-target]'))
  },
}

Hooks.IndexPage = {
  mounted() {
    this.selected = [];

    // this.el.addEventListener("live_admin:action", (e) => {
    //   if (e.target.tagName === "FORM") {
    //     const params = [...new FormData(e.target)].reduce(
    //       (params, [key, val]) => {
    //         if (key === "args[]") {
    //           return { ...params, args: [...params.args, val] };
    //         } else {
    //           return { ...params, [key]: val };
    //         }
    //       },
    //       { args: [] },
    //     );

    //     this.pushEventTo(this.el, "action", { ...params, ids: this.selected });
    //   } else {
    //     this.pushEventTo(this.el, "action", {
    //       name: e.target.dataset.action,
    //       ids: this.selected,
    //     });
    //   }
    // });

    // this.el.addEventListener("live_admin:toggle_select", (e) => {
    //   if (e.target.id === "select-all") {
    //     this.el
    //       .querySelectorAll(".resource__select")
    //       .forEach((box) => (box.checked = e.target.checked));
    //   } else {
    //     this.el.querySelector("#select-all").checked = false;
    //   }

    //   this.selected = Array.from(
    //     this.el.querySelectorAll("input[data-record-key]:checked"),
    //     (e) => e.dataset.recordKey,
    //   );

    //   if (this.selected.length > 0) {
    //     document.getElementById("footer-select").style.removeProperty("display");
    //     document.getElementById("footer-nav").style.display = "none";
    //   } else {
    //     document.getElementById("footer-nav").style.removeProperty("display");
    //     document.getElementById("footer-select").style.display = "none";
    //   }
    // });
  },
  updated() {
    this.selected = [];
  },
};

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  hooks: {...Hooks, ...colocatedHooks},
  params: { _csrf_token: csrfToken },
});

// Connect if there are any LiveViews on the page
liveSocket.connect();

if (ENV == "dev") {
  liveSocket.enableDebug();
  liveSocket.enableLatencySim(process.env.LATENCY_SIM);
}

window.liveSocket = liveSocket;
