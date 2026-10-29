# Technische Datenschutzbeschreibung

Sixora enthält keine Werbung, Analysebibliothek oder automatische
Fehlerübermittlung. Eine Verbindung entsteht nur zum eingestellten
Sixora-Server und zu Seiten, die der Benutzer ausdrücklich über einen Link
öffnet.

## Auf dem Gerät

OTP-Geheimnisse, Tresornamen und private Schlüssel liegen außerhalb des
Arbeitsspeichers nur verschlüsselt vor. Sitzungsschlüssel und – falls
eingeschaltet – der Schlüssel zum schnellen Entsperren liegen im sicheren
Speicher des Betriebssystems. Fehlt unter Linux ein solcher Speicher, wird nur
das Sitzungstoken in einer Datei mit Rechten `0600` abgelegt; schnelles
Entsperren ist dann nicht verfügbar.

Einstellungen, verschlüsselte Zwischenspeicher und die lokale Datenbank liegen
im privaten App-Verzeichnis. Auf macOS und Linux setzt Sixora dafür zusätzlich
Verzeichnisrechte `0700` und Dateirechte `0600`.

Die Browser-Erweiterung speichert die für sie versiegelte Kontoschlüsselkopie
im Profilspeicher des Browsers. Sie lässt sich nur über das Master-Passwort
oder eine ausdrücklich verbundene und bestätigte Desktop-App öffnen.

## Auf dem Server sichtbare Daten

Der Server sieht keine Klartext-Codes, Tresornamen oder privaten Schlüssel. Er
verarbeitet und speichert jedoch folgende Metadaten:

- Benutzername, Kontorolle und Sperrstatus,
- Gerätebezeichnung, Plattform, Sitzungszeitpunkte und IP-Adresse,
- Eigentümer, Mitglieder und Rollen eines Tresors,
- Erstellungs-, Änderungs- und Löschzeitpunkte,
- Anzahl, Größe und Änderungsrhythmus verschlüsselter Datensätze,
- Verwaltungsereignisse und die dabei verwendete IP-Adresse.

Damit lassen sich Nutzungsmuster und Beziehungen zwischen Konten erkennen,
auch wenn die Inhalte verschlüsselt bleiben. Der Betreiber des Servers ist für
Zugriffsschutz, Protokolle, Sicherungen und deren Aufbewahrung verantwortlich.

## Aufbewahrung und Löschen

- Sitzungen verfallen nach 180 Tagen ohne Nutzung oder werden beim Abmelden,
  Passwortwechsel bzw. durch den Benutzer widerrufen.
- Das Verwaltungsprotokoll wird 365 Tage aufbewahrt.
- Gelöschte Einträge bleiben 30 Tage verschlüsselt im Papierkorb.
- Tägliche Datenbankkopien bleiben standardmäßig 14 Tage erhalten; der
  Betreiber kann diese Frist ändern oder Sicherungen abschalten.
- Beim Löschen eines Kontos entfernt die Datenbank dessen Benutzer-, Sitzungs-
  und Tresordaten. Bereits angelegte Sicherungskopien verschwinden erst nach
  der für sie geltenden Aufbewahrungsfrist.

## Externe Links und Plattformdienste

Service-Symbole sind in der App enthalten und werden nicht aus dem Internet
nachgeladen. Betriebssystemfunktionen wie Schlüsselbund, Biometrie, Kamera,
Dateiauswahl und Autofill laufen nach den Regeln der jeweiligen Plattform.
Ein Unterstützungslink öffnet erst nach einem ausdrücklichen Tipp die
zugehörige Webseite im Standardbrowser.
