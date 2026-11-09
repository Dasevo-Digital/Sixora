// Content script next to passkey_page.js: passes the page's passkey
// requests to the extension and the answers back, and shows the suggestion
// at the sign-in field. The page cannot reach the extension itself, and which
// site asks is decided by the browser (`sender` in background.js), not by
// anything said here.
(() => {
  "use strict";

  const ext = globalThis.browser ?? globalThis.chrome;
  const origin = window.location.origin;
  const open = new Set();
  // Requests that wait for the user at the field: id → { request, busy }.
  const offers = new Map();

  function answer(id, reply) {
    if (!open.delete(id)) return;
    window.postMessage({ sixoraPasskey: "reply", id, reply }, origin);
  }

  // An offer the window ended without a passkey stays: the page's request
  // is still open, and the user can try again.
  function finish(id, reply) {
    const waiting = offers.get(id);
    if (waiting && !reply.result) {
      waiting.busy = false;
    } else {
      offers.delete(id);
      answer(id, reply);
    }
    updateSuggestion();
  }

  function start(id, request, picked) {
    ext.runtime.sendMessage({ sixora: "passkey", pageId: id, request, picked }).then(
      (reply) => {
        if (!reply?.pending) finish(id, reply ?? { fallback: true, why: "no answer" });
      },
      (e) => finish(id, { fallback: true, why: String(e) }),
    );
  }

  function offer(id, request) {
    ext.runtime.sendMessage({ sixora: "passkey-offer", request }).then(
      (reply) => {
        if (!open.has(id)) return;
        if (!reply?.offer) {
          answer(id, { declined: true, why: reply?.why });
          return;
        }
        offers.set(id, { request, busy: false });
        updateSuggestion();
      },
      (e) => answer(id, { declined: true, why: String(e) }),
    );
  }

  window.addEventListener("message", (event) => {
    if (event.source !== window) return;
    const { sixoraPasskey: kind, id, request } = event.data ?? {};
    if (typeof id !== "string") return;
    if (kind === "abort" && open.delete(id)) {
      offers.delete(id);
      updateSuggestion();
      ext.runtime.sendMessage({ sixora: "passkey-abort", pageId: id }).catch(() => {});
    }
    if (kind !== "request") return;
    open.add(id);
    if (request?.conditional) offer(id, request);
    else start(id, request, false);
  });

  // An answer for a document that is gone meets no open request here.
  ext.runtime.onMessage.addListener((message) => {
    if (message?.sixora === "passkey-result") finish(message.pageId, message.reply);
  });

  // --- The suggestion at the field --------------------------------------
  //
  // Built here and not in the page, in a closed shadow root, and only a
  // real click counts: the page cannot press it or read what it says.

  // Above the field: the browser's list and other managers go below it.
  const SPACE_ABOVE = 40;
  const SVG = "http://www.w3.org/2000/svg";
  let chip = null;
  let field = null;
  let chipOffer = null;

  function deepActiveElement() {
    let element = document.activeElement;
    while (element?.shadowRoot?.activeElement) element = element.shadowRoot.activeElement;
    return element;
  }

  // Browsers want `webauthn` in `autocomplete`; other managers also look at
  // plain user name fields, and so do many sites' own forms.
  function isSignInField(element) {
    if (element?.localName !== "input" || element.disabled || element.readOnly) return false;
    const auto = (element.getAttribute("autocomplete") ?? "").toLowerCase().split(/\s+/);
    if (["webauthn", "username", "email"].some((token) => auto.includes(token))) return true;
    if (element.type === "email") return true;
    return element.type === "text" && /user|mail|login|account/i.test(`${element.name} ${element.id}`);
  }

  function keyIcon() {
    const icon = document.createElementNS(SVG, "svg");
    icon.setAttribute("viewBox", "0 0 24 24");
    icon.setAttribute("width", "16");
    icon.setAttribute("height", "16");
    icon.setAttribute("fill", "none");
    icon.setAttribute("stroke", "currentColor");
    icon.setAttribute("stroke-width", "2");
    icon.setAttribute("stroke-linecap", "round");
    icon.setAttribute("stroke-linejoin", "round");
    for (const [name, attributes] of [
      ["circle", { cx: "7.5", cy: "15.5", r: "5.5" }],
      ["path", { d: "M21 2l-9.6 9.6M15.5 7.5l3 3L22 7l-3-3" }],
    ]) {
      const shape = document.createElementNS(SVG, name);
      for (const [key, value] of Object.entries(attributes)) shape.setAttribute(key, value);
      icon.append(shape);
    }
    return icon;
  }

  function pick() {
    const current = offers.get(chipOffer);
    if (!current) return;
    const id = chipOffer;
    current.busy = true;
    hideSuggestion();
    const { conditional, ...request } = current.request;
    start(id, request, true);
  }

  // Styles through the style object: a page's security policy may forbid
  // style sheets, and its own rules must not reach this element.
  function buildChip() {
    const host = document.createElement("div");
    host.setAttribute("data-sixora-passkey", "");
    host.style.cssText =
      "all:initial!important;display:block!important;position:fixed!important;" +
      "inset:auto!important;top:0;left:0;margin:0!important;padding:0!important;" +
      "border:0!important;background:transparent!important;overflow:visible!important;" +
      "z-index:2147483647!important;pointer-events:auto!important;";
    const button = document.createElement("button");
    button.type = "button";
    button.style.cssText =
      "all:initial;display:flex;align-items:center;gap:6px;height:34px;padding:0 12px;" +
      "border-radius:8px;background:#4f46e5;color:#fff;cursor:pointer;white-space:nowrap;" +
      "font:500 13px system-ui,-apple-system,'Segoe UI',sans-serif;" +
      "box-shadow:0 2px 10px rgba(0,0,0,.35);";
    button.append(keyIcon(), document.createTextNode(ext.i18n.getMessage("passkeySuggestion")));
    // Neither the field nor a dialog around it notice the click: the field
    // keeps the focus and the dialog stays open.
    for (const type of ["pointerdown", "mousedown", "touchstart", "pointerup", "mouseup", "touchend", "click"]) {
      button.addEventListener(type, (event) => {
        event.stopPropagation();
        if (type === "pointerdown" || type === "mousedown") event.preventDefault();
        if (type === "click" && event.isTrusted) pick();
      });
    }
    host.attachShadow({ mode: "closed" }).append(button);
    return host;
  }

  function follow(current) {
    if (chip !== current) return;
    const box = field.getBoundingClientRect();
    if (!field.isConnected || box.width === 0) {
      hideSuggestion();
      return;
    }
    const top = box.top > SPACE_ABOVE ? box.top - SPACE_ABOVE : box.bottom + 6;
    const left = Math.max(8, Math.min(box.left, window.innerWidth - chip.offsetWidth - 8));
    chip.style.setProperty("top", `${top}px`, "important");
    chip.style.setProperty("left", `${left}px`, "important");
    requestAnimationFrame(() => follow(current));
  }

  function showSuggestion(id, element) {
    chipOffer = id;
    if (field === element && chip) return;
    hideSuggestion();
    chipOffer = id;
    field = element;
    chip = buildChip();
    // Everything outside a modal <dialog> is inert.
    (element.closest("dialog") ?? document.documentElement).append(chip);
    try {
      chip.popover = "manual";
      chip.showPopover();
    } catch (e) {
      // No top layer in this browser: the z-index has to do.
    }
    follow(chip);
  }

  function hideSuggestion() {
    chip?.remove();
    chip = null;
    field = null;
    chipOffer = null;
  }

  function updateSuggestion() {
    let id = null;
    for (const [key, current] of offers) {
      if (!current.busy) id = key;
    }
    const element = id === null ? null : deepActiveElement();
    if (isSignInField(element)) showSuggestion(id, element);
    else hideSuggestion();
  }

  document.addEventListener("focusin", updateSuggestion, true);
  document.addEventListener("focusout", () => setTimeout(updateSuggestion), true);
})();
