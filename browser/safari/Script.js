// The small Mac app around the Safari extension: says whether the
// extension is on and opens Safari's settings. Replaces the converter's
// English template (tool/safari.sh), in German, English and Spanish.
const texts = {
  de: {
    unknown: "Schalte Sixora in Safari unter Einstellungen → Erweiterungen ein.",
    on: "Sixora ist in Safari eingeschaltet. Öffne Sixora über das Symbol in der Symbolleiste.",
    off: "Sixora ist in Safari noch ausgeschaltet. Schalte es unter Einstellungen → Erweiterungen ein.",
    open: "Beenden und Safari-Einstellungen öffnen …",
  },
  en: {
    unknown: "Turn on Sixora in Safari under Settings → Extensions.",
    on: "Sixora is on in Safari. Open it with its icon in the toolbar.",
    off: "Sixora is still off in Safari. Turn it on under Settings → Extensions.",
    open: "Quit and Open Safari Settings…",
  },
  es: {
    unknown: "Activa Sixora en Safari en Ajustes → Extensiones.",
    on: "Sixora está activado en Safari. Ábrelo con su icono en la barra de herramientas.",
    off: "Sixora aún está desactivado en Safari. Actívalo en Ajustes → Extensiones.",
    open: "Salir y abrir los ajustes de Safari…",
  },
};
const t = texts[navigator.language.slice(0, 2)] ?? texts.en;
document.querySelector(".state-unknown").innerText = t.unknown;
document.querySelector(".state-on").innerText = t.on;
document.querySelector(".state-off").innerText = t.off;
document.querySelector("button.open-preferences").innerText = t.open;

// Called by the app's ViewController.
function show(enabled) {
  if (typeof enabled === "boolean") {
    document.body.classList.toggle("state-on", enabled);
    document.body.classList.toggle("state-off", !enabled);
  } else {
    document.body.classList.remove("state-on");
    document.body.classList.remove("state-off");
  }
}

function openPreferences() {
  webkit.messageHandlers.controller.postMessage("open-preferences");
}

document.querySelector("button.open-preferences").addEventListener("click", openPreferences);
