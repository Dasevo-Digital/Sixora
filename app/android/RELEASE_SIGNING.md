# Android-Release signieren

Produkt-APKs müssen denselben Schlüssel wie alle bereits veröffentlichten
Versionen tragen. Der erwartete öffentliche Fingerabdruck steht in
`release-cert-sha256.txt`. Ein anderer Schlüssel würde bestehende
Installationen von Updates abschneiden.

Gradle liest Schlüssel und Kennwörter ausschließlich zur Laufzeit aus:

- `SIXORA_ANDROID_KEYSTORE`
- `SIXORA_ANDROID_KEY_ALIAS`
- `SIXORA_ANDROID_STORE_PASSWORD`
- `SIXORA_ANDROID_KEY_PASSWORD`

Fehlt einer dieser Werte, bricht ein Produkt-Release ab. Die Dev-Variante
behält ihre eigene Paketkennung und darf weiterhin den Android-Debugschlüssel
verwenden.

Der öffentliche CI-Lauf erzeugt nur kurzlebig signierte Dateien mit der Endung
`.stage.apk`. Diese Dateien sind nicht zur Veröffentlichung bestimmt. Auf dem
Release-Rechner signiert `app/tool/sign_android.sh` sie mit dem bestehenden
Produktschlüssel neu, prüft danach den Zertifikatsfingerabdruck und entfernt
bei einer Abweichung die erzeugte APK wieder. Zugangsdaten werden weder als
Argument noch in Projektdateien gespeichert.
