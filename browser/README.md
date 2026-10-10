# Sixora für den Browser

Erweiterung für Firefox, Safari und Chromium-Browser (Chrome, Edge, Opera,
Brave, Vivaldi). Sie zeigt die Codes eines Sixora-Kontos, kopiert sie und
setzt sie in das Code-Feld der aktuellen Seite ein. Konten anlegen und
ändern geht in den Apps; die Erweiterung liest nur.

## Aufbau

- Das Popup ist Dart, nach WebAssembly übersetzt (`web/popup.dart`). Es
  nutzt `sixora_core` wie die Apps: dieselbe Anmeldung, dieselbe
  Verschlüsselung, derselbe Abgleich. Der Server sieht auch hier nur
  verschlüsselte Daten.
- `static/bridge.js` verbindet das Popup mit den Browser-Schnittstellen und
  enthält die Funktion, die den Code in die Seite einsetzt.
- Im Browser-Profil liegen Konto, Sitzung und Tresore nur verschlüsselt,
  auch das Sitzungs-Token. Entsperrt hält die Erweiterung den
  Benutzerschlüssel in `storage.session`. Der Browser hält diesen Speicher
  nur im Arbeitsspeicher und vergisst ihn beim Beenden. Nach der
  eingestellten Zeit sperrt die Erweiterung wieder.
- Berechtigungen: Speicher, der aktive Tab (erst wenn man die Erweiterung
  öffnet) und der eigene Server. Den Zugriff auf den Server erfragt die
  Anmeldung, und zwar nur für diese eine Adresse; Zugriff auf alle
  Websites braucht die Erweiterung nicht.

## Bauen

```sh
browser/tool/build.sh     # build/{chromium,firefox,safari} und ZIP-Dateien
browser/tool/safari.sh    # danach: Mac-App mit der Safari-Erweiterung
```

Zum Ausprobieren ohne Store:

- **Chromium-Browser:** `chrome://extensions` (bzw. `opera://extensions`,
  `edge://extensions`) → Entwicklermodus → „Entpackte Erweiterung laden“ →
  `browser/build/chromium`.
- **Firefox:** `about:debugging#/runtime/this-firefox` → „Temporäres
  Add-on laden“ → `browser/build/firefox/manifest.json`. Dauerhaft geht das
  nur mit einer von Mozilla signierten Fassung.
- **Safari:** `browser/build/safari.noindex/Sixora für Safari.app` einmal
  öffnen, dann Safari → Einstellungen → Erweiterungen → Sixora einschalten.
  Ohne bezahltes Apple-Entwicklerkonto zusätzlich in Safari unter
  Entwickler „Nicht signierte Erweiterungen erlauben“ (gilt bis zum
  Beenden von Safari).

## Prüfen

```sh
cd browser
dart test                      # Logik gegen einen Server im Testprozess
tool/build.sh && dart run tool/e2e_firefox.dart
```

`e2e_firefox.dart` startet einen Firefox ohne Fenster mit eigenem
Wegwerf-Profil. Dort meldet sich die Erweiterung an, zeigt die Codes,
sperrt und entsperrt; außerdem prüft der Test das Einsetzen in
verschiedene Code-Felder.
