// The extension's access to the browser, for the Dart code (popup.dart).
// Kept in plain JavaScript: the function that fills the page is copied
// into the page by the browser, and the WebExtension APIs differ slightly
// between Firefox and Safari (browser.*) and Chromium (chrome.*).
"use strict";

const ext = globalThis.browser ?? globalThis.chrome;

// storage.session is memory only and forgotten when the browser closes.
// Where it is missing, an unlocked state lasts as long as the popup.
const memory = new Map();
function area(name) {
  if (name === "session" && !ext.storage.session) {
    return {
      get: async (key) => (memory.has(key) ? { [key]: memory.get(key) } : {}),
      set: async (items) => Object.entries(items).forEach(([k, v]) => memory.set(k, v)),
      remove: async (key) => memory.delete(key),
    };
  }
  return ext.storage[name];
}

// Runs inside the web page (copied there by scripting.executeScript, so it
// must not use anything from this file). Puts the code into the field for
// it: the focused field, a field that asks for a one-time code, or a row
// of single-character fields. Returns whether it filled something.
function fillInPage(code) {
  const strong = [
    "totp", "2fa", "mfa", "tfa", "one-time", "onetime", "one_time",
    "authenticator", "two-factor", "twofactor", "two_factor", "2-step",
    "two-step", "2step", "zwei-faktor", "einmalcode", "einmal-code",
    "einmalpasswort", "un solo uso", "dos pasos",
  ];
  const context = [
    "verif", "auth", "secur", "confirm", "login", "sign-in", "signin",
    "bestätig", "bestaetig", "sicherheit", "anmelde", "verifizier",
    "authentifizier", "seguridad", "acceso",
  ];
  const otherCodes = [
    "postal", "zip", "plz", "promo", "coupon", "voucher", "gutschein",
    "rabatt", "discount", "country", "area", "invite", "einladung",
    "referral", "captcha", "cupón", "cupon", "descuento",
  ];
  const otherFields = [
    "username", "email", "current-password", "new-password", "tel",
    "cc-number", "cc-csc", "name", "street-address", "postal-code",
  ];
  const textTypes = ["", "text", "tel", "number", "password"];

  const usable = (el) =>
    el instanceof HTMLInputElement &&
    textTypes.includes((el.getAttribute("type") || "").toLowerCase()) &&
    !el.disabled && !el.readOnly &&
    el.getClientRects().length > 0 &&
    getComputedStyle(el).visibility !== "hidden";

  const labelOf = (el) => {
    const parts = [el.name, el.id, el.placeholder, el.getAttribute("aria-label")];
    for (const label of el.labels || []) parts.push(label.textContent);
    return parts.filter(Boolean).join(" ").toLowerCase();
  };

  const asksForCode = (el) => {
    const auto = (el.getAttribute("autocomplete") || "").toLowerCase().split(/\s+/);
    if (auto.includes("one-time-code")) return true;
    if (auto.some((a) => otherFields.includes(a))) return false;
    const text = labelOf(el);
    if (/(^|[^a-z0-9])otp/.test(text) || strong.some((w) => text.includes(w))) return true;
    if ((el.getAttribute("type") || "").toLowerCase() === "password") return false;
    const isCode = text.includes("code") || text.includes("código") || text.includes("codigo");
    return isCode && context.some((w) => text.includes(w)) && !otherCodes.some((w) => text.includes(w));
  };

  // React & co. watch the value setter, not the property.
  const put = (el, value) => {
    el.focus();
    Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, "value").set.call(el, value);
    el.dispatchEvent(new Event("input", { bubbles: true }));
    el.dispatchEvent(new Event("change", { bubbles: true }));
  };

  const fields = [...document.querySelectorAll("input")].filter(usable);
  // One box per digit: fill them in order.
  const singles = fields.filter((el) => el.maxLength === 1);
  if (singles.length >= code.length && singles.length <= code.length + 2) {
    singles.slice(0, code.length).forEach((el, i) => put(el, code[i]));
    return true;
  }
  const active = document.activeElement;
  const focused = fields.includes(active) && !(active.getAttribute("autocomplete") || "")
    .toLowerCase().split(/\s+/).some((a) => otherFields.includes(a)) ? active : null;
  const target = fields.find(asksForCode) ?? focused;
  if (!target) return false;
  put(target, code);
  return true;
}

globalThis.sixoraBridge = {
  async read(areaName, key) {
    const result = await area(areaName).get(key);
    return result[key] ?? null;
  },

  async write(areaName, key, value) {
    if (value === null || value === undefined) await area(areaName).remove(key);
    else await area(areaName).set({ [key]: value });
  },

  // Must be called right in the click handler (user gesture).
  requestHost(pattern) {
    return ext.permissions.request({ origins: [pattern] });
  },

  async activeTabUrl() {
    const [tab] = await ext.tabs.query({ active: true, currentWindow: true });
    return tab?.url ?? null;
  },

  async fill(code) {
    const [tab] = await ext.tabs.query({ active: true, currentWindow: true });
    if (!tab?.id) return false;
    try {
      const results = await ext.scripting.executeScript({
        target: { tabId: tab.id, allFrames: true },
        func: fillInPage,
        args: [code],
      });
      return results.some((r) => r.result === true);
    } catch (e) {
      // Browser pages and stores do not allow scripts.
      return false;
    }
  },

  openTab(path) {
    return ext.tabs.create({ url: ext.runtime.getURL(path) });
  },

  version() {
    return ext.runtime.getManifest().version;
  },

  language() {
    return ext.i18n?.getUILanguage?.() ?? navigator.language;
  },

  isBrave() {
    return !!navigator.brave;
  },
};
