import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";
import { Hooks as FluxonHooks, DOM as FluxonDOM } from "fluxon";

let Uploaders = {};

Uploaders.S3 = function (entries, onViewError) {
  entries.forEach((entry) => {
    let xhr = new XMLHttpRequest();
    onViewError(() => xhr.abort());

    xhr.onload = () => {
      console.log("Response Status:", xhr.status);
      xhr.status === 200 ? entry.progress(100) : entry.error();
    };

    xhr.onerror = (error) => {
      console.error("Upload error:", error);
      entry.error();
    };

    xhr.upload.addEventListener("progress", (event) => {
      if (event.lengthComputable) {
        let percent = Math.round((event.loaded / event.total) * 100);
        if (percent < 100) {
          entry.progress(percent);
        }
      }
    });

    let url = entry.meta.url;
    xhr.open("PUT", url, true);

    // Set headers that match the pre-signed URL
    xhr.setRequestHeader("Content-Type", entry.file.type);
    xhr.setRequestHeader("x-amz-acl", "private");

    xhr.send(entry.file);
  });
};

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: FluxonHooks,
  uploaders: Uploaders,
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  dom: {
    onBeforeElUpdated(from, to) {
      FluxonDOM.onBeforeElUpdated(from, to);
    },
  },
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

window.addEventListener("phx:js-exec", ({ detail }) => {
  document.querySelectorAll(detail.to).forEach((el) => {
    liveSocket.execJS(el, el.getAttribute(detail.attr));
  });
});

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
