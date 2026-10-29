// Talks to the Sixora desktop app for the popup ("Mit Touch ID
// entsperren"), through native messaging. It lives here and not in the
// popup: the popup closes as soon as Touch ID or a dialog of the app takes
// the focus. The answer then waits in storage.session (memory only) for the
// next popup, and the popup is opened again where the browser allows it.
"use strict";

const ext = globalThis.browser ?? globalThis.chrome;
const HOST = "de.status403.sixora";
const CLIPBOARD_ALARM = "sixora-clear-clipboard";
const CLIPBOARD_KEY = "sixoraPendingClipboard";
let pendingClipboard = null;
let creatingOffscreen = null;

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

async function rememberClipboard(code) {
  pendingClipboard = code;
  if (ext.storage.session) {
    await ext.storage.session.set({ [CLIPBOARD_KEY]: code });
  }
}

async function pendingCode() {
  if (ext.storage.session) {
    const stored = await ext.storage.session.get(CLIPBOARD_KEY);
    return stored[CLIPBOARD_KEY] ?? null;
  }
  return pendingClipboard;
}

async function forgetClipboard() {
  pendingClipboard = null;
  if (ext.storage.session) await ext.storage.session.remove(CLIPBOARD_KEY);
}

async function ensureOffscreenDocument() {
  if (!ext.offscreen) return false;
  if (await ext.offscreen.hasDocument()) return true;
  if (!creatingOffscreen) {
    creatingOffscreen = ext.offscreen.createDocument({
      url: "offscreen.html",
      reasons: ["CLIPBOARD"],
      justification: "Einmal-Code nach 30 Sekunden aus der Zwischenablage entfernen",
    }).finally(() => creatingOffscreen = null);
  }
  await creatingOffscreen;
  return true;
}

async function clearClipboardIfUnchanged(code) {
  // Chromium service workers have no clipboard; their offscreen document
  // performs the same comparison without opening a visible page.
  if (await ensureOffscreenDocument()) {
    return await ext.runtime.sendMessage({
      sixora: "clipboard-clear",
      code,
    }) === true;
  }
  const clipboard = globalThis.navigator?.clipboard;
  if (!clipboard?.readText || !clipboard?.writeText) return false;
  const current = await clipboard.readText();
  if (current !== code) return false;
  await clipboard.writeText("");
  return true;
}

async function scheduleClipboardClear(code) {
  if (typeof code !== "string" || code.length === 0 || code.length > 64) {
    return false;
  }
  await rememberClipboard(code);
  await ext.alarms.create(CLIPBOARD_ALARM, { delayInMinutes: 0.5 });
  return true;
}

ext.alarms.onAlarm.addListener(async (alarm) => {
  if (alarm.name !== CLIPBOARD_ALARM) return;
  const code = await pendingCode();
  if (code == null) return;
  try {
    await clearClipboardIfUnchanged(code);
  } catch (e) {
    // Some browser/OS combinations deny background clipboard access.
  } finally {
    await forgetClipboard();
  }
});

ext.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (sender.id !== ext.runtime.id) return false;
  if (message?.sixora === "clipboard-schedule") {
    scheduleClipboardClear(message.code).then(sendResponse, () => sendResponse(false));
    return true;
  }
  if (message?.sixora !== "native") return false;
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
