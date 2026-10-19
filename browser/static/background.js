// Talks to the Sixora desktop app for the popup ("Mit Touch ID
// entsperren"), through native messaging. It lives here and not in the
// popup: the popup closes as soon as Touch ID or a dialog of the app takes
// the focus. The answer then waits in storage.session (memory only) for the
// next popup, and the popup is opened again where the browser allows it.
"use strict";

const ext = globalThis.browser ?? globalThis.chrome;
const HOST = "de.status403.sixora";

function ask(request, timeout) {
  return new Promise((resolve) => {
    let port;
    try {
      port = ext.runtime.connectNative(HOST);
    } catch (e) {
      resolve({ error: "no_host" });
      return;
    }
    const timer = setTimeout(() => {
      port.disconnect();
      resolve({ error: "timeout" });
    }, timeout);
    port.onMessage.addListener((reply) => {
      clearTimeout(timer);
      port.disconnect();
      resolve(reply);
    });
    // No host registered, or it ended without an answer.
    port.onDisconnect.addListener((p) => {
      clearTimeout(timer);
      const reason = ext.runtime.lastError?.message ?? p?.error?.message ?? "";
      resolve({ error: "no_host", reason });
    });
    port.postMessage(request);
  });
}

ext.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (sender.id !== ext.runtime.id || message?.sixora !== "native") return false;
  ask(message.request, message.timeout ?? 5000).then(async (reply) => {
    const keep = message.keep;
    if (keep) await ext.storage.session.set({ [keep]: JSON.stringify(reply) });
    sendResponse(reply);
    if (!keep) return;
    // An open popup takes the answer at once. Still there a moment later,
    // the popup had closed: open it again where the browser allows it.
    setTimeout(async () => {
      const left = await ext.storage.session.get(keep);
      if (left[keep] == null) return;
      try {
        await ext.action.openPopup();
      } catch (e) {
        // Not allowed here: the next popup picks it up.
      }
    }, 1000);
  });
  return true;
});
