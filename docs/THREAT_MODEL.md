# Bedrohungsmodell

## Schützenswerte Werte

Sixora schützt OTP-Geheimnisse, Master- und Wiederherstellungsschlüssel,
Benutzer- und Tresorschlüssel, Sitzungen sowie die Verfügbarkeit und
Vollständigkeit verschlüsselter Tresordaten.

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
- **Browser-Erweiterung:** Bekommt nur einen für ihren einmaligen öffentlichen
  Schlüssel versiegelten Kontoschlüssel. Eine neue Erweiterung muss in der
  Desktop-App anhand eines übereinstimmenden Codes bestätigt werden.
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

- Ein zuvor berechtigtes Mitglied kann bereits gelesene OTP-Geheimnisse
  behalten. Nach einem Ausschluss müssen die betroffenen Dienste neue
  Geheimnisse ausstellen.
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
