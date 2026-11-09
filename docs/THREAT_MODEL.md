# Bedrohungsmodell

## Schützenswerte Werte

Sixora schützt OTP-Geheimnisse, private Schlüssel von Passkeys, Master- und
Wiederherstellungsschlüssel, Benutzer- und Tresorschlüssel, Sitzungen sowie
die Verfügbarkeit und Vollständigkeit verschlüsselter Tresordaten.

## Vertrauensgrenzen

- **Client:** Ent- und verschlüsselt Inhalte. Ein entsperrter, kompromittierter
  Client kann alle für dieses Konto sichtbaren Codes auslesen.
- **Betriebssystem:** Schlüsselbund, Biometrie, Zwischenablage, Kamera,
  Dateiauswahl und Autofill sind Teil der vertrauenswürdigen Plattform.
- **Server:** Darf neugierig oder fehlerhaft sein. Er soll keine Klartextdaten
  erhalten und verschlüsselte Einträge nicht unbemerkt vertauschen können.
  Er kann Verfügbarkeit verweigern, alte verschlüsselte Daten ausliefern und
  Metadaten beobachten.
- **Transport und Reverse-Proxy:** TLS schützt Daten und Sitzungstoken auf dem
  Weg. Ein falsch konfigurierter vertrauenswürdiger Proxy kann IP-basierte
  Grenzen umgehen oder falsche Adressen protokollieren.
- **Browser-Erweiterung:** Hat ein eigenes Schlüsselpaar in ihrem lokalen
  Browser-Speicher. Eine neue Erweiterung muss in der Desktop-App anhand eines
  übereinstimmenden Codes bestätigt werden; danach bekommt sie den
  Kontoschlüssel nur versiegelt für diesen öffentlichen Schlüssel. Sie darf die
  Zwischenablage lesen, um einen kopierten Code nach 30 Sekunden nur dann zu
  entfernen, wenn dort noch derselbe steht.
- **Websites bei eingeschalteten Passkeys:** Nicht vertrauenswürdig. Das
  Skript in der Seite hält keine Schlüssel. Die Herkunft einer Anfrage stammt
  vom Browser; eine Seite erreicht nur Passkeys ihrer eigenen Domain oder
  deren übergeordneter Domains und kann nicht erfahren, ob für andere Websites
  welche existieren. Jede Nutzung braucht eine Bestätigung in einem Fenster der
  Erweiterung, das die vom Browser genannte Adresse zeigt.
- **Lokale Verbindung zur Desktop-App:** Die App lauscht auf 127.0.0.1; jedes
  Programm des Rechners, auch anderer Benutzerkonten, kann sie erreichen. Sie
  verrät dort weder Server noch Konto (nur ein Prüfwert wird verglichen),
  fragt nach einer abgelehnten Kopplung eine Minute lang nicht erneut und
  gibt den Kontoschlüssel nur an bestätigte Schlüssel heraus. Ein Programm
  desselben Benutzers kann den Schlüssel einer Erweiterung aus dem
  Browser-Profil lesen und fällt unter „kompromittiertes Gerät“.
- **Sicherungen:** Enthalten verschlüsselte Codes und brauchen ein eigenes
  Passwort. Verlust des Sicherungspassworts oder Wiederherstellungsschlüssels
  ist nicht rückgängig zu machen.

## Schutzmaßnahmen

- Argon2id begrenzt Offline-Passwortversuche; Mindest- und Höchstwerte
  verhindern absichtlich schwache oder speichererschöpfende Parameter.
- HKDF trennt Anmeldung und Schlüsselverschlüsselung.
- XChaCha20-Poly1305 bindet Einträge über zusätzliche authentifizierte Daten
  an Tresor und Eintragskennung.
- X25519 versiegelt jeden Tresorschlüssel getrennt für seine Mitglieder.
- Der Server speichert Sitzungs- und Anmeldeschlüssel nur gehasht, begrenzt
  Anmeldeversuche und antwortet bei unbekannten Konten mit stabilen
  Scheinparametern.
- Schlüssel werden beim Sperren aus den verwalteten Puffern überschrieben.
- Papierkorb, Schlüsselrotation, atomare lokale Schreibvorgänge und geprüfte
  Datenbankkopien schützen vor Bedien- und Speicherfehlern.

## Nicht vollständig lösbare Risiken

- Ein zuvor berechtigtes Mitglied kann bereits gelesene OTP-Geheimnisse und
  Passkeys behalten. Nach einem Ausschluss müssen die betroffenen Dienste neue
  Geheimnisse ausstellen bzw. den Passkey widerrufen.
- Synchronisierte Passkeys haben keinen Signaturzähler. Eine Website kann eine
  Kopie des Schlüssels daran nicht erkennen.
- Ein kompromittiertes entsperrtes Gerät, manipuliertes Betriebssystem oder
  eine bösartige Bildschirm-/Eingabehilfe liegt außerhalb der kryptografischen
  Schutzgrenze.
- Der Server sieht die in `PRIVACY.md` aufgeführten Metadaten und kann den
  Dienst blockieren oder Daten löschen. Sicherungen schützen die
  Verfügbarkeit, nicht die Metadaten.
- Selbst gehostete TLS-, Proxy-, Firewall- und Sicherungskonfigurationen sind
  Teil der Verantwortung des Betreibers.
- Das Design und seine Implementierung wurden nicht unabhängig formal
  verifiziert. Tests und Codeprüfung ersetzen kein externes Kryptografieaudit.
