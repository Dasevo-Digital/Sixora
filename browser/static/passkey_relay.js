// Content script next to passkey_page.js: passes the page's passkey
// requests to the extension and the answers back. The page cannot reach
// the extension itself, and which site asks is decided by the browser
// (`sender` in background.js), not by anything said here.
(() => {
  "use strict";

  const ext = globalThis.browser ?? globalThis.chrome;
  const origin = window.location.origin;
  const open = new Set();

  function answer(id, reply) {
    if (!open.delete(id)) return;
    window.postMessage({ sixoraPasskey: "reply", id, reply }, origin);
  }

  window.addEventListener("message", (event) => {
    if (event.source !== window) return;
    const { sixoraPasskey: kind, id, request } = event.data ?? {};
    if (typeof id !== "string") return;
    if (kind === "abort" && open.delete(id)) {
      ext.runtime.sendMessage({ sixora: "passkey-abort", pageId: id }).catch(() => {});
    }
    if (kind !== "request") return;
    open.add(id);
    ext.runtime.sendMessage({ sixora: "passkey", pageId: id, request }).then(
      (reply) => {
        if (!reply?.pending) answer(id, reply ?? { fallback: true, why: "no answer" });
      },
      (e) => answer(id, { fallback: true, why: String(e) }),
    );
  });

  // An answer for a document that is gone meets no open request here.
  ext.runtime.onMessage.addListener((message) => {
    if (message?.sixora === "passkey-result") answer(message.pageId, message.reply);
  });
})();
