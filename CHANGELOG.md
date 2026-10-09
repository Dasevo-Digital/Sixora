# Änderungen

App und Server haben eigene Versionsnummern. Eine App-Version setzt die
angegebene Server-Version voraus, wenn eine genannt ist. Ältere Server
funktionieren weiter, nur ohne die jeweils neuen Funktionen.

## App

### 0.1.19 – 09.10.2026
- Sixora spricht Deutsch, Englisch und Spanisch. Die Sprache folgt dem
  System (sonst Englisch) und lässt sich unter Einstellungen → Sprache
  festlegen. Übersetzt sind auch Fehlermeldungen von Server und Import,
  die Berechtigungsfragen von iOS und macOS sowie das macOS-Menü.

### 0.1.18 – 09.10.2026
- Bildschirmleser (VoiceOver, TalkBack): Jedes Konto wird mit Name, Konto,
  dem Code Ziffer für Ziffer und der Restzeit vorgelesen; verborgene Codes
  bleiben verborgen. Logos und Countdown werden nicht einzeln angesagt.
- Große Schrift: Der Code bleibt auf einer Zeile. Getestet mit 200 % auf
  einem schmalen Telefon.
- Die Blätterknöpfe der QR-Ansicht sind beschriftet.

### 0.1.17 – 09.10.2026
- macOS: Das App-Menü ist deutsch.

### 0.1.16 – 09.10.2026
- Touch ID und Windows Hello starten auf dem Schreibtisch erst auf
  Knopfdruck, nicht mehr von selbst beim Sperren.

### 0.1.15 – 09.10.2026
- Face ID fragt beim Entsperren nur noch einmal. Die Abfrage startete
  bisher, bevor die App wieder aktiv war; iOS brach sie ab und zeigte sie
  erneut.

### 0.1.14 – 09.10.2026 (Server 0.1.5)
- Öffentliche Schlüssel von Tresor-Mitgliedern werden festgehalten. Liefert
  der Server später einen anderen, bricht die App das Teilen bzw. die
  Schlüsselerneuerung ab und warnt.
- Automatische Sicherungen werden nach dem Schreiben wieder eingelesen.
  Neu: „Sicherung prüfen“.

### 0.1.13 – 09.10.2026 (erstes Release)
- Die Meldung „… gelöscht – Rückgängig“ verschwindet wieder von selbst.
- iOS: Nach dem Sperren ist im App-Umschalter und beim Zurückkehren nichts
  mehr von den Codes zu sehen (nativer Sichtschutz).

### 0.1.12 – 09.10.2026
- macOS: Sixora lässt sich für `otpauth://`-Links eintragen (bisher öffnete
  sie Apples Passwörter-App). Systemdialoge erscheinen auf Deutsch.

### 0.1.11 – 09.10.2026
- macOS: Ctrl+Klick öffnet das Kontextmenü.

### 0.1.10 – 09.10.2026
- Alle Eingabefelder haben ein Kontextmenü mit „Einfügen“.
- Das Menü in Menüleiste bzw. Infobereich zeigt nur noch Favoriten und
  „Suchen …“.

### 0.1.9 – 09.10.2026 (Server 0.1.4)
- Hinweis auf allen Geräten, wenn sich ein neues Gerät anmeldet, mit
  „Abmelden“.
- Verlässt jemand einen geteilten Tresor, bekommt er einen neuen Schlüssel.
- Automatische verschlüsselte Sicherung in einen Ordner nach Wahl.
- Kontenprüfung: doppelte, kurze und ungültige Schlüssel, Konten ohne Namen
  oder Logo.

### 0.1.8 – 09.10.2026
- Änderungen anderer Geräte erscheinen sofort, ohne Sync-Knopf.

### 0.1.7 – 09.10.2026 (Server 0.1.3)
- Symbol in Menüleiste bzw. Infobereich, Tastenkürzel ⌥⌘O bzw. Strg+Alt+O.
- `otpauth://`-Links öffnen Sixora, Einladungen als QR-Code und Link.
- Papierkorb: gelöschte Konten 30 Tage lang wiederherstellbar.
- Sofort-Abgleich zwischen den Geräten.
- Kopierte Codes gelten als vertraulich (kein Verlauf, keine Übertragung).

### 0.1.6 – 09.10.2026
- Der Ausweg aus Face ID & Co. führt zum Sixora-Master-Passwort, nicht zum
  Gerätepasswort.

### 0.1.5 – 09.10.2026
- Logos der Dienste (Simple Icons), im Editor wählbar.

### 0.1.4 – 08.10.2026
- Entsperren mit Face ID, Touch ID, Fingerabdruck und Windows Hello.

### 0.1.3 – 07.10.2026
- Import der Google-Authenticator-Übertragung mit mehreren QR-Codes, auch
  aus Bildern.

### 0.1.2 – 06.10.2026
- Einfügen in Passwort- und Schlüsselfelder.

### 0.1.1 – 06.10.2026
- Ein DNS-Fehler wird als solcher gemeldet, nicht als Serverausfall.

### 0.1.0 – 06.10.2026
- Erste Version: TOTP, HOTP und Steam, Ende-zu-Ende-verschlüsselt auf dem
  eigenen Server, geteilte Tresore, Import und Export, Apps für iOS,
  Android, macOS, Windows und Linux.

## Server

### 0.1.5 – 09.10.2026
- Bekannte Schlüssel je Konto, verschlüsselt gespeichert (Schema 4).
- Jede Tageskopie wird nach dem Schreiben geprüft; neuer Befehl
  `verify-backup`.

### 0.1.4 – 09.10.2026
- Sitzungen im Sync, neue Anmeldungen wecken die anderen Geräte.
- Schlüsselerneuerung für Tresore (Schema 3).

### 0.1.3 – 09.10.2026
- Papierkorb, Sofort-Sync (Long-Poll), tägliche Datenbankkopie (Schema 2).

### 0.1.2 – 09.10.2026
- Neue Startseite; Härtung nach OWASP (Sicherheits-Header, keine Angaben
  zur eingesetzten Technik).

### 0.1.1 – 06.10.2026
- Hinter einem Reverse-Proxy zählt die Adresse, die der Proxy gesehen hat.

### 0.1.0 – 06.10.2026
- Erste Version: Konten, Tresore, Sync, Einladungen, Verwaltung.
