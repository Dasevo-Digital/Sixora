// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Sixora';

  @override
  String get signedOut => 'Abgemeldet';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get backupPasswordTitle => 'Passwort für die Sicherung';

  @override
  String get backupPasswordHint =>
      'Mindestens 10 Zeichen. Ohne dieses Passwort lässt sich die Sicherung nicht öffnen.';

  @override
  String get password => 'Passwort';

  @override
  String get continueAction => 'Weiter';

  @override
  String get passwordTooShort => 'Das Passwort braucht mindestens 10 Zeichen';

  @override
  String get repeatPassword => 'Passwort wiederholen';

  @override
  String get passwordsDoNotMatch => 'Die Passwörter stimmen nicht überein';

  @override
  String get paste => 'Einfügen';

  @override
  String get selectAll => 'Alles auswählen';

  @override
  String get clipboardEmpty => 'Die Zwischenablage ist leer';

  @override
  String get hide => 'Verbergen';

  @override
  String get show => 'Anzeigen';

  @override
  String get strengthWeak => 'Schwach';

  @override
  String get strengthFair => 'Mittel';

  @override
  String get strengthGood => 'Gut';

  @override
  String get strengthVeryGood => 'Sehr gut';

  @override
  String get enterSixoraMasterPassword =>
      'Bitte das Sixora-Master-Passwort eingeben.';

  @override
  String get signOutQuestion => 'Abmelden?';

  @override
  String get signOutLocalCopyMessage =>
      'Die lokale Kopie wird von diesem Gerät entfernt. Deine Codes bleiben auf dem Server und auf deinen anderen Geräten erhalten.';

  @override
  String get signOut => 'Abmelden';

  @override
  String get locked => 'Gesperrt';

  @override
  String get unlock => 'Entsperren';

  @override
  String unlockWith(Object method) {
    return 'Mit $method entsperren';
  }

  @override
  String get notAnInviteCode => 'Das ist kein Sixora-Einladungscode';

  @override
  String get usernameTooShort => 'Benutzername: mindestens 3 Zeichen';

  @override
  String get masterPasswordTooShort =>
      'Das Master-Passwort braucht mindestens 10 Zeichen';

  @override
  String get enterUsernameAndPassword =>
      'Benutzername und Master-Passwort eingeben';

  @override
  String get tagline =>
      'Deine Einmal-Codes, Ende-zu-Ende-verschlüsselt auf deinem eigenen Server.';

  @override
  String get serverAddressOrInvite => 'Server-Adresse oder Einladungslink';

  @override
  String get connect => 'Verbinden';

  @override
  String get scanInviteQr => 'Einladungs-QR-Code scannen';

  @override
  String get change => 'Ändern';

  @override
  String get signIn => 'Anmelden';

  @override
  String get register => 'Registrieren';

  @override
  String get forgotten => 'Vergessen';

  @override
  String get newServerFirstAdmin =>
      'Dieser Server ist neu. Das erste Konto wird Administrator.';

  @override
  String get username => 'Benutzername';

  @override
  String get recoveryKey => 'Wiederherstellungsschlüssel';

  @override
  String get newMasterPassword => 'Neues Master-Passwort';

  @override
  String get masterPassword => 'Master-Passwort';

  @override
  String strengthLabel(Object strength) {
    return 'Stärke: $strength';
  }

  @override
  String get repeatMasterPassword => 'Master-Passwort wiederholen';

  @override
  String get inviteCode => 'Einladungscode';

  @override
  String get masterPasswordNeverLeaves =>
      'Das Master-Passwort verlässt nie dieses Gerät und kann von niemandem zurückgesetzt werden – auch nicht vom Administrator. Nur mit dem Wiederherstellungsschlüssel kommst du ohne Passwort wieder hinein.';

  @override
  String get createAccount => 'Konto erstellen';

  @override
  String get setNewPassword => 'Neues Passwort setzen';

  @override
  String get generatingKeys => 'Schlüssel werden erzeugt …';

  @override
  String get keyInvalidShort => 'Schlüssel ungültig';

  @override
  String get codeHidden => 'Code verborgen';

  @override
  String spokenCode(Object digits) {
    return 'Code $digits';
  }

  @override
  String secondsLeft(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'noch $seconds Sekunden',
      one: 'noch 1 Sekunde',
    );
    return '$_temp0';
  }

  @override
  String get showCode => 'Code anzeigen';

  @override
  String get copyCode => 'Code kopieren';

  @override
  String get moreActions => 'Weitere Aktionen';

  @override
  String nextCodeLabel(Object code) {
    return 'Nächster: $code';
  }

  @override
  String get keyIsInvalid => 'Schlüssel ist ungültig';

  @override
  String get nextCode => 'Nächster Code';

  @override
  String get more => 'Mehr';

  @override
  String get code => 'Code';

  @override
  String copied(Object what) {
    return '$what kopiert';
  }

  @override
  String copiedClearsSoon(Object what) {
    return '$what kopiert – wird nach 30 s aus der Zwischenablage entfernt';
  }

  @override
  String serverVersion(Object version) {
    return 'Version $version';
  }

  @override
  String get noHttpsWarning => 'Ohne HTTPS – nur im eigenen Netz verwenden!';

  @override
  String get settings => 'Einstellungen';

  @override
  String get sectionSecurity => 'Sicherheit';

  @override
  String get autoLock => 'Automatisch sperren';

  @override
  String get quickUnlockHardwareHint =>
      'Statt des Master-Passworts. Der Schlüssel ist an die Biometrie dieses Geräts gebunden; wird ein neuer Finger oder ein neues Gesicht registriert, braucht es wieder das Passwort.';

  @override
  String get quickUnlockKeychainHint =>
      'Statt des Master-Passworts. Der Schlüssel liegt dafür im Schlüsselbund dieses Geräts.';

  @override
  String get hideCodes => 'Codes verbergen';

  @override
  String get hideCodesHint => 'Erst nach Antippen anzeigen';

  @override
  String get clearClipboard => 'Zwischenablage leeren';

  @override
  String get clearClipboardHint => 'Kopierte Codes nach 30 Sekunden entfernen';

  @override
  String get allowScreenshots => 'Bildschirmfotos erlauben';

  @override
  String get allowScreenshotsHint =>
      'Sonst sind Screenshots und Bildschirmaufnahmen gesperrt';

  @override
  String get changeMasterPassword => 'Master-Passwort ändern';

  @override
  String get newRecoveryKey => 'Neuer Wiederherstellungsschlüssel';

  @override
  String get newRecoveryKeyHint => 'Der bisherige wird ungültig';

  @override
  String get signedInDevices => 'Angemeldete Geräte';

  @override
  String get trash => 'Papierkorb';

  @override
  String get trashHint => 'Gelöschte Konten der letzten 30 Tage';

  @override
  String get activity => 'Aktivitäten';

  @override
  String get activityHint => 'Anmeldungen und Änderungen am Konto';

  @override
  String get sectionDesktop => 'Schreibtisch';

  @override
  String get keepInMenuBar => 'In der Menüleiste weiterlaufen';

  @override
  String get keepInTray => 'Im Infobereich weiterlaufen';

  @override
  String get keepInTrayHint =>
      'Beim Schließen des Fensters bleibt Sixora erreichbar. Über das Symbol lassen sich die Codes der Favoriten kopieren oder alle Konten durchsuchen.';

  @override
  String shortcutTitle(Object shortcut) {
    return 'Tastenkürzel $shortcut';
  }

  @override
  String get shortcutHint =>
      'Holt Sixora von überall nach vorn, mit dem Cursor in der Suche.';

  @override
  String get sectionDisplay => 'Anzeige';

  @override
  String get showNextCode => 'Nächsten Code anzeigen';

  @override
  String get showNextCodeHint => 'In den letzten 5 Sekunden eines Codes';

  @override
  String get appearance => 'Erscheinungsbild';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get sectionVaultsData => 'Tresore und Daten';

  @override
  String get vaultsAndSharing => 'Tresore und Teilen';

  @override
  String get importAction => 'Importieren';

  @override
  String get exportAction => 'Exportieren';

  @override
  String get exportHint => 'Verschlüsselte Sicherung, Textdatei oder QR-Codes';

  @override
  String get autoBackup => 'Automatische Sicherung';

  @override
  String get off => 'Aus';

  @override
  String errorWith(Object error) {
    return 'Fehler: $error';
  }

  @override
  String backupFolderLast(Object folder, Object time) {
    return '$folder · zuletzt $time';
  }

  @override
  String get accountCheck => 'Kontenprüfung';

  @override
  String get accountCheckHint =>
      'Doppelte Konten, schwache Schlüssel, fehlende Logos';

  @override
  String get sectionServer => 'Server';

  @override
  String get administration => 'Verwaltung';

  @override
  String get administrationHint => 'Benutzer, Einladungen, Protokoll';

  @override
  String get sectionAccount => 'Konto';

  @override
  String get signOutHint => 'Entfernt die lokale Kopie von diesem Gerät';

  @override
  String get signOutMessage =>
      'Deine Codes bleiben auf dem Server. Zum erneuten Anmelden brauchst du Benutzername und Master-Passwort.';

  @override
  String get deleteAccount => 'Konto löschen';

  @override
  String get sectionAbout => 'Über';

  @override
  String get currentPassword => 'Aktuelles Passwort';

  @override
  String get newPassword => 'Neues Passwort';

  @override
  String get newPasswordHint =>
      'Mindestens 10 Zeichen. Andere Geräte werden abgemeldet.';

  @override
  String get repeatNewPassword => 'Neues Passwort wiederholen';

  @override
  String get newPasswordTooShort =>
      'Das neue Passwort braucht mindestens 10 Zeichen';

  @override
  String get newPasswordsDoNotMatch =>
      'Die neuen Passwörter stimmen nicht überein';

  @override
  String get changingPassword => 'Passwort wird geändert …';

  @override
  String get masterPasswordChanged =>
      'Master-Passwort geändert. Andere Geräte müssen sich neu anmelden.';

  @override
  String get newRecoveryKeyConfirm =>
      'Zur Bestätigung das Master-Passwort eingeben. Der bisherige Schlüssel wird ungültig.';

  @override
  String get generate => 'Erzeugen';

  @override
  String get deleteAccountQuestion => 'Konto endgültig löschen?';

  @override
  String get deleteAccountMessage =>
      'Alle deine Codes und die Tresore, die dir gehören – auch geteilte –, werden auf dem Server gelöscht. Das lässt sich nicht rückgängig machen. Deaktiviere vorher die Zwei-Faktor-Anmeldung bei den Diensten oder exportiere deine Konten.';

  @override
  String get confirmMasterPassword => 'Master-Passwort bestätigen';

  @override
  String get nothingToExport => 'Keine Konten zum Exportieren';

  @override
  String get encryptedBackup => 'Verschlüsselte Sicherung';

  @override
  String get encryptedBackupHint =>
      'Mit eigenem Passwort, lässt sich in Sixora importieren';

  @override
  String get googleAuthenticatorQr => 'QR-Codes für Google Authenticator';

  @override
  String get googleAuthenticatorQrHint => 'Zum Übertragen in eine andere App';

  @override
  String get plainTextFile => 'Unverschlüsselte Textdatei';

  @override
  String get plainTextFileHint =>
      'otpauth-Links, für andere Apps – nur mit Vorsicht';

  @override
  String get encryptingBackup => 'Sicherung wird verschlüsselt …';

  @override
  String get exportUnencryptedQuestion => 'Unverschlüsselt exportieren?';

  @override
  String get exportUnencryptedMessage =>
      'Die Datei enthält alle geheimen Schlüssel im Klartext. Wer sie liest, kann deine Codes erzeugen. Nach dem Import sofort löschen.';

  @override
  String get saveAs => 'Speichern unter';

  @override
  String get saved => 'Gespeichert';

  @override
  String get openOtpauthLinks => 'otpauth-Links mit Sixora öffnen';

  @override
  String get otpauthLinksOpenSixora =>
      'Links zum Einrichten von Konten öffnen Sixora.';

  @override
  String notChanged(Object reason) {
    return 'Nicht geändert: $reason';
  }

  @override
  String get useSixora => 'Sixora verwenden';

  @override
  String get administrator => 'Administrator';

  @override
  String lastSynced(Object time) {
    return 'Zuletzt synchronisiert: $time';
  }

  @override
  String get aboutText =>
      'Codes werden auf deinen Geräten berechnet. Der Server speichert nur verschlüsselte Daten.';

  @override
  String get linksOpenOtherApp => 'Zurzeit öffnet sie eine andere App.';

  @override
  String linksOpenApp(Object app) {
    return 'Zurzeit öffnet sie „$app“.';
  }

  @override
  String vaultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tresore',
      one: '1 Tresor',
    );
    return '$_temp0';
  }

  @override
  String get language => 'Sprache';

  @override
  String get languageSystem => 'System';

  @override
  String offerBiometricsTitle(Object method) {
    return 'Mit $method entsperren?';
  }

  @override
  String offerBiometricsMessage(Object method) {
    return 'Dann reicht zum Entsperren $method statt des Master-Passworts. Das Passwort brauchst du weiterhin für Kontoänderungen und auf neuen Geräten.';
  }

  @override
  String get notNow => 'Nicht jetzt';

  @override
  String get setUp => 'Einrichten';

  @override
  String biometricsEnabled(Object method) {
    return 'Sixora lässt sich jetzt mit $method entsperren';
  }

  @override
  String get setUpLaterInSettings =>
      'Lässt sich später unter Einstellungen einrichten';

  @override
  String codeFor(Object name) {
    return 'Code für $name';
  }

  @override
  String get scanQrCode => 'QR-Code scannen';

  @override
  String get withCamera => 'Mit der Kamera';

  @override
  String get qrFromImage => 'QR-Code aus Bild';

  @override
  String get qrFromImageHint => 'Screenshot oder Foto auswählen';

  @override
  String get linkFromClipboard => 'Link aus Zwischenablage';

  @override
  String get linkFromClipboardHint => 'otpauth://… einfügen';

  @override
  String get enterManually => 'Manuell eingeben';

  @override
  String get enterManuallyHint => 'Schlüssel abtippen';

  @override
  String get importHint => 'Google Authenticator, Aegis, 2FAuth, Sixora …';

  @override
  String get chooseQrImages => 'Bilder mit QR-Codes auswählen';

  @override
  String get searchingQr => 'QR-Code wird gesucht …';

  @override
  String searchingQrInImages(int count) {
    return 'QR-Codes in $count Bildern werden gesucht …';
  }

  @override
  String get noQrInImage => 'Kein QR-Code im Bild gefunden';

  @override
  String get noQrInImages => 'In den Bildern wurde kein QR-Code gefunden';

  @override
  String linkIncomplete(Object reason) {
    return 'Link ist unvollständig: $reason';
  }

  @override
  String get notA2faLink => 'Das ist kein 2FA-Code (otpauth://…)';

  @override
  String get noWritableVault => 'Kein Tresor mit Schreibrecht vorhanden';

  @override
  String get alreadyThere => 'Schon vorhanden';

  @override
  String get alreadyThereMessage =>
      'Dieses Konto ist bereits gespeichert. Trotzdem noch einmal anlegen?';

  @override
  String get addAnyway => 'Anlegen';

  @override
  String get edit => 'Bearbeiten';

  @override
  String get removeFavorite => 'Kein Favorit mehr';

  @override
  String get makeFavorite => 'Als Favorit';

  @override
  String get moveToVault => 'In anderen Tresor verschieben';

  @override
  String get transferQr => 'Übertragen (QR-Code)';

  @override
  String get delete => 'Löschen';

  @override
  String get showSecretQuestion => 'Geheimen Schlüssel anzeigen?';

  @override
  String get showSecretMessage =>
      'Der QR-Code enthält den geheimen Schlüssel. Wer ihn sieht oder fotografiert, kann deine Codes erzeugen.';

  @override
  String deleteEntryQuestion(Object name) {
    return '„$name“ löschen?';
  }

  @override
  String entryDeleted(Object name) {
    return '„$name“ gelöscht';
  }

  @override
  String get undo => 'Rückgängig';

  @override
  String get moveTo => 'Verschieben nach';

  @override
  String get synchronize => 'Synchronisieren';

  @override
  String get lock => 'Sperren';

  @override
  String get add => 'Hinzufügen';

  @override
  String get all => 'Alle';

  @override
  String get favorites => 'Favoriten';

  @override
  String syncErrorBanner(Object error) {
    return '$error\nDie Codes funktionieren trotzdem; Änderungen brauchen eine Verbindung.';
  }

  @override
  String undecryptableEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge lassen sich nicht entschlüsseln.',
      one: '1 Eintrag lässt sich nicht entschlüsseln.',
    );
    return '$_temp0';
  }

  @override
  String get noMatches => 'Keine Treffer';

  @override
  String get noAccountsYet => 'Noch keine Konten';

  @override
  String get noAccountsHint =>
      'Aktiviere bei einem Dienst die Zwei-Faktor-Anmeldung und scanne den angezeigten QR-Code – oder importiere deine Konten aus einer anderen App.';

  @override
  String get addAccount => 'Konto hinzufügen';

  @override
  String get search => 'Suchen';

  @override
  String get clear => 'Leeren';

  @override
  String get signOutDeviceQuestion => 'Gerät abmelden?';

  @override
  String signOutDeviceMessage(Object device) {
    return '„$device“ verliert sofort den Zugriff. Warst du das nicht, ändere danach auch dein Master-Passwort: Wer sich anmelden konnte, kennt es.';
  }

  @override
  String get deviceSignedOut => 'Gerät abgemeldet';

  @override
  String newSignIn(Object device, Object platform, Object time) {
    return 'Neue Anmeldung: $device$platform, $time';
  }

  @override
  String get thatWasMe => 'Das war ich';

  @override
  String get deleteEntryMessage =>
      'Der Eintrag verschwindet auf allen Geräten. 30 Tage lang lässt er sich im Papierkorb (Einstellungen) wiederherstellen.';

  @override
  String get deleteEntrySharedMessage =>
      'Der Eintrag verschwindet auf allen Geräten und bei allen, mit denen der Tresor geteilt ist. 30 Tage lang lässt er sich im Papierkorb (Einstellungen) wiederherstellen.';

  @override
  String get newVault => 'Neuer Tresor';

  @override
  String get newVaultMessage =>
      'Ein eigener Tresor lässt sich mit anderen Benutzern dieses Servers teilen, z. B. „Team“ oder „Familie“.';

  @override
  String get name => 'Name';

  @override
  String get vaultsExplanation =>
      'Jeder Tresor hat einen eigenen Schlüssel. Beim Teilen wird er mit dem öffentlichen Schlüssel des Empfängers verschlüsselt – der Server sieht die Codes nie.';

  @override
  String get personal => 'Persönlich';

  @override
  String ownedBy(Object owner) {
    return 'von $owner';
  }

  @override
  String get roleOwner => 'Eigentümer';

  @override
  String get roleWrite => 'Lesen und Schreiben';

  @override
  String get roleRead => 'Nur lesen';

  @override
  String accountCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Konten',
      one: '1 Konto',
    );
    return '$_temp0';
  }

  @override
  String memberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitglieder',
      one: '1 Mitglied',
    );
    return '$_temp0';
  }

  @override
  String get shareWith => 'Teilen mit';

  @override
  String get thatIsYou => 'Das bist du selbst';

  @override
  String shareWithUser(Object user) {
    return 'Mit $user teilen';
  }

  @override
  String get compareFingerprint =>
      'Vergleicht zur Sicherheit den Schlüssel-Fingerabdruck, z. B. am Telefon. Er steht bei der anderen Person unter „Tresore und Teilen“. Stimmt er nicht, nicht teilen.';

  @override
  String fingerprintOf(Object user) {
    return 'Fingerabdruck von $user:';
  }

  @override
  String get roleReadHint => 'Codes sehen und kopieren';

  @override
  String get roleWriteHint => 'Auch Konten hinzufügen, ändern und löschen';

  @override
  String get share => 'Teilen';

  @override
  String get vaultGone => 'Tresor nicht mehr verfügbar';

  @override
  String get rename => 'Umbenennen';

  @override
  String get personalVaultNotShared =>
      'Dein persönlicher Tresor kann nicht geteilt werden.';

  @override
  String get personalVaultNotSharedHint =>
      'Lege für gemeinsame Konten einen eigenen Tresor an und verschiebe sie dorthin.';

  @override
  String get yourFingerprint => 'Dein Schlüssel-Fingerabdruck';

  @override
  String get members => 'Mitglieder';

  @override
  String memberYou(Object user) {
    return '$user (du)';
  }

  @override
  String get remove => 'Entfernen';

  @override
  String removeMemberQuestion(Object user) {
    return '$user entfernen?';
  }

  @override
  String removeMemberMessage(Object user) {
    return '$user verliert den Zugriff auf diesen Tresor. Sixora erneuert danach den Schlüssel des Tresors, damit der alte nichts mehr öffnet. Schlüssel von Konten, die $user schon gesehen hat, bleiben aber bekannt – bei Bedarf beim Dienst neu einrichten.';
  }

  @override
  String get deleteVault => 'Tresor löschen';

  @override
  String get deleteVaultHint => 'Mit allen Konten darin, für alle Mitglieder';

  @override
  String deleteVaultQuestion(Object name) {
    return '„$name“ löschen?';
  }

  @override
  String get deleteVaultMessage =>
      'Alle Konten in diesem Tresor werden für alle Mitglieder gelöscht.';

  @override
  String get leaveVault => 'Tresor verlassen';

  @override
  String leaveVaultQuestion(Object name) {
    return '„$name“ verlassen?';
  }

  @override
  String get leaveVaultMessage =>
      'Du siehst die Konten darin nicht mehr, bis du erneut eingeladen wirst.';

  @override
  String get leave => 'Verlassen';

  @override
  String get editAccount => 'Konto bearbeiten';

  @override
  String get save => 'Speichern';

  @override
  String get newAccount => 'Neues Konto';

  @override
  String get enterKey => 'Schlüssel eingeben …';

  @override
  String get service => 'Dienst';

  @override
  String get serviceExample => 'z. B. GitHub';

  @override
  String get accountName => 'Konto';

  @override
  String get accountExample => 'z. B. name@example.org';

  @override
  String get secretKey => 'Geheimer Schlüssel';

  @override
  String get secretKeyHint => 'Base32, Leerzeichen sind egal';

  @override
  String get groupOptional => 'Gruppe (optional)';

  @override
  String get groupExample => 'z. B. Arbeit';

  @override
  String get chooseGroup => 'Vorhandene Gruppe wählen';

  @override
  String get vault => 'Tresor';

  @override
  String get favorite => 'Favorit';

  @override
  String get favoriteHint => 'Steht oben in der Liste';

  @override
  String get icon => 'Symbol';

  @override
  String get initialLetter => 'Anfangsbuchstabe';

  @override
  String iconAutomatic(Object name) {
    return '$name (automatisch)';
  }

  @override
  String get initialLetterNoLogo =>
      'Anfangsbuchstabe (kein passendes Logo gefunden)';

  @override
  String get unknown => 'Unbekannt';

  @override
  String get color => 'Farbe';

  @override
  String get colorAuto => 'Auto';

  @override
  String get notesOptional => 'Notizen (optional)';

  @override
  String get advanced => 'Erweitert';

  @override
  String get timeBased => 'Zeitbasiert';

  @override
  String get counter => 'Zähler';

  @override
  String get algorithm => 'Algorithmus';

  @override
  String get digits => 'Stellen';

  @override
  String get periodSeconds => 'Intervall (s)';

  @override
  String get chooseIcon => 'Symbol wählen';

  @override
  String get searchServiceExample => 'Dienst suchen, z. B. Google';

  @override
  String get automatic => 'Automatisch';

  @override
  String get letter => 'Buchstabe';

  @override
  String get noLogoFound => 'Kein Logo gefunden';

  @override
  String logosCredit(Object version) {
    return 'Logos: Simple Icons $version. Die Marken gehören ihren Inhabern.';
  }

  @override
  String digitsCount(int count) {
    return '$count Stellen';
  }

  @override
  String unexpectedError(Object error) {
    return 'Unerwarteter Fehler: $error';
  }

  @override
  String get biometrics => 'Biometrie';

  @override
  String get enterServerAddress => 'Bitte die Server-Adresse eingeben';

  @override
  String get invalidAddress => 'Ungültige Adresse';

  @override
  String get httpOnlyLocal =>
      'Unverschlüsseltes HTTP ist nur im lokalen Netz erlaubt. Bitte https:// verwenden.';

  @override
  String get recoveryKeyMismatch => 'Wiederherstellungsschlüssel passt nicht';

  @override
  String get masterPasswordWrong => 'Master-Passwort ist falsch';

  @override
  String biometricsInvalidatedEnrolled(Object method) {
    return 'Entsperren mit $method ist nicht mehr gültig, z. B. weil ein Finger oder Gesicht neu registriert wurde. Bitte mit dem Master-Passwort entsperren und es danach neu einrichten.';
  }

  @override
  String biometricsInvalidated(Object method) {
    return 'Entsperren mit $method ist nicht mehr gültig. Bitte mit dem Master-Passwort entsperren.';
  }

  @override
  String biometricsSetupFailed(Object method, Object reason) {
    return '$method ließ sich nicht einrichten: $reason';
  }

  @override
  String get noSession =>
      'Keine Sitzung. Bitte sperren und mit Passwort entsperren.';

  @override
  String get accountDisabledNotice => 'Dein Konto wurde gesperrt.';

  @override
  String get deviceSignedOutNotice =>
      'Dieses Gerät wurde abgemeldet (Passwort geändert oder Gerät entfernt). Bitte erneut anmelden.';

  @override
  String noServerConnection(Object reason) {
    return 'Keine Verbindung zum Server. $reason.';
  }

  @override
  String backupWrittenMismatch(Object found, Object expected) {
    return 'Die geschriebene Sicherung enthält $found statt $expected Konten';
  }

  @override
  String backupFailed(Object reason) {
    return 'Sicherung fehlgeschlagen: $reason';
  }

  @override
  String get backupOtherAccount =>
      'Die Sicherung wurde für ein anderes Konto eingerichtet. Bitte neu einrichten.';

  @override
  String get backupNotSetUp =>
      'Die automatische Sicherung ist nicht eingerichtet';

  @override
  String get noBackupInFolder => 'Im Ordner liegt keine Sicherung';

  @override
  String backupUnreadable(Object reason) {
    return 'Sicherung nicht lesbar: $reason';
  }

  @override
  String get vaultKeyRenewed =>
      'Der Schlüssel des Tresors wurde gerade erneuert. Bitte erneut versuchen.';

  @override
  String get entryChangedElsewhere =>
      'Der Eintrag wurde inzwischen auf einem anderen Gerät geändert. Die aktuelle Fassung ist geladen, bitte erneut versuchen.';

  @override
  String get vaultReadOnly => 'In diesen Tresor darfst du nicht schreiben';

  @override
  String get trustedKeysTampered =>
      'Die gespeicherten Schlüssel deiner Kontakte wurden verändert. Zur Sicherheit wurde abgebrochen. Bitte den Server prüfen.';

  @override
  String get aContact => 'einem Kontakt';

  @override
  String memberKeyChanged(Object user) {
    return 'Der Schlüssel von „$user“ ist ein anderer als bisher. Ein Benutzerschlüssel ändert sich nie, dieser kommt also nicht von „$user“. Zur Sicherheit wurde abgebrochen. Bitte den Server prüfen.';
  }

  @override
  String get currentMasterPasswordWrong =>
      'Aktuelles Master-Passwort ist falsch';

  @override
  String get accountDeletedNotice => 'Dein Konto wurde gelöscht.';

  @override
  String get unlockSixora => 'Sixora entsperren';

  @override
  String get fingerprint => 'Fingerabdruck';

  @override
  String setUpUnlockWith(Object method) {
    return 'Entsperren mit $method einrichten';
  }

  @override
  String get autoLockImmediately => 'Sofort beim Verlassen';

  @override
  String autoLockMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Nach $minutes Minuten',
      one: 'Nach 1 Minute',
    );
    return '$_temp0';
  }

  @override
  String get autoLockOneHour => 'Nach 1 Stunde';

  @override
  String get autoLockNever => 'Nie';

  @override
  String get users => 'Benutzer';

  @override
  String get invites => 'Einladungen';

  @override
  String get log => 'Protokoll';

  @override
  String get adminCannotSee =>
      'Als Administrator siehst du keine Codes anderer Benutzer und kannst keine Passwörter zurücksetzen – das verhindert die Verschlüsselung.';

  @override
  String since(Object date) {
    return 'seit $date';
  }

  @override
  String deleteUserQuestion(Object user) {
    return '$user löschen?';
  }

  @override
  String get deleteUserMessage =>
      'Das Konto, alle seine Codes und die Tresore, die ihm gehören, werden endgültig gelöscht.';

  @override
  String get revokeAdmin => 'Administrator entziehen';

  @override
  String get makeAdmin => 'Zum Administrator machen';

  @override
  String get unblock => 'Entsperren';

  @override
  String get block => 'Sperren';

  @override
  String get createInvite => 'Einladung erstellen';

  @override
  String get createInviteHint => 'Einmal verwendbar, 7 Tage gültig';

  @override
  String get inviteFor => 'Für wen? (optional)';

  @override
  String get create => 'Erstellen';

  @override
  String get invite => 'Einladung';

  @override
  String inviteInstructions(Object date) {
    return 'In der Sixora-App bei „Einladungs-QR-Code scannen“ scannen oder den Link schicken: Server-Adresse und Code sind dann schon eingetragen. Gültig bis $date, nur einmal verwendbar. Code und Link werden nur jetzt angezeigt.';
  }

  @override
  String get copyLink => 'Link kopieren';

  @override
  String get done => 'Fertig';

  @override
  String get noOpenInvites => 'Keine offenen Einladungen';

  @override
  String inviteDates(Object created, Object expires) {
    return 'Erstellt $created · gültig bis $expires';
  }

  @override
  String get withdraw => 'Zurückziehen';

  @override
  String get chooseExportFilesOrImages =>
      'Export-Dateien oder Bilder auswählen';

  @override
  String get nothingNew => 'Nichts Neues gefunden';

  @override
  String get backupPassword => 'Passwort der Sicherung';

  @override
  String get decrypt => 'Entschlüsseln';

  @override
  String accountsImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Konten importiert',
      one: '1 Konto importiert',
    );
    return '$_temp0';
  }

  @override
  String get supported => 'Unterstützt werden:';

  @override
  String get supportedFormats =>
      '• Google Authenticator: „Konten übertragen“ → QR-Codes scannen oder Screenshots wählen (alle auf einmal, bei mehreren Codes)\n• Aegis: Export als unverschlüsseltes JSON\n• 2FAS: Sicherung ohne Passwort (.2fas)\n• Bitwarden: Export als JSON (unverschlüsselt) oder CSV\n• andOTP: unverschlüsselter JSON-Export\n• FreeOTP+: JSON-Export\n• 2FAuth: Export als JSON\n• Sixora: verschlüsselte Sicherung\n• Alles mit otpauth://-Links, z. B. Ente Auth (Export als Text) oder Textdateien';

  @override
  String get microsoftNoExport =>
      'Microsoft Authenticator und Authy bieten keinen Export. Dort jedes Konto beim Dienst neu einrichten oder den QR-Code erneut anzeigen lassen.';

  @override
  String get chooseFilesOrImages => 'Dateien oder Bilder auswählen';

  @override
  String missingTransferCodes(Object codes) {
    return 'Es fehlen noch Code $codes.';
  }

  @override
  String get missingTransferCodesHint =>
      'Google Authenticator verteilt die Konten auf mehrere QR-Codes. Die fehlenden bitte ebenfalls hinzufügen.';

  @override
  String get addMoreFiles => 'Weitere Bilder oder Dateien hinzufügen';

  @override
  String get alreadyPresent => 'schon vorhanden';

  @override
  String get groupForUngrouped => 'Gruppe für Konten ohne Gruppe';

  @override
  String progressOf(Object done, Object total) {
    return '$done von $total';
  }

  @override
  String importAccounts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Konten importieren',
      one: '1 Konto importieren',
    );
    return '$_temp0';
  }

  @override
  String get tryAgain => 'Erneut versuchen';

  @override
  String get signedInDevicesHint =>
      'Ein abgemeldetes Gerät verliert sofort den Zugriff auf den Server und löscht beim nächsten Kontakt seine lokale Kopie.';

  @override
  String thisDevice(Object device) {
    return '$device (dieses Gerät)';
  }

  @override
  String sessionDates(Object created, Object lastSeen) {
    return 'Angemeldet $created · zuletzt aktiv $lastSeen';
  }

  @override
  String signOutDeviceNamed(Object device) {
    return '„$device“ abmelden?';
  }

  @override
  String get signOutDeviceHint => 'Das Gerät muss sich danach neu anmelden.';

  @override
  String get eventRegister => 'Konto erstellt';

  @override
  String get eventLogin => 'Anmeldung';

  @override
  String get eventLoginFailed => 'Fehlgeschlagene Anmeldung';

  @override
  String get eventReauthFailed => 'Falsches Passwort bei Kontoänderung';

  @override
  String get eventLogout => 'Abmeldung';

  @override
  String get eventPasswordChanged => 'Master-Passwort geändert';

  @override
  String get eventRecoveryUsed => 'Wiederherstellungsschlüssel benutzt';

  @override
  String get eventRecoveryFailed => 'Falscher Wiederherstellungsschlüssel';

  @override
  String get eventRecoveryKeyChanged => 'Neuer Wiederherstellungsschlüssel';

  @override
  String get eventSessionRevoked => 'Gerät abgemeldet';

  @override
  String get eventAccountDeleted => 'Konto gelöscht';

  @override
  String get eventVaultShared => 'Tresor geteilt';

  @override
  String get eventVaultUnshared => 'Mitglied entfernt';

  @override
  String get eventVaultLeft => 'Tresor verlassen';

  @override
  String get eventVaultDeleted => 'Tresor gelöscht';

  @override
  String get eventInviteCreated => 'Einladung erstellt';

  @override
  String get eventInviteDeleted => 'Einladung gelöscht';

  @override
  String get eventUserUpdated => 'Benutzer geändert';

  @override
  String get eventUserDeleted => 'Benutzer gelöscht';

  @override
  String get noEntries => 'Keine Einträge';

  @override
  String accountsFound(int count, Object source) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Konten aus $source gefunden',
      one: '1 Konto aus $source gefunden',
    );
    return '$_temp0';
  }

  @override
  String notReadable(int count) {
    return ', $count nicht lesbar';
  }

  @override
  String get existingDeselected => 'Bereits vorhandene sind abgewählt.';

  @override
  String get blocked => 'gesperrt';

  @override
  String get eventVaultKeyRotated => 'Tresorschlüssel erneuert';

  @override
  String get writingFirstBackup => 'Erste Sicherung wird geschrieben …';

  @override
  String get autoBackupExplanation =>
      'Sixora schreibt nach Änderungen eine verschlüsselte Sicherung aller Konten in einen Ordner deiner Wahl, zum Beispiel in die iCloud, in Nextcloud oder auf einen USB-Stick. So bleibt eine Kopie, auch wenn Server oder Konto verloren gehen.\n\nPro Tag entsteht eine Datei, die letzten 14 bleiben. Geschrieben wird nur, solange Sixora entsperrt ist. Öffnen lässt sich eine Sicherung mit ihrem Passwort über „Importieren“, auch in einem neuen Konto.';

  @override
  String get chooseFolderAndSetUp => 'Ordner wählen und einrichten';

  @override
  String get folder => 'Ordner';

  @override
  String get lastBackup => 'Letzte Sicherung';

  @override
  String get lastBackupFailed => 'Letzte Sicherung fehlgeschlagen';

  @override
  String backupErrorDetail(Object error, Object date) {
    return '$error\nZuletzt erfolgreich: $date';
  }

  @override
  String get backUpNow => 'Jetzt sichern';

  @override
  String get backupWritten => 'Sicherung geschrieben';

  @override
  String get verifyBackup => 'Sicherung prüfen';

  @override
  String get verifyBackupHint =>
      'Öffnet die neueste Datei wie beim Zurückspielen';

  @override
  String get backupOk => 'Sicherung in Ordnung';

  @override
  String get backupNotCurrent => 'Sicherung lesbar, aber nicht aktuell';

  @override
  String get otherFolderOrPassword => 'Anderen Ordner oder neues Passwort';

  @override
  String get turnOff => 'Ausschalten';

  @override
  String get turnOffHint => 'Vorhandene Dateien bleiben im Ordner';

  @override
  String get saveRecoveryKey => 'Wiederherstellungsschlüssel speichern';

  @override
  String get newRecoveryKeyShown =>
      'Dein neuer Wiederherstellungsschlüssel. Der alte gilt nicht mehr.';

  @override
  String get writeDownKey => 'Schreib dir diesen Schlüssel jetzt auf.';

  @override
  String get recoveryKeyExplanation =>
      'Vergisst du dein Master-Passwort, ist er der einzige Weg zurück an deine Codes. Er wird nur dieses eine Mal angezeigt.';

  @override
  String get copy => 'Kopieren';

  @override
  String get copiedRemoveAfterPaste =>
      'Kopiert – bitte nach dem Einfügen aus der Zwischenablage entfernen';

  @override
  String get saveAsFile => 'Als Datei speichern';

  @override
  String get keyStoredSafely => 'Ich habe den Schlüssel sicher aufbewahrt.';

  @override
  String get trashEmpty => 'Der Papierkorb ist leer';

  @override
  String get trashExplanation =>
      'Gelöschte Konten bleiben 30 Tage verschlüsselt auf dem Server und lassen sich bis dahin wiederherstellen.';

  @override
  String deletedOn(Object date) {
    return 'gelöscht $date';
  }

  @override
  String get restore => 'Wiederherstellen';

  @override
  String restored(Object name) {
    return '„$name“ wiederhergestellt';
  }

  @override
  String get deleteForGood => 'Endgültig löschen';

  @override
  String get deleteForGoodQuestion => 'Endgültig löschen?';

  @override
  String deleteForGoodMessage(Object name) {
    return '„$name“ lässt sich danach nicht mehr wiederherstellen.';
  }

  @override
  String get transferAccounts => 'Konten übertragen';

  @override
  String get noneTransferable => 'Keines der Konten lässt sich so übertragen.';

  @override
  String get previousCode => 'Vorheriger Code';

  @override
  String codeOfTotal(Object page, Object total) {
    return 'Code $page von $total';
  }

  @override
  String get scanInOtherApp => 'In der anderen App „QR-Code scannen“ wählen.';

  @override
  String get scanInGoogleAuthenticator =>
      'In Google Authenticator „Konten importieren“ wählen und die Codes nacheinander scannen. Andere Apps wie Aegis lesen dieses Format ebenfalls.';

  @override
  String skippedTransfer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count Konten (Steam oder ungewöhnliche Intervalle) sind nicht enthalten – bitte einzeln übertragen.',
      one:
          '1 Konto (Steam oder ungewöhnliches Intervall) ist nicht enthalten – bitte einzeln übertragen.',
    );
    return '$_temp0';
  }

  @override
  String get switchCamera => 'Kamera wechseln';

  @override
  String get noCameraAccess =>
      'Kein Zugriff auf die Kamera. Bitte in den Systemeinstellungen erlauben.';

  @override
  String cameraUnavailable(Object reason) {
    return 'Kamera nicht verfügbar: $reason';
  }

  @override
  String codesCaptured(Object count, Object total) {
    return '$count von $total Codes erfasst';
  }

  @override
  String get nextInGoogleAuthenticator =>
      'In Google Authenticator zum nächsten Code blättern.';

  @override
  String get continueWithCaptured => 'Mit den erfassten weiter';

  @override
  String get scanHint =>
      'Halte die Kamera auf den QR-Code, den der Dienst bei der Einrichtung der Zwei-Faktor-Anmeldung anzeigt.';

  @override
  String get shortcutCtrlAltO => 'Strg+Alt+O';

  @override
  String get openSixora => 'Sixora öffnen';

  @override
  String searchWithShortcut(Object shortcut) {
    return 'Suchen … ($shortcut)';
  }

  @override
  String get favoritesHint => 'Favoriten: Stern bei einem Konto setzen';

  @override
  String get unlockEllipsis => 'Entsperren …';

  @override
  String get quitSixora => 'Sixora beenden';

  @override
  String get imageNotOpenable =>
      'Das Bild lässt sich nicht öffnen. Bitte als PNG oder JPEG speichern (z. B. einen Screenshot statt eines HEIC-Fotos).';

  @override
  String codeListOfSize(Object list, Object size) {
    return '$list von $size';
  }

  @override
  String get autoBackupFolder => 'Ordner für die automatische Sicherung';

  @override
  String listAnd(Object first, Object last) {
    return '$first und $last';
  }

  @override
  String backupVerified(Object file, int accounts, int files) {
    return '$file lässt sich mit dem Passwort öffnen und enthält $accounts Konten. Im Ordner liegen $files Sicherungen.';
  }

  @override
  String backupMissing(Object names) {
    return 'Noch nicht enthalten: $names. „Jetzt sichern“ nimmt sie auf.';
  }

  @override
  String recoveryKeyFile(Object user, Object date, Object key) {
    return 'Sixora – Wiederherstellungsschlüssel\n\nBenutzer: $user\nErstellt: $date\n\n$key\n\nDamit lässt sich ein neues Master-Passwort setzen. Sicher aufbewahren (z. B. ausgedruckt oder im Passwort-Manager) und niemandem zeigen.\n';
  }

  @override
  String get checkDuplicate => 'Doppelt gespeichert';

  @override
  String get checkDuplicateHint =>
      'Gleicher Schlüssel, gleiche Codes. Eine Kopie genügt; die andere kann in den Papierkorb.';

  @override
  String get checkWeak => 'Kurzer Schlüssel';

  @override
  String get checkWeakHint =>
      'Unter 80 Bit. Einen neuen Schlüssel kann nur der Dienst ausstellen: die Zwei-Faktor-Anmeldung dort neu einrichten.';

  @override
  String get checkInvalid => 'Ungültiger Schlüssel';

  @override
  String get checkInvalidHint =>
      'Daraus lässt sich kein Code berechnen. Bitte den Schlüssel prüfen.';

  @override
  String get checkUnnamed => 'Ohne Namen';

  @override
  String get checkUnnamedHint => 'Weder Dienst noch Konto: schwer zu erkennen.';

  @override
  String get withoutLogo => 'Ohne Logo';

  @override
  String get withoutLogoHint =>
      'Kein passendes Logo gefunden. Im Editor lässt sich eines auswählen oder der Buchstabe festlegen.';

  @override
  String allGood(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alles in Ordnung: $count Konten geprüft',
      one: 'Alles in Ordnung: 1 Konto geprüft',
    );
    return '$_temp0';
  }

  @override
  String get errOffline => 'Server nicht erreichbar';

  @override
  String errDns(Object host) {
    return 'Adresse „$host“ nicht gefunden (DNS). Stimmt die Adresse? Nach einer Änderung kann es bis zu einer Stunde dauern.';
  }

  @override
  String get errTls => 'Sichere Verbindung fehlgeschlagen (Zertifikat prüfen)';

  @override
  String get errBadRequest => 'Ungültige Anfrage';

  @override
  String get errConflict =>
      'Die Daten wurden inzwischen geändert. Bitte erneut versuchen.';

  @override
  String get errDisabled => 'Konto ist gesperrt';

  @override
  String get errForbidden =>
      'Das darf nur der Eigentümer bzw. ein Administrator';

  @override
  String get errInvalidCredentials => 'Benutzername oder Passwort ist falsch';

  @override
  String get errInvalidInvite => 'Einladungscode ist ungültig oder abgelaufen';

  @override
  String get errInvalidUsername =>
      'Benutzername: 3–64 Zeichen, Buchstaben, Ziffern und . _ @ + -';

  @override
  String get errLastAdmin =>
      'Der letzte Administrator kann nicht entfernt werden. Bitte zuerst einen anderen Benutzer zum Administrator machen.';

  @override
  String get errLimit => 'Zu viele Einträge';

  @override
  String get errNotFound => 'Nicht gefunden';

  @override
  String get errOwnerCannotLeave =>
      'Der Eigentümer kann den Tresor nicht verlassen, nur löschen';

  @override
  String get errPersonalVault =>
      'Der persönliche Tresor kann weder geteilt noch gelöscht werden';

  @override
  String get errRateLimited =>
      'Zu viele Versuche. Bitte später erneut versuchen.';

  @override
  String get errRegistrationClosed => 'Registrierung ist geschlossen';

  @override
  String get errSelf => 'Das geht nicht mit dem eigenen Konto';

  @override
  String get errTooLarge => 'Anfrage ist zu groß';

  @override
  String get errUnauthorized => 'Sitzung ist abgelaufen';

  @override
  String get errUsernameTaken => 'Benutzername ist vergeben';

  @override
  String errUnexpectedResponse(int status) {
    return 'Unerwartete Antwort (Fehler $status) – ist das ein Sixora-Server?';
  }

  @override
  String get errServiceOrAccount => 'Dienst oder Konto angeben';

  @override
  String get errBackupOtherPassword =>
      'Diese Sicherung wurde mit einem anderen Passwort erstellt';

  @override
  String get errDecryptionFailed => 'Entschlüsselung fehlgeschlagen';

  @override
  String get errExportDamaged => 'Export-Daten sind beschädigt';

  @override
  String get errPeriodRange => 'Intervall muss zwischen 5 und 600 s liegen';

  @override
  String get errNotGoogleExport => 'Kein Google-Authenticator-Export';

  @override
  String get errNotOtpauth => 'Kein otpauth-Link';

  @override
  String get errNoAccountsInFile => 'Keine Konten in der Datei gefunden';

  @override
  String get errEmptyKey => 'Leerer Schlüssel';

  @override
  String get errBackupPasswordWrong => 'Passwort der Sicherung ist falsch';

  @override
  String get errKeyMissing => 'Schlüssel fehlt';

  @override
  String get errKeyTooShort => 'Schlüssel ist zu kurz';

  @override
  String get errDigitsRange => 'Stellen müssen zwischen 4 und 10 liegen';

  @override
  String get errTypeUnsupported => 'Typ nicht unterstützt';

  @override
  String get errUnknownFormat => 'Unbekanntes Format';

  @override
  String get errUnknownBackupFormat => 'Unbekanntes Sicherungsformat';

  @override
  String get errInvalidKeyCharacter => 'Ungültiges Zeichen im Schlüssel';

  @override
  String get errInvalidKeyParameters => 'Unzulässige Schlüsselparameter';

  @override
  String get errRecoveryKeyInvalid =>
      'Wiederherstellungsschlüssel ist ungültig';

  @override
  String get errCounterNegative => 'Zähler ist negativ';

  @override
  String get errAegisEncrypted =>
      'Verschlüsselte Aegis-Sicherung: bitte in Aegis unverschlüsselt exportieren';

  @override
  String get choose => 'Auswählen';

  @override
  String get err2fasEncrypted =>
      'Verschlüsselte 2FAS-Sicherung: bitte in 2FAS ohne Passwort exportieren';

  @override
  String get errBitwardenEncrypted =>
      'Verschlüsselter Bitwarden-Export: bitte als „.json“ ohne Verschlüsselung exportieren';

  @override
  String get errEnteEncrypted =>
      'Verschlüsselte Ente-Auth-Sicherung: bitte unverschlüsselt (als Textdatei) exportieren';

  @override
  String get searchEllipsis => 'Suchen …';
}
