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
  öffnet), Zwischenablage und Zeitgeber sowie der eigene Server. Den Zugriff
  auf den Server erfragt die Anmeldung, und zwar nur für diese eine Adresse;
  Zugriff auf alle Websites braucht die Erweiterung nicht. Chromium nutzt
  zum zeitversetzten Leeren zusätzlich ein unsichtbares Erweiterungsdokument.
- Kopiert Sixora einen Code, merkt sich die Erweiterung ihn 30 Sekunden im
  flüchtigen Sitzungsspeicher. Danach liest sie die Zwischenablage und leert
  sie nur, wenn dort noch genau dieser Code steht. Später kopierte Inhalte
  bleiben erhalten. Das ist in Firefox und Chromium geprüft. Safari erlaubt
  das Lesen der Zwischenablage im Hintergrund derzeit nicht; dort kann die
  Erweiterung das zeitversetzte sichere Leeren nicht garantieren. Browser
  können außerdem den Verlauf oder die geräteübergreifende Zwischenablage
  des Betriebssystems nicht abschalten.
- Entsperren über die Desktop-App („Mit Touch ID entsperren“): Ist in der
  Sixora-App unter Einstellungen „Browser-Erweiterung entsperren“
  eingeschaltet, fragt die Erweiterung die App per Native Messaging. Beim
  ersten Mal verbindet die App die Erweiterung (beide zeigen denselben
  Code); dafür hat die Erweiterung ein eigenes Schlüsselpaar in
  `storage.local`. Danach gibt die App den Benutzerschlüssel nur noch an
  diesen Schlüssel versiegelt heraus, und Server und Konto gehen nur als
  Prüfwert über die Verbindung. Der
  Browser startet dafür das Sixora-Programm (macOS) bzw. `sixora-bridge`
  (Windows, Linux), das die Bytes nur an die laufende App auf 127.0.0.1
  weiterreicht. Die App bestätigt mit Touch ID, Windows Hello oder einem
  Dialog. `background.js` hält die Verbindung, weil sich das Popup schließt,
  sobald Touch ID den Fokus nimmt; die Antwort wartet dann in
  `storage.session` auf das nächste Popup. Safari kann per Native
  Messaging nur seine eigene Hülle erreichen und geht deshalb ohne.
- In Chromium-Browsern hat die Erweiterung eine feste ID
  (`dgnhcjdoiadiehcdiimmkopdhpkgfbek`, aus dem Schlüssel im Manifest), auch
  entpackt: Die App nennt sie in ihrem Host-Manifest.
- Einsetzen: Der Code geht nur an die Seite, die beim Öffnen des Popups
  angezeigt wurde, und nur in Rahmen dieser Adresse, nicht in eingebettete
  Rahmen anderer Websites. Passt das Konto nicht erkennbar zur Seite, fragt
  die Erweiterung vorher nach.

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

`e2e_chromium.dart` (Opera ohne Fenster) prüft zusätzlich das Entsperren
über die Desktop-App: Als Gegenstelle läuft eine gespielte App im
Testprozess, der Browser erreicht sie über das echte Sixora-Programm
(`/Applications/Sixora Dev.app`, sonst `SIXORA_HOST_BINARY`). Das
Host-Manifest liegt für die Dauer des Tests in Chromes Ordner, den auch
Opera liest.

`e2e_firefox.dart` startet einen Firefox ohne Fenster mit eigenem
Wegwerf-Profil. Dort meldet sich die Erweiterung an, zeigt die Codes,
sperrt und entsperrt; außerdem prüft der Test das Einsetzen in
verschiedene Code-Felder.
