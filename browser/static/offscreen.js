"use strict";

const ext = globalThis.chrome;
const field = document.getElementById("clipboard");

function readWithCommand() {
  let value = null;
  const take = (event) => {
    value = event.clipboardData.getData("text/plain");
    event.preventDefault();
  };
  document.addEventListener("paste", take, { once: true });
  field.focus();
  const allowed = document.execCommand("paste");
  document.removeEventListener("paste", take);
  if (!allowed || value === null) throw new Error("clipboard read denied");
  return value;
}

function writeWithCommand(value) {
  let handled = false;
  const put = (event) => {
    event.clipboardData.setData("text/plain", value);
    event.preventDefault();
    handled = true;
  };
  document.addEventListener("copy", put, { once: true });
  field.focus();
  const allowed = document.execCommand("copy");
  document.removeEventListener("copy", put);
  if (!allowed || !handled) throw new Error("clipboard write denied");
}

async function readClipboard() {
  try {
    return readWithCommand();
  } catch (e) {
    if (navigator.clipboard?.readText) return await navigator.clipboard.readText();
    throw e;
  }
}

async function clearClipboard() {
  try {
    writeWithCommand("");
    return;
  } catch (e) {
    if (navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText("");
      return;
    }
    throw e;
  }
}

ext.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (sender.id !== ext.runtime.id || message?.sixora !== "clipboard-clear") {
    return false;
  }
  (async () => {
    const current = await readClipboard();
    if (current !== message.code) return false;
    await clearClipboard();
    return true;
  })().then(sendResponse, () => sendResponse(false));
  return true;
});
