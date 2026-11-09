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

// --- Passkeys ---------------------------------------------------------------

const PASSKEY_ORIGINS = ["https://*/*", "http://localhost/*"];
const PASSKEY_SCRIPTS = ["sixora-passkey-page", "sixora-passkey-relay"];

// In storage.session: a request by its id, the id by its window, the open
// ceremony by its tab, and until when a tab stays quiet after a "no".
const PASSKEY_REQUEST = "passkey:";
const PASSKEY_WINDOW = "passkeyWindow:";
const PASSKEY_TAB = "passkeyTab:";
const PASSKEY_PAUSE = "passkeyPause:";
const PASSKEY_PAUSE_MS = 10000;

const passkeyStarting = new Set();

let passkeyScripts = Promise.resolve(false);

// Brings the page scripts in line with the setting and the permission. Runs
// here and not in the popup, which Firefox closes while it asks.
function applyPasskeyScripts() {
  const apply = async () => {
    const { passkeysWanted } = await ext.storage.local.get("passkeysWanted");
    const on =
      Boolean(passkeysWanted) &&
      (await ext.permissions.contains({ origins: PASSKEY_ORIGINS }));
    const registered = await ext.scripting.getRegisteredContentScripts({
      ids: PASSKEY_SCRIPTS,
    });
    if (on && registered.length === PASSKEY_SCRIPTS.length) return true;
    if (registered.length > 0) {
      await ext.scripting.unregisterContentScripts({
        ids: registered.map((script) => script.id),
      });
    }
    if (!on) return false;
    const shared = {
      matches: PASSKEY_ORIGINS,
      runAt: "document_start",
      allFrames: false,
    };
    await ext.scripting.registerContentScripts([
      { ...shared, id: PASSKEY_SCRIPTS[0], js: ["passkey_page.js"], world: "MAIN" },
      { ...shared, id: PASSKEY_SCRIPTS[1], js: ["passkey_relay.js"] },
    ]);
    return true;
  };
  passkeyScripts = passkeyScripts.then(apply, apply);
  return passkeyScripts;
}

ext.runtime.onInstalled.addListener(applyPasskeyScripts);
ext.runtime.onStartup.addListener(applyPasskeyScripts);
ext.permissions?.onAdded?.addListener(applyPasskeyScripts);
ext.permissions?.onRemoved?.addListener(applyPasskeyScripts);

// Whether a passkey for this site is stored: otherwise no window opens and
// the browser handles the request as if Sixora were not there.
async function siteHasPasskey(rpId) {
  const stored = await ext.storage.local.get("passkeyIndex");
  if (!stored.passkeyIndex) return false;
  const { salt, sites } = JSON.parse(stored.passkeyIndex);
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(`${salt}|${rpId}`),
  );
  return sites.includes(btoa(String.fromCharCode(...new Uint8Array(digest))));
}

async function openPasskeyWindow(message, origin, tabId) {
  const request = message.request;
  const tabKey = PASSKEY_TAB + tabId;
  const pauseKey = PASSKEY_PAUSE + tabId;
  const state = await ext.storage.session.get([tabKey, pauseKey]);
  // One window per tab, and no new one right after a "no": a page must not
  // be able to keep them coming.
  if (state[tabKey] || (state[pauseKey] ?? 0) > Date.now()) return { fallback: true };
  const id = crypto.randomUUID();
  const key = PASSKEY_REQUEST + id;
  await ext.storage.session.set({
    [key]: JSON.stringify({ origin, tabId, pageId: message.pageId, request }),
  });
  try {
    const window = await ext.windows.create({
      url: ext.runtime.getURL(`popup.html#passkey=${id}`),
      type: "popup",
      width: 420,
      height: 560,
    });
    await ext.storage.session.set({
      [PASSKEY_WINDOW + window.id]: id,
      [tabKey]: JSON.stringify({ id, windowId: window.id, pageId: message.pageId }),
    });
  } catch (e) {
    await ext.storage.session.remove(key);
    throw e;
  }
  return { pending: true };
}

async function startPasskey(message, sender) {
  // Which site asks comes from the browser, never from the page. Frames
  // keep the browser's own passkeys.
  const origin = sender.origin ?? (sender.url ? new URL(sender.url).origin : null);
  const tabId = sender.tab?.id;
  if (sender.frameId !== 0 || tabId === undefined || !origin || origin === "null") {
    return { fallback: true };
  }
  const request = message.request ?? {};
  const host = new URL(origin).hostname;
  const rpId = String(request.rpId || host).toLowerCase();
  // The browser reports the mistake; and a page learns nothing, not even
  // through a window, about the passkeys of other sites.
  if (host !== rpId && !host.endsWith(`.${rpId}`)) return { fallback: true };
  if (request.kind !== "create" && !(await siteHasPasskey(rpId))) return { fallback: true };
  if (passkeyStarting.has(tabId)) return { fallback: true };
  passkeyStarting.add(tabId);
  try {
    return await openPasskeyWindow({ ...message, request }, origin, tabId);
  } finally {
    passkeyStarting.delete(tabId);
  }
}

// Ends a request and returns the record; null if it is already over.
async function takePasskey(id) {
  const key = PASSKEY_REQUEST + id;
  const text = (await ext.storage.session.get(key))[key];
  if (!text) return null;
  const record = JSON.parse(text);
  const tabKey = PASSKEY_TAB + record.tabId;
  const open = (await ext.storage.session.get(tabKey))[tabKey];
  await ext.storage.session.remove([key, tabKey]);
  return { ...record, windowId: open ? JSON.parse(open).windowId : null };
}

function closePasskeyWindow(windowId) {
  if (windowId !== null) ext.windows.remove(windowId).catch(() => {});
}

// Hands the answer to the page and closes the window.
async function finishPasskey(id, reply) {
  const record = await takePasskey(id);
  if (!record) return false;
  if (reply.error === "NotAllowedError") {
    await ext.storage.session.set({
      [PASSKEY_PAUSE + record.tabId]: Date.now() + PASSKEY_PAUSE_MS,
    });
  }
  try {
    await ext.tabs.sendMessage(
      record.tabId,
      { sixora: "passkey-result", pageId: record.pageId, reply },
      { frameId: 0 },
    );
  } catch (e) {
    // The tab was closed meanwhile.
  }
  closePasskeyWindow(record.windowId);
  return true;
}

// The page itself gave up (AbortController).
async function abortPasskey(message, sender) {
  const tabKey = PASSKEY_TAB + sender.tab?.id;
  const open = (await ext.storage.session.get(tabKey))[tabKey];
  if (!open) return;
  const { id, pageId } = JSON.parse(open);
  if (pageId !== message.pageId || sender.frameId !== 0) return;
  const record = await takePasskey(id);
  if (record) closePasskeyWindow(record.windowId);
}

// Closing the window is a "no" for the page.
ext.windows.onRemoved.addListener(async (windowId) => {
  const key = PASSKEY_WINDOW + windowId;
  const id = (await ext.storage.session.get(key))[key];
  if (!id) return;
  await ext.storage.session.remove(key);
  await finishPasskey(id, { error: "NotAllowedError", message: "" });
});

ext.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (sender.id !== ext.runtime.id) return false;
  if (message?.sixora === "passkey") {
    startPasskey(message, sender).then(sendResponse, () => sendResponse({ fallback: true }));
    return true;
  }
  if (message?.sixora === "passkey-abort") {
    abortPasskey(message, sender).then(sendResponse, () => sendResponse(false));
    return true;
  }
  if (message?.sixora === "passkey-finish") {
    // Only from the extension's own pages, not from a content script.
    if (!sender.url?.startsWith(ext.runtime.getURL(""))) return false;
    finishPasskey(message.id, message.reply).then(sendResponse, () => sendResponse(false));
    return true;
  }
  if (message?.sixora === "passkey-scripts") {
    if (!sender.url?.startsWith(ext.runtime.getURL(""))) return false;
    applyPasskeyScripts().then(sendResponse, () => sendResponse(false));
    return true;
  }
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
