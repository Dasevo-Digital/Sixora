# Änderungen

App und Server haben eigene Versionsnummern. Eine App-Version setzt die
angegebene Server-Version voraus, wenn eine genannt ist. Ältere Server
funktionieren weiter, nur ohne die jeweils neuen Funktionen.

## App

### 0.1.30 – 26.10.2026 (Erweiterung 0.1.3)
- Browser-Erweiterung entsperren: Eine Erweiterung wird jetzt einmal mit
  der App verbunden. Bisher nahm die App Anfragen jedes Programms auf dem
  Rechner an (auch anderer Benutzerkonten); geschützt hat nur der Vergleich
  des Codes, und bei Touch ID achtet man darauf kaum. Jetzt fragt die App
  beim ersten Mal in ihrem Fenster, ob sie die Erweiterung verbinden soll,
  und zeigt denselben Code wie die Erweiterung. Danach genügt Touch ID bzw.
  Windows Hello, und der Schlüssel geht nur noch verschlüsselt an diese
  eine Erweiterung: Ein anderes Programm kann ihn nicht öffnen. Verbundene
  Browser stehen unter Einstellungen und lassen sich dort trennen; nach
  einer Ablehnung fragt die App eine Minute lang nicht erneut.
- Die App verrät über diese Verbindung nicht mehr, mit welchem Server und
  Konto sie angemeldet ist; die Erweiterung schickt nur einen Prüfwert.
- macOS und Windows: Ohne „Bildschirmfotos erlauben“ bleibt das
  Sixora-Fenster in Bildschirmfotos, Aufnahmen und bei der
  Bildschirmfreigabe leer, wie unter Android.
- Bibliotheken auf aktuelle Versionen, darunter die für Bilder (QR-Codes
  aus Dateien), ZIP-Archive (Importe) und SQLite.

### 0.1.29 – 19.10.2026
- Einstellungen → Über: „Sixora unterstützen“ öffnet die Ko-fi-Seite im
  Browser. Die App selbst sendet dafür nichts.

### 0.1.28 – 19.10.2026
- Schreibtisch: Die Browser-Erweiterung lässt sich über die App entsperren,
  mit Touch ID bzw. Windows Hello oder, wo es das nicht gibt, mit einer
  Bestätigung in der App. Einschalten unter Einstellungen → „Browser-
  Erweiterung entsperren“; Sixora trägt sich dann bei Chrome, Opera, Edge,
  Brave, Vivaldi und Firefox als Gegenstelle ein. Die App gibt den
  Schlüssel nur verschlüsselt an einen Einmal-Schlüssel der Erweiterung
  heraus, und beide zeigen denselben sechsstelligen Code: Fragt ein anderes
  Programm, passt er nicht. Ist Sixora gesperrt, genügt Touch ID bzw.
  Windows Hello, wenn das schnelle Entsperren eingeschaltet ist; die App
  bleibt dabei gesperrt.

### 0.1.27 – 18.10.2026 (Server 0.1.6 für den Einrichtungscode)
- Schreibtisch: Sixora sperrt sich, sobald der Bildschirm gesperrt wird
  oder der Rechner in den Ruhezustand geht, nicht erst nach der
  eingestellten Zeit ohne Eingabe. Wer den Rechner danach entsperrt, findet
  die Codes nicht offen vor. Gilt für macOS, Windows und Linux (über
  systemd-logind und den Bildschirmschoner); bei „Automatisch sperren: Nie“
  bleibt es wie bisher.
- Android-Autofill: Wählt man ein Konto, das nicht erkennbar zur App oder
  Website gehört, fragt Sixora vor dem Einsetzen nach. Eine nachgemachte
  Anmeldeseite bekommt den Code so nicht mehr mit einem Tipp.
- Android-Autofill: Die Website-Adresse zählt nur noch, wenn ein bekannter
  Browser fragt. Jede App kann in ihr Formular eine beliebige Adresse
  schreiben und hätte sich so als „github.com“ ausgeben können; bei anderen
  Apps zählt jetzt nur ihr eigener Paketname.
- Ein neuer Server fragt beim ersten Konto nach dem Einrichtungscode aus
  seinem Protokoll; die App zeigt dafür ein eigenes Feld.
- Schlüsselparameter von einem Server oder aus einer Sicherungsdatei werden
  bei mehr als 256 MiB Speicher abgelehnt (bisher 1 GiB). Ein bösartiger
  Server hätte die App mit einem riesigen Wert zum Absturz bringen können;
  Sixora selbst nutzt 64 MiB.

### 0.1.26 – 12.10.2026
- „Mit Server verbinden“ zeigt das Ergebnis jetzt auf einer eigenen Seite
  mit „Fertig“. Bisher erschien es nur kurz als Meldung, und die gleich
  danach gestellte Frage nach Touch ID bzw. Face ID verdrängte sie. Diese
  Frage kommt während der Übertragung nicht mehr; die Ergebnisseite weist
  darauf hin, dass das schnelle Entsperren für das neue Konto in den
  Einstellungen wieder eingeschaltet wird.

### 0.1.25 – 12.10.2026
- macOS: „QR-Code vom Bildschirm“ fragt nicht mehr nach der Freigabe für
  Bildschirmaufnahmen. Das Bild kam bisher aus der Bildschirmfoto-Funktion
  von ScreenCaptureKit, für die macOS die Freigabe auch dann verlangt, wenn
  das Fenster in der Systemauswahl gewählt wurde. Jetzt ist es das erste
  Bild eines kurzen Streams; dafür genügt die Auswahl.

### 0.1.24 – 10.10.2026
- Android: Codes in anderen Apps und auf Websites einfügen (Autofill).
  Sixora erkennt Felder für Einmal-Codes und bietet dort „Code aus Sixora
  einfügen“ an; ein kleines Fenster entsperrt, zeigt passende Konten zuerst
  und setzt den aktuellen Code ein. Andere Felder (Name, Passwort,
  Gutscheincode …) bleiben unberührt. Einschalten unter Einstellungen →
  „Codes in anderen Apps einfügen“.
- Ohne Server: kein Sync-Knopf mehr, und der Hinweis zum Master-Passwort
  spricht nicht mehr von einem Administrator.

### 0.1.23 – 10.10.2026
- Sixora ohne Server: „Ohne Server nutzen“ auf dem Startbildschirm. Die
  Codes bleiben verschlüsselt auf dem Gerät; dafür läuft der Code des
  Servers in der App, mit eigener Datenbank. Verschlüsselung, Papierkorb
  und Wiederherstellungsschlüssel sind dieselben. Ein Hinweis empfiehlt die
  automatische Sicherung.
- Einstellungen → „Mit Server verbinden“ überträgt alle Codes auf einen
  Server, in ein neues oder ein vorhandenes Konto. Codes, die das Konto
  schon hat, werden übersprungen; Tresore werden nach Namen zugeordnet.
  Erst wenn alles angekommen ist, werden die lokalen Daten gelöscht. Bricht
  die Übertragung ab, setzt „Weiter übertragen“ sie fort.
- Abmelden aus den Einstellungen schließt die Seite sofort; ein noch
  laufender Abgleich konnte sie vorher ohne Konto neu zeichnen.

### 0.1.22 – 10.10.2026
- QR-Codes direkt vom Bildschirm lesen, z. B. von der Einstellungsseite
  eines Dienstes im Browser: Hinzufügen → „QR-Code vom Bildschirm“. Sixora
  tritt dafür kurz zur Seite. macOS: Fenster oder Bildschirm in der
  Systemauswahl wählen, ohne Freigabe für Bildschirmaufnahmen; Linux:
  Bereich mit dem Bildschirmfoto-Werkzeug des Desktops wählen; Windows: der
  ganze Bildschirm wird durchsucht, auch in voller 4K-Auflösung.

### 0.1.21 – 10.10.2026
- Auf echten Windows- und Linux-Rechnern geprüft (Tests und Builds).
- Linux: kein globales Tastenkürzel mehr und damit keine Abhängigkeit von
  libkeybinder (die unter Wayland ohnehin nicht greift). Gezeichnet wird mit
  Skia, weil Impeller auf virtueller Grafik Eingabefelder falsch füllte.
  Der Build bricht auf neueren Distributionen nicht mehr an veralteten
  Funktionen der Infobereich-Bibliothek ab.
- Windows: Die Testvariante speichert ihre Geheimnisse ohne `chmod`, das es
  dort nicht gibt.

### 0.1.20 – 09.10.2026
- Import aus 2FAS (Sicherung ohne Passwort), Bitwarden (JSON und CSV),
  andOTP und FreeOTP+. Verschlüsselte Exporte von 2FAS, Bitwarden und
  Ente Auth werden erkannt und erklärt.

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

## Browser-Erweiterung

### 0.1.3 – 26.10.2026
- Entsperren über die Desktop-App: Beim ersten Mal „Mit der Sixora-App
  verbinden“; die App fragt in ihrem Fenster nach und zeigt denselben Code.
  Danach entsperrt Touch ID bzw. Windows Hello wie bisher. Die Erweiterung
  hat dafür einen eigenen Schlüssel; Server und Konto gehen nur als
  Prüfwert an die App. Braucht App 0.1.30.

### 0.1.2 – 19.10.2026
- „Mit Touch ID entsperren“ (bzw. Windows Hello oder „Mit der Sixora-App
  entsperren“) statt Master-Passwort, wenn die Sixora-App auf dem Rechner
  mit demselben Konto läuft und die Einstellung dort eingeschaltet ist.
  Mit Touch ID oder Windows Hello fragt die Erweiterung beim Öffnen gleich
  nach. Schließt sich das Popup, während die App fragt, öffnet die nächste
  Erweiterung entsperrt. Für Firefox und Chromium-Browser; Safari folgt.
- Chromium: Die Erweiterung hat jetzt eine feste ID. Eine bereits geladene
  entpackte Fassung bitte entfernen und neu laden; danach einmal neu
  anmelden.

### 0.1.1 – 18.10.2026
- Vor dem Einfügen eines Codes, dessen Konto nicht erkennbar zur Seite
  gehört, fragt die Erweiterung nach. Eine nachgemachte Anmeldeseite bekommt
  den Code so nicht mit einem Klick.
- Der Code geht nur noch an die Seite, die beim Öffnen von Sixora angezeigt
  wurde: Hat der Tab inzwischen zu einer anderen Adresse gewechselt, setzt
  die Erweiterung nichts ein. Eingebettete Rahmen anderer Websites (Werbung,
  Widgets) bekommen den Code nie.

### 0.1.0 – 10.10.2026
- Erste Version für Firefox, Safari und Chromium-Browser (Chrome, Edge,
  Opera, Brave, Vivaldi): Anmeldung am eigenen Server, Codes mit
  Restzeit, Kopieren und Einfügen in das Code-Feld der Seite (auch Felder
  mit einem Kästchen je Ziffer), passende Konten zuerst. Sie liest nur;
  Konten werden in den Apps angelegt.
- Dieselbe Verschlüsselung wie die Apps (gemeinsamer Kern als
  WebAssembly). Im Browser-Profil liegt nichts im Klartext, auch das
  Sitzungs-Token nicht; entsperrt bleibt sie bis zur eingestellten Zeit
  oder bis der Browser schließt.
- Sie fragt nur nach Zugriff auf den eigenen Server und auf den aktiven
  Tab, wenn man sie öffnet.

## Server

### 0.1.7 – 26.10.2026
- Fehlversuche bei der Anmeldung zählen pro Konto und Adresse. Bisher
  sperrten 10 falsche Versuche das Konto für alle; wer einen Benutzernamen
  kannte, konnte dessen Inhaber so aussperren. Jetzt sperren sie nur die
  Adresse, von der sie kamen; aus allen Adressen zusammen bleiben es
  höchstens 100 Versuche in 15 Minuten.
- Bibliotheken auf aktuelle Versionen (SQLite, shelf).

### 0.1.6 – 18.10.2026
- Das erste Konto braucht einen Einrichtungscode. Bisher wurde Administrator,
  wer sich zuerst registrierte; war ein neuer Server schon aus dem Netz
  erreichbar, konnte das ein Fremder sein. Der Server schreibt den Code
  beim Start ins Protokoll (`journalctl -u sixora` bzw. `docker logs
  sixora`), `setup-code` erzeugt einen neuen, und mit `SIXORA_SETUP_CODE`
  lässt er sich vorgeben. Server mit Benutzern sind nicht betroffen.
- Argon2-Parameter über 256 MiB Speicher werden bei der Registrierung
  abgelehnt, passend zur Grenze der Apps.

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
