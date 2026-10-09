import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In de, this message translates to:
  /// **'Sixora'**
  String get appTitle;

  /// No description provided for @signedOut.
  ///
  /// In de, this message translates to:
  /// **'Abgemeldet'**
  String get signedOut;

  /// No description provided for @cancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get cancel;

  /// No description provided for @backupPasswordTitle.
  ///
  /// In de, this message translates to:
  /// **'Passwort für die Sicherung'**
  String get backupPasswordTitle;

  /// No description provided for @backupPasswordHint.
  ///
  /// In de, this message translates to:
  /// **'Mindestens 10 Zeichen. Ohne dieses Passwort lässt sich die Sicherung nicht öffnen.'**
  String get backupPasswordHint;

  /// No description provided for @password.
  ///
  /// In de, this message translates to:
  /// **'Passwort'**
  String get password;

  /// No description provided for @continueAction.
  ///
  /// In de, this message translates to:
  /// **'Weiter'**
  String get continueAction;

  /// No description provided for @passwordTooShort.
  ///
  /// In de, this message translates to:
  /// **'Das Passwort braucht mindestens 10 Zeichen'**
  String get passwordTooShort;

  /// No description provided for @repeatPassword.
  ///
  /// In de, this message translates to:
  /// **'Passwort wiederholen'**
  String get repeatPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In de, this message translates to:
  /// **'Die Passwörter stimmen nicht überein'**
  String get passwordsDoNotMatch;

  /// No description provided for @paste.
  ///
  /// In de, this message translates to:
  /// **'Einfügen'**
  String get paste;

  /// No description provided for @selectAll.
  ///
  /// In de, this message translates to:
  /// **'Alles auswählen'**
  String get selectAll;

  /// No description provided for @clipboardEmpty.
  ///
  /// In de, this message translates to:
  /// **'Die Zwischenablage ist leer'**
  String get clipboardEmpty;

  /// No description provided for @hide.
  ///
  /// In de, this message translates to:
  /// **'Verbergen'**
  String get hide;

  /// No description provided for @show.
  ///
  /// In de, this message translates to:
  /// **'Anzeigen'**
  String get show;

  /// No description provided for @strengthWeak.
  ///
  /// In de, this message translates to:
  /// **'Schwach'**
  String get strengthWeak;

  /// No description provided for @strengthFair.
  ///
  /// In de, this message translates to:
  /// **'Mittel'**
  String get strengthFair;

  /// No description provided for @strengthGood.
  ///
  /// In de, this message translates to:
  /// **'Gut'**
  String get strengthGood;

  /// No description provided for @strengthVeryGood.
  ///
  /// In de, this message translates to:
  /// **'Sehr gut'**
  String get strengthVeryGood;

  /// No description provided for @enterSixoraMasterPassword.
  ///
  /// In de, this message translates to:
  /// **'Bitte das Sixora-Master-Passwort eingeben.'**
  String get enterSixoraMasterPassword;

  /// No description provided for @signOutQuestion.
  ///
  /// In de, this message translates to:
  /// **'Abmelden?'**
  String get signOutQuestion;

  /// No description provided for @signOutLocalCopyMessage.
  ///
  /// In de, this message translates to:
  /// **'Die lokale Kopie wird von diesem Gerät entfernt. Deine Codes bleiben auf dem Server und auf deinen anderen Geräten erhalten.'**
  String get signOutLocalCopyMessage;

  /// No description provided for @signOut.
  ///
  /// In de, this message translates to:
  /// **'Abmelden'**
  String get signOut;

  /// No description provided for @locked.
  ///
  /// In de, this message translates to:
  /// **'Gesperrt'**
  String get locked;

  /// No description provided for @unlock.
  ///
  /// In de, this message translates to:
  /// **'Entsperren'**
  String get unlock;

  /// No description provided for @unlockWith.
  ///
  /// In de, this message translates to:
  /// **'Mit {method} entsperren'**
  String unlockWith(Object method);

  /// No description provided for @notAnInviteCode.
  ///
  /// In de, this message translates to:
  /// **'Das ist kein Sixora-Einladungscode'**
  String get notAnInviteCode;

  /// No description provided for @usernameTooShort.
  ///
  /// In de, this message translates to:
  /// **'Benutzername: mindestens 3 Zeichen'**
  String get usernameTooShort;

  /// No description provided for @masterPasswordTooShort.
  ///
  /// In de, this message translates to:
  /// **'Das Master-Passwort braucht mindestens 10 Zeichen'**
  String get masterPasswordTooShort;

  /// No description provided for @enterUsernameAndPassword.
  ///
  /// In de, this message translates to:
  /// **'Benutzername und Master-Passwort eingeben'**
  String get enterUsernameAndPassword;

  /// No description provided for @tagline.
  ///
  /// In de, this message translates to:
  /// **'Deine Einmal-Codes, Ende-zu-Ende-verschlüsselt auf deinem eigenen Server.'**
  String get tagline;

  /// No description provided for @serverAddressOrInvite.
  ///
  /// In de, this message translates to:
  /// **'Server-Adresse oder Einladungslink'**
  String get serverAddressOrInvite;

  /// No description provided for @connect.
  ///
  /// In de, this message translates to:
  /// **'Verbinden'**
  String get connect;

  /// No description provided for @scanInviteQr.
  ///
  /// In de, this message translates to:
  /// **'Einladungs-QR-Code scannen'**
  String get scanInviteQr;

  /// No description provided for @change.
  ///
  /// In de, this message translates to:
  /// **'Ändern'**
  String get change;

  /// No description provided for @signIn.
  ///
  /// In de, this message translates to:
  /// **'Anmelden'**
  String get signIn;

  /// No description provided for @register.
  ///
  /// In de, this message translates to:
  /// **'Registrieren'**
  String get register;

  /// No description provided for @forgotten.
  ///
  /// In de, this message translates to:
  /// **'Vergessen'**
  String get forgotten;

  /// No description provided for @newServerFirstAdmin.
  ///
  /// In de, this message translates to:
  /// **'Dieser Server ist neu. Das erste Konto wird Administrator.'**
  String get newServerFirstAdmin;

  /// No description provided for @username.
  ///
  /// In de, this message translates to:
  /// **'Benutzername'**
  String get username;

  /// No description provided for @recoveryKey.
  ///
  /// In de, this message translates to:
  /// **'Wiederherstellungsschlüssel'**
  String get recoveryKey;

  /// No description provided for @newMasterPassword.
  ///
  /// In de, this message translates to:
  /// **'Neues Master-Passwort'**
  String get newMasterPassword;

  /// No description provided for @masterPassword.
  ///
  /// In de, this message translates to:
  /// **'Master-Passwort'**
  String get masterPassword;

  /// No description provided for @strengthLabel.
  ///
  /// In de, this message translates to:
  /// **'Stärke: {strength}'**
  String strengthLabel(Object strength);

  /// No description provided for @repeatMasterPassword.
  ///
  /// In de, this message translates to:
  /// **'Master-Passwort wiederholen'**
  String get repeatMasterPassword;

  /// No description provided for @inviteCode.
  ///
  /// In de, this message translates to:
  /// **'Einladungscode'**
  String get inviteCode;

  /// No description provided for @masterPasswordNeverLeaves.
  ///
  /// In de, this message translates to:
  /// **'Das Master-Passwort verlässt nie dieses Gerät und kann von niemandem zurückgesetzt werden – auch nicht vom Administrator. Nur mit dem Wiederherstellungsschlüssel kommst du ohne Passwort wieder hinein.'**
  String get masterPasswordNeverLeaves;

  /// No description provided for @createAccount.
  ///
  /// In de, this message translates to:
  /// **'Konto erstellen'**
  String get createAccount;

  /// No description provided for @setNewPassword.
  ///
  /// In de, this message translates to:
  /// **'Neues Passwort setzen'**
  String get setNewPassword;

  /// No description provided for @generatingKeys.
  ///
  /// In de, this message translates to:
  /// **'Schlüssel werden erzeugt …'**
  String get generatingKeys;

  /// No description provided for @keyInvalidShort.
  ///
  /// In de, this message translates to:
  /// **'Schlüssel ungültig'**
  String get keyInvalidShort;

  /// No description provided for @codeHidden.
  ///
  /// In de, this message translates to:
  /// **'Code verborgen'**
  String get codeHidden;

  /// No description provided for @spokenCode.
  ///
  /// In de, this message translates to:
  /// **'Code {digits}'**
  String spokenCode(Object digits);

  /// No description provided for @secondsLeft.
  ///
  /// In de, this message translates to:
  /// **'{seconds, plural, =1{noch 1 Sekunde} other{noch {seconds} Sekunden}}'**
  String secondsLeft(int seconds);

  /// No description provided for @showCode.
  ///
  /// In de, this message translates to:
  /// **'Code anzeigen'**
  String get showCode;

  /// No description provided for @copyCode.
  ///
  /// In de, this message translates to:
  /// **'Code kopieren'**
  String get copyCode;

  /// No description provided for @moreActions.
  ///
  /// In de, this message translates to:
  /// **'Weitere Aktionen'**
  String get moreActions;

  /// No description provided for @nextCodeLabel.
  ///
  /// In de, this message translates to:
  /// **'Nächster: {code}'**
  String nextCodeLabel(Object code);

  /// No description provided for @keyIsInvalid.
  ///
  /// In de, this message translates to:
  /// **'Schlüssel ist ungültig'**
  String get keyIsInvalid;

  /// No description provided for @nextCode.
  ///
  /// In de, this message translates to:
  /// **'Nächster Code'**
  String get nextCode;

  /// No description provided for @more.
  ///
  /// In de, this message translates to:
  /// **'Mehr'**
  String get more;

  /// No description provided for @code.
  ///
  /// In de, this message translates to:
  /// **'Code'**
  String get code;

  /// No description provided for @copied.
  ///
  /// In de, this message translates to:
  /// **'{what} kopiert'**
  String copied(Object what);

  /// No description provided for @copiedClearsSoon.
  ///
  /// In de, this message translates to:
  /// **'{what} kopiert – wird nach 30 s aus der Zwischenablage entfernt'**
  String copiedClearsSoon(Object what);

  /// No description provided for @serverVersion.
  ///
  /// In de, this message translates to:
  /// **'Version {version}'**
  String serverVersion(Object version);

  /// No description provided for @noHttpsWarning.
  ///
  /// In de, this message translates to:
  /// **'Ohne HTTPS – nur im eigenen Netz verwenden!'**
  String get noHttpsWarning;

  /// No description provided for @settings.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get settings;

  /// No description provided for @sectionSecurity.
  ///
  /// In de, this message translates to:
  /// **'Sicherheit'**
  String get sectionSecurity;

  /// No description provided for @autoLock.
  ///
  /// In de, this message translates to:
  /// **'Automatisch sperren'**
  String get autoLock;

  /// No description provided for @quickUnlockHardwareHint.
  ///
  /// In de, this message translates to:
  /// **'Statt des Master-Passworts. Der Schlüssel ist an die Biometrie dieses Geräts gebunden; wird ein neuer Finger oder ein neues Gesicht registriert, braucht es wieder das Passwort.'**
  String get quickUnlockHardwareHint;

  /// No description provided for @quickUnlockKeychainHint.
  ///
  /// In de, this message translates to:
  /// **'Statt des Master-Passworts. Der Schlüssel liegt dafür im Schlüsselbund dieses Geräts.'**
  String get quickUnlockKeychainHint;

  /// No description provided for @hideCodes.
  ///
  /// In de, this message translates to:
  /// **'Codes verbergen'**
  String get hideCodes;

  /// No description provided for @hideCodesHint.
  ///
  /// In de, this message translates to:
  /// **'Erst nach Antippen anzeigen'**
  String get hideCodesHint;

  /// No description provided for @clearClipboard.
  ///
  /// In de, this message translates to:
  /// **'Zwischenablage leeren'**
  String get clearClipboard;

  /// No description provided for @clearClipboardHint.
  ///
  /// In de, this message translates to:
  /// **'Kopierte Codes nach 30 Sekunden entfernen'**
  String get clearClipboardHint;

  /// No description provided for @allowScreenshots.
  ///
  /// In de, this message translates to:
  /// **'Bildschirmfotos erlauben'**
  String get allowScreenshots;

  /// No description provided for @allowScreenshotsHint.
  ///
  /// In de, this message translates to:
  /// **'Sonst sind Screenshots und Bildschirmaufnahmen gesperrt'**
  String get allowScreenshotsHint;

  /// No description provided for @changeMasterPassword.
  ///
  /// In de, this message translates to:
  /// **'Master-Passwort ändern'**
  String get changeMasterPassword;

  /// No description provided for @newRecoveryKey.
  ///
  /// In de, this message translates to:
  /// **'Neuer Wiederherstellungsschlüssel'**
  String get newRecoveryKey;

  /// No description provided for @newRecoveryKeyHint.
  ///
  /// In de, this message translates to:
  /// **'Der bisherige wird ungültig'**
  String get newRecoveryKeyHint;

  /// No description provided for @signedInDevices.
  ///
  /// In de, this message translates to:
  /// **'Angemeldete Geräte'**
  String get signedInDevices;

  /// No description provided for @trash.
  ///
  /// In de, this message translates to:
  /// **'Papierkorb'**
  String get trash;

  /// No description provided for @trashHint.
  ///
  /// In de, this message translates to:
  /// **'Gelöschte Konten der letzten 30 Tage'**
  String get trashHint;

  /// No description provided for @activity.
  ///
  /// In de, this message translates to:
  /// **'Aktivitäten'**
  String get activity;

  /// No description provided for @activityHint.
  ///
  /// In de, this message translates to:
  /// **'Anmeldungen und Änderungen am Konto'**
  String get activityHint;

  /// No description provided for @sectionDesktop.
  ///
  /// In de, this message translates to:
  /// **'Schreibtisch'**
  String get sectionDesktop;

  /// No description provided for @keepInMenuBar.
  ///
  /// In de, this message translates to:
  /// **'In der Menüleiste weiterlaufen'**
  String get keepInMenuBar;

  /// No description provided for @keepInTray.
  ///
  /// In de, this message translates to:
  /// **'Im Infobereich weiterlaufen'**
  String get keepInTray;

  /// No description provided for @keepInTrayHint.
  ///
  /// In de, this message translates to:
  /// **'Beim Schließen des Fensters bleibt Sixora erreichbar. Über das Symbol lassen sich die Codes der Favoriten kopieren oder alle Konten durchsuchen.'**
  String get keepInTrayHint;

  /// No description provided for @shortcutTitle.
  ///
  /// In de, this message translates to:
  /// **'Tastenkürzel {shortcut}'**
  String shortcutTitle(Object shortcut);

  /// No description provided for @shortcutHint.
  ///
  /// In de, this message translates to:
  /// **'Holt Sixora von überall nach vorn, mit dem Cursor in der Suche.'**
  String get shortcutHint;

  /// No description provided for @sectionDisplay.
  ///
  /// In de, this message translates to:
  /// **'Anzeige'**
  String get sectionDisplay;

  /// No description provided for @showNextCode.
  ///
  /// In de, this message translates to:
  /// **'Nächsten Code anzeigen'**
  String get showNextCode;

  /// No description provided for @showNextCodeHint.
  ///
  /// In de, this message translates to:
  /// **'In den letzten 5 Sekunden eines Codes'**
  String get showNextCodeHint;

  /// No description provided for @appearance.
  ///
  /// In de, this message translates to:
  /// **'Erscheinungsbild'**
  String get appearance;

  /// No description provided for @themeSystem.
  ///
  /// In de, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In de, this message translates to:
  /// **'Hell'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In de, this message translates to:
  /// **'Dunkel'**
  String get themeDark;

  /// No description provided for @sectionVaultsData.
  ///
  /// In de, this message translates to:
  /// **'Tresore und Daten'**
  String get sectionVaultsData;

  /// No description provided for @vaultsAndSharing.
  ///
  /// In de, this message translates to:
  /// **'Tresore und Teilen'**
  String get vaultsAndSharing;

  /// No description provided for @importAction.
  ///
  /// In de, this message translates to:
  /// **'Importieren'**
  String get importAction;

  /// No description provided for @exportAction.
  ///
  /// In de, this message translates to:
  /// **'Exportieren'**
  String get exportAction;

  /// No description provided for @exportHint.
  ///
  /// In de, this message translates to:
  /// **'Verschlüsselte Sicherung, Textdatei oder QR-Codes'**
  String get exportHint;

  /// No description provided for @autoBackup.
  ///
  /// In de, this message translates to:
  /// **'Automatische Sicherung'**
  String get autoBackup;

  /// No description provided for @off.
  ///
  /// In de, this message translates to:
  /// **'Aus'**
  String get off;

  /// No description provided for @errorWith.
  ///
  /// In de, this message translates to:
  /// **'Fehler: {error}'**
  String errorWith(Object error);

  /// No description provided for @backupFolderLast.
  ///
  /// In de, this message translates to:
  /// **'{folder} · zuletzt {time}'**
  String backupFolderLast(Object folder, Object time);

  /// No description provided for @accountCheck.
  ///
  /// In de, this message translates to:
  /// **'Kontenprüfung'**
  String get accountCheck;

  /// No description provided for @accountCheckHint.
  ///
  /// In de, this message translates to:
  /// **'Doppelte Konten, schwache Schlüssel, fehlende Logos'**
  String get accountCheckHint;

  /// No description provided for @sectionServer.
  ///
  /// In de, this message translates to:
  /// **'Server'**
  String get sectionServer;

  /// No description provided for @administration.
  ///
  /// In de, this message translates to:
  /// **'Verwaltung'**
  String get administration;

  /// No description provided for @administrationHint.
  ///
  /// In de, this message translates to:
  /// **'Benutzer, Einladungen, Protokoll'**
  String get administrationHint;

  /// No description provided for @sectionAccount.
  ///
  /// In de, this message translates to:
  /// **'Konto'**
  String get sectionAccount;

  /// No description provided for @signOutHint.
  ///
  /// In de, this message translates to:
  /// **'Entfernt die lokale Kopie von diesem Gerät'**
  String get signOutHint;

  /// No description provided for @signOutMessage.
  ///
  /// In de, this message translates to:
  /// **'Deine Codes bleiben auf dem Server. Zum erneuten Anmelden brauchst du Benutzername und Master-Passwort.'**
  String get signOutMessage;

  /// No description provided for @deleteAccount.
  ///
  /// In de, this message translates to:
  /// **'Konto löschen'**
  String get deleteAccount;

  /// No description provided for @sectionAbout.
  ///
  /// In de, this message translates to:
  /// **'Über'**
  String get sectionAbout;

  /// No description provided for @currentPassword.
  ///
  /// In de, this message translates to:
  /// **'Aktuelles Passwort'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In de, this message translates to:
  /// **'Neues Passwort'**
  String get newPassword;

  /// No description provided for @newPasswordHint.
  ///
  /// In de, this message translates to:
  /// **'Mindestens 10 Zeichen. Andere Geräte werden abgemeldet.'**
  String get newPasswordHint;

  /// No description provided for @repeatNewPassword.
  ///
  /// In de, this message translates to:
  /// **'Neues Passwort wiederholen'**
  String get repeatNewPassword;

  /// No description provided for @newPasswordTooShort.
  ///
  /// In de, this message translates to:
  /// **'Das neue Passwort braucht mindestens 10 Zeichen'**
  String get newPasswordTooShort;

  /// No description provided for @newPasswordsDoNotMatch.
  ///
  /// In de, this message translates to:
  /// **'Die neuen Passwörter stimmen nicht überein'**
  String get newPasswordsDoNotMatch;

  /// No description provided for @changingPassword.
  ///
  /// In de, this message translates to:
  /// **'Passwort wird geändert …'**
  String get changingPassword;

  /// No description provided for @masterPasswordChanged.
  ///
  /// In de, this message translates to:
  /// **'Master-Passwort geändert. Andere Geräte müssen sich neu anmelden.'**
  String get masterPasswordChanged;

  /// No description provided for @newRecoveryKeyConfirm.
  ///
  /// In de, this message translates to:
  /// **'Zur Bestätigung das Master-Passwort eingeben. Der bisherige Schlüssel wird ungültig.'**
  String get newRecoveryKeyConfirm;

  /// No description provided for @generate.
  ///
  /// In de, this message translates to:
  /// **'Erzeugen'**
  String get generate;

  /// No description provided for @deleteAccountQuestion.
  ///
  /// In de, this message translates to:
  /// **'Konto endgültig löschen?'**
  String get deleteAccountQuestion;

  /// No description provided for @deleteAccountMessage.
  ///
  /// In de, this message translates to:
  /// **'Alle deine Codes und die Tresore, die dir gehören – auch geteilte –, werden auf dem Server gelöscht. Das lässt sich nicht rückgängig machen. Deaktiviere vorher die Zwei-Faktor-Anmeldung bei den Diensten oder exportiere deine Konten.'**
  String get deleteAccountMessage;

  /// No description provided for @confirmMasterPassword.
  ///
  /// In de, this message translates to:
  /// **'Master-Passwort bestätigen'**
  String get confirmMasterPassword;

  /// No description provided for @nothingToExport.
  ///
  /// In de, this message translates to:
  /// **'Keine Konten zum Exportieren'**
  String get nothingToExport;

  /// No description provided for @encryptedBackup.
  ///
  /// In de, this message translates to:
  /// **'Verschlüsselte Sicherung'**
  String get encryptedBackup;

  /// No description provided for @encryptedBackupHint.
  ///
  /// In de, this message translates to:
  /// **'Mit eigenem Passwort, lässt sich in Sixora importieren'**
  String get encryptedBackupHint;

  /// No description provided for @googleAuthenticatorQr.
  ///
  /// In de, this message translates to:
  /// **'QR-Codes für Google Authenticator'**
  String get googleAuthenticatorQr;

  /// No description provided for @googleAuthenticatorQrHint.
  ///
  /// In de, this message translates to:
  /// **'Zum Übertragen in eine andere App'**
  String get googleAuthenticatorQrHint;

  /// No description provided for @plainTextFile.
  ///
  /// In de, this message translates to:
  /// **'Unverschlüsselte Textdatei'**
  String get plainTextFile;

  /// No description provided for @plainTextFileHint.
  ///
  /// In de, this message translates to:
  /// **'otpauth-Links, für andere Apps – nur mit Vorsicht'**
  String get plainTextFileHint;

  /// No description provided for @encryptingBackup.
  ///
  /// In de, this message translates to:
  /// **'Sicherung wird verschlüsselt …'**
  String get encryptingBackup;

  /// No description provided for @exportUnencryptedQuestion.
  ///
  /// In de, this message translates to:
  /// **'Unverschlüsselt exportieren?'**
  String get exportUnencryptedQuestion;

  /// No description provided for @exportUnencryptedMessage.
  ///
  /// In de, this message translates to:
  /// **'Die Datei enthält alle geheimen Schlüssel im Klartext. Wer sie liest, kann deine Codes erzeugen. Nach dem Import sofort löschen.'**
  String get exportUnencryptedMessage;

  /// No description provided for @saveAs.
  ///
  /// In de, this message translates to:
  /// **'Speichern unter'**
  String get saveAs;

  /// No description provided for @saved.
  ///
  /// In de, this message translates to:
  /// **'Gespeichert'**
  String get saved;

  /// No description provided for @openOtpauthLinks.
  ///
  /// In de, this message translates to:
  /// **'otpauth-Links mit Sixora öffnen'**
  String get openOtpauthLinks;

  /// No description provided for @otpauthLinksOpenSixora.
  ///
  /// In de, this message translates to:
  /// **'Links zum Einrichten von Konten öffnen Sixora.'**
  String get otpauthLinksOpenSixora;

  /// No description provided for @notChanged.
  ///
  /// In de, this message translates to:
  /// **'Nicht geändert: {reason}'**
  String notChanged(Object reason);

  /// No description provided for @useSixora.
  ///
  /// In de, this message translates to:
  /// **'Sixora verwenden'**
  String get useSixora;

  /// No description provided for @administrator.
  ///
  /// In de, this message translates to:
  /// **'Administrator'**
  String get administrator;

  /// No description provided for @lastSynced.
  ///
  /// In de, this message translates to:
  /// **'Zuletzt synchronisiert: {time}'**
  String lastSynced(Object time);

  /// No description provided for @aboutText.
  ///
  /// In de, this message translates to:
  /// **'Codes werden auf deinen Geräten berechnet. Der Server speichert nur verschlüsselte Daten.'**
  String get aboutText;

  /// No description provided for @linksOpenOtherApp.
  ///
  /// In de, this message translates to:
  /// **'Zurzeit öffnet sie eine andere App.'**
  String get linksOpenOtherApp;

  /// No description provided for @linksOpenApp.
  ///
  /// In de, this message translates to:
  /// **'Zurzeit öffnet sie „{app}“.'**
  String linksOpenApp(Object app);

  /// No description provided for @vaultCount.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Tresor} other{{count} Tresore}}'**
  String vaultCount(int count);

  /// No description provided for @language.
  ///
  /// In de, this message translates to:
  /// **'Sprache'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In de, this message translates to:
  /// **'System'**
  String get languageSystem;

  /// No description provided for @offerBiometricsTitle.
  ///
  /// In de, this message translates to:
  /// **'Mit {method} entsperren?'**
  String offerBiometricsTitle(Object method);

  /// No description provided for @offerBiometricsMessage.
  ///
  /// In de, this message translates to:
  /// **'Dann reicht zum Entsperren {method} statt des Master-Passworts. Das Passwort brauchst du weiterhin für Kontoänderungen und auf neuen Geräten.'**
  String offerBiometricsMessage(Object method);

  /// No description provided for @notNow.
  ///
  /// In de, this message translates to:
  /// **'Nicht jetzt'**
  String get notNow;

  /// No description provided for @setUp.
  ///
  /// In de, this message translates to:
  /// **'Einrichten'**
  String get setUp;

  /// No description provided for @biometricsEnabled.
  ///
  /// In de, this message translates to:
  /// **'Sixora lässt sich jetzt mit {method} entsperren'**
  String biometricsEnabled(Object method);

  /// No description provided for @setUpLaterInSettings.
  ///
  /// In de, this message translates to:
  /// **'Lässt sich später unter Einstellungen einrichten'**
  String get setUpLaterInSettings;

  /// No description provided for @codeFor.
  ///
  /// In de, this message translates to:
  /// **'Code für {name}'**
  String codeFor(Object name);

  /// No description provided for @scanQrCode.
  ///
  /// In de, this message translates to:
  /// **'QR-Code scannen'**
  String get scanQrCode;

  /// No description provided for @withCamera.
  ///
  /// In de, this message translates to:
  /// **'Mit der Kamera'**
  String get withCamera;

  /// No description provided for @qrFromImage.
  ///
  /// In de, this message translates to:
  /// **'QR-Code aus Bild'**
  String get qrFromImage;

  /// No description provided for @qrFromImageHint.
  ///
  /// In de, this message translates to:
  /// **'Screenshot oder Foto auswählen'**
  String get qrFromImageHint;

  /// No description provided for @linkFromClipboard.
  ///
  /// In de, this message translates to:
  /// **'Link aus Zwischenablage'**
  String get linkFromClipboard;

  /// No description provided for @linkFromClipboardHint.
  ///
  /// In de, this message translates to:
  /// **'otpauth://… einfügen'**
  String get linkFromClipboardHint;

  /// No description provided for @enterManually.
  ///
  /// In de, this message translates to:
  /// **'Manuell eingeben'**
  String get enterManually;

  /// No description provided for @enterManuallyHint.
  ///
  /// In de, this message translates to:
  /// **'Schlüssel abtippen'**
  String get enterManuallyHint;

  /// No description provided for @importHint.
  ///
  /// In de, this message translates to:
  /// **'Google Authenticator, Aegis, 2FAuth, Sixora …'**
  String get importHint;

  /// No description provided for @chooseQrImages.
  ///
  /// In de, this message translates to:
  /// **'Bilder mit QR-Codes auswählen'**
  String get chooseQrImages;

  /// No description provided for @searchingQr.
  ///
  /// In de, this message translates to:
  /// **'QR-Code wird gesucht …'**
  String get searchingQr;

  /// No description provided for @searchingQrInImages.
  ///
  /// In de, this message translates to:
  /// **'QR-Codes in {count} Bildern werden gesucht …'**
  String searchingQrInImages(int count);

  /// No description provided for @noQrInImage.
  ///
  /// In de, this message translates to:
  /// **'Kein QR-Code im Bild gefunden'**
  String get noQrInImage;

  /// No description provided for @noQrInImages.
  ///
  /// In de, this message translates to:
  /// **'In den Bildern wurde kein QR-Code gefunden'**
  String get noQrInImages;

  /// No description provided for @linkIncomplete.
  ///
  /// In de, this message translates to:
  /// **'Link ist unvollständig: {reason}'**
  String linkIncomplete(Object reason);

  /// No description provided for @notA2faLink.
  ///
  /// In de, this message translates to:
  /// **'Das ist kein 2FA-Code (otpauth://…)'**
  String get notA2faLink;

  /// No description provided for @noWritableVault.
  ///
  /// In de, this message translates to:
  /// **'Kein Tresor mit Schreibrecht vorhanden'**
  String get noWritableVault;

  /// No description provided for @alreadyThere.
  ///
  /// In de, this message translates to:
  /// **'Schon vorhanden'**
  String get alreadyThere;

  /// No description provided for @alreadyThereMessage.
  ///
  /// In de, this message translates to:
  /// **'Dieses Konto ist bereits gespeichert. Trotzdem noch einmal anlegen?'**
  String get alreadyThereMessage;

  /// No description provided for @addAnyway.
  ///
  /// In de, this message translates to:
  /// **'Anlegen'**
  String get addAnyway;

  /// No description provided for @edit.
  ///
  /// In de, this message translates to:
  /// **'Bearbeiten'**
  String get edit;

  /// No description provided for @removeFavorite.
  ///
  /// In de, this message translates to:
  /// **'Kein Favorit mehr'**
  String get removeFavorite;

  /// No description provided for @makeFavorite.
  ///
  /// In de, this message translates to:
  /// **'Als Favorit'**
  String get makeFavorite;

  /// No description provided for @moveToVault.
  ///
  /// In de, this message translates to:
  /// **'In anderen Tresor verschieben'**
  String get moveToVault;

  /// No description provided for @transferQr.
  ///
  /// In de, this message translates to:
  /// **'Übertragen (QR-Code)'**
  String get transferQr;

  /// No description provided for @delete.
  ///
  /// In de, this message translates to:
  /// **'Löschen'**
  String get delete;

  /// No description provided for @showSecretQuestion.
  ///
  /// In de, this message translates to:
  /// **'Geheimen Schlüssel anzeigen?'**
  String get showSecretQuestion;

  /// No description provided for @showSecretMessage.
  ///
  /// In de, this message translates to:
  /// **'Der QR-Code enthält den geheimen Schlüssel. Wer ihn sieht oder fotografiert, kann deine Codes erzeugen.'**
  String get showSecretMessage;

  /// No description provided for @deleteEntryQuestion.
  ///
  /// In de, this message translates to:
  /// **'„{name}“ löschen?'**
  String deleteEntryQuestion(Object name);

  /// No description provided for @entryDeleted.
  ///
  /// In de, this message translates to:
  /// **'„{name}“ gelöscht'**
  String entryDeleted(Object name);

  /// No description provided for @undo.
  ///
  /// In de, this message translates to:
  /// **'Rückgängig'**
  String get undo;

  /// No description provided for @moveTo.
  ///
  /// In de, this message translates to:
  /// **'Verschieben nach'**
  String get moveTo;

  /// No description provided for @synchronize.
  ///
  /// In de, this message translates to:
  /// **'Synchronisieren'**
  String get synchronize;

  /// No description provided for @lock.
  ///
  /// In de, this message translates to:
  /// **'Sperren'**
  String get lock;

  /// No description provided for @add.
  ///
  /// In de, this message translates to:
  /// **'Hinzufügen'**
  String get add;

  /// No description provided for @all.
  ///
  /// In de, this message translates to:
  /// **'Alle'**
  String get all;

  /// No description provided for @favorites.
  ///
  /// In de, this message translates to:
  /// **'Favoriten'**
  String get favorites;

  /// No description provided for @syncErrorBanner.
  ///
  /// In de, this message translates to:
  /// **'{error}\nDie Codes funktionieren trotzdem; Änderungen brauchen eine Verbindung.'**
  String syncErrorBanner(Object error);

  /// No description provided for @undecryptableEntries.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Eintrag lässt sich nicht entschlüsseln.} other{{count} Einträge lassen sich nicht entschlüsseln.}}'**
  String undecryptableEntries(int count);

  /// No description provided for @noMatches.
  ///
  /// In de, this message translates to:
  /// **'Keine Treffer'**
  String get noMatches;

  /// No description provided for @noAccountsYet.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Konten'**
  String get noAccountsYet;

  /// No description provided for @noAccountsHint.
  ///
  /// In de, this message translates to:
  /// **'Aktiviere bei einem Dienst die Zwei-Faktor-Anmeldung und scanne den angezeigten QR-Code – oder importiere deine Konten aus einer anderen App.'**
  String get noAccountsHint;

  /// No description provided for @addAccount.
  ///
  /// In de, this message translates to:
  /// **'Konto hinzufügen'**
  String get addAccount;

  /// No description provided for @search.
  ///
  /// In de, this message translates to:
  /// **'Suchen'**
  String get search;

  /// No description provided for @clear.
  ///
  /// In de, this message translates to:
  /// **'Leeren'**
  String get clear;

  /// No description provided for @signOutDeviceQuestion.
  ///
  /// In de, this message translates to:
  /// **'Gerät abmelden?'**
  String get signOutDeviceQuestion;

  /// No description provided for @signOutDeviceMessage.
  ///
  /// In de, this message translates to:
  /// **'„{device}“ verliert sofort den Zugriff. Warst du das nicht, ändere danach auch dein Master-Passwort: Wer sich anmelden konnte, kennt es.'**
  String signOutDeviceMessage(Object device);

  /// No description provided for @deviceSignedOut.
  ///
  /// In de, this message translates to:
  /// **'Gerät abgemeldet'**
  String get deviceSignedOut;

  /// No description provided for @newSignIn.
  ///
  /// In de, this message translates to:
  /// **'Neue Anmeldung: {device}{platform}, {time}'**
  String newSignIn(Object device, Object platform, Object time);

  /// No description provided for @thatWasMe.
  ///
  /// In de, this message translates to:
  /// **'Das war ich'**
  String get thatWasMe;

  /// No description provided for @deleteEntryMessage.
  ///
  /// In de, this message translates to:
  /// **'Der Eintrag verschwindet auf allen Geräten. 30 Tage lang lässt er sich im Papierkorb (Einstellungen) wiederherstellen.'**
  String get deleteEntryMessage;

  /// No description provided for @deleteEntrySharedMessage.
  ///
  /// In de, this message translates to:
  /// **'Der Eintrag verschwindet auf allen Geräten und bei allen, mit denen der Tresor geteilt ist. 30 Tage lang lässt er sich im Papierkorb (Einstellungen) wiederherstellen.'**
  String get deleteEntrySharedMessage;

  /// No description provided for @newVault.
  ///
  /// In de, this message translates to:
  /// **'Neuer Tresor'**
  String get newVault;

  /// No description provided for @newVaultMessage.
  ///
  /// In de, this message translates to:
  /// **'Ein eigener Tresor lässt sich mit anderen Benutzern dieses Servers teilen, z. B. „Team“ oder „Familie“.'**
  String get newVaultMessage;

  /// No description provided for @name.
  ///
  /// In de, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @vaultsExplanation.
  ///
  /// In de, this message translates to:
  /// **'Jeder Tresor hat einen eigenen Schlüssel. Beim Teilen wird er mit dem öffentlichen Schlüssel des Empfängers verschlüsselt – der Server sieht die Codes nie.'**
  String get vaultsExplanation;

  /// No description provided for @personal.
  ///
  /// In de, this message translates to:
  /// **'Persönlich'**
  String get personal;

  /// No description provided for @ownedBy.
  ///
  /// In de, this message translates to:
  /// **'von {owner}'**
  String ownedBy(Object owner);

  /// No description provided for @roleOwner.
  ///
  /// In de, this message translates to:
  /// **'Eigentümer'**
  String get roleOwner;

  /// No description provided for @roleWrite.
  ///
  /// In de, this message translates to:
  /// **'Lesen und Schreiben'**
  String get roleWrite;

  /// No description provided for @roleRead.
  ///
  /// In de, this message translates to:
  /// **'Nur lesen'**
  String get roleRead;

  /// No description provided for @accountCount.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Konto} other{{count} Konten}}'**
  String accountCount(int count);

  /// No description provided for @memberCount.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Mitglied} other{{count} Mitglieder}}'**
  String memberCount(int count);

  /// No description provided for @shareWith.
  ///
  /// In de, this message translates to:
  /// **'Teilen mit'**
  String get shareWith;

  /// No description provided for @thatIsYou.
  ///
  /// In de, this message translates to:
  /// **'Das bist du selbst'**
  String get thatIsYou;

  /// No description provided for @shareWithUser.
  ///
  /// In de, this message translates to:
  /// **'Mit {user} teilen'**
  String shareWithUser(Object user);

  /// No description provided for @compareFingerprint.
  ///
  /// In de, this message translates to:
  /// **'Vergleicht zur Sicherheit den Schlüssel-Fingerabdruck, z. B. am Telefon. Er steht bei der anderen Person unter „Tresore und Teilen“. Stimmt er nicht, nicht teilen.'**
  String get compareFingerprint;

  /// No description provided for @fingerprintOf.
  ///
  /// In de, this message translates to:
  /// **'Fingerabdruck von {user}:'**
  String fingerprintOf(Object user);

  /// No description provided for @roleReadHint.
  ///
  /// In de, this message translates to:
  /// **'Codes sehen und kopieren'**
  String get roleReadHint;

  /// No description provided for @roleWriteHint.
  ///
  /// In de, this message translates to:
  /// **'Auch Konten hinzufügen, ändern und löschen'**
  String get roleWriteHint;

  /// No description provided for @share.
  ///
  /// In de, this message translates to:
  /// **'Teilen'**
  String get share;

  /// No description provided for @vaultGone.
  ///
  /// In de, this message translates to:
  /// **'Tresor nicht mehr verfügbar'**
  String get vaultGone;

  /// No description provided for @rename.
  ///
  /// In de, this message translates to:
  /// **'Umbenennen'**
  String get rename;

  /// No description provided for @personalVaultNotShared.
  ///
  /// In de, this message translates to:
  /// **'Dein persönlicher Tresor kann nicht geteilt werden.'**
  String get personalVaultNotShared;

  /// No description provided for @personalVaultNotSharedHint.
  ///
  /// In de, this message translates to:
  /// **'Lege für gemeinsame Konten einen eigenen Tresor an und verschiebe sie dorthin.'**
  String get personalVaultNotSharedHint;

  /// No description provided for @yourFingerprint.
  ///
  /// In de, this message translates to:
  /// **'Dein Schlüssel-Fingerabdruck'**
  String get yourFingerprint;

  /// No description provided for @members.
  ///
  /// In de, this message translates to:
  /// **'Mitglieder'**
  String get members;

  /// No description provided for @memberYou.
  ///
  /// In de, this message translates to:
  /// **'{user} (du)'**
  String memberYou(Object user);

  /// No description provided for @remove.
  ///
  /// In de, this message translates to:
  /// **'Entfernen'**
  String get remove;

  /// No description provided for @removeMemberQuestion.
  ///
  /// In de, this message translates to:
  /// **'{user} entfernen?'**
  String removeMemberQuestion(Object user);

  /// No description provided for @removeMemberMessage.
  ///
  /// In de, this message translates to:
  /// **'{user} verliert den Zugriff auf diesen Tresor. Sixora erneuert danach den Schlüssel des Tresors, damit der alte nichts mehr öffnet. Schlüssel von Konten, die {user} schon gesehen hat, bleiben aber bekannt – bei Bedarf beim Dienst neu einrichten.'**
  String removeMemberMessage(Object user);

  /// No description provided for @deleteVault.
  ///
  /// In de, this message translates to:
  /// **'Tresor löschen'**
  String get deleteVault;

  /// No description provided for @deleteVaultHint.
  ///
  /// In de, this message translates to:
  /// **'Mit allen Konten darin, für alle Mitglieder'**
  String get deleteVaultHint;

  /// No description provided for @deleteVaultQuestion.
  ///
  /// In de, this message translates to:
  /// **'„{name}“ löschen?'**
  String deleteVaultQuestion(Object name);

  /// No description provided for @deleteVaultMessage.
  ///
  /// In de, this message translates to:
  /// **'Alle Konten in diesem Tresor werden für alle Mitglieder gelöscht.'**
  String get deleteVaultMessage;

  /// No description provided for @leaveVault.
  ///
  /// In de, this message translates to:
  /// **'Tresor verlassen'**
  String get leaveVault;

  /// No description provided for @leaveVaultQuestion.
  ///
  /// In de, this message translates to:
  /// **'„{name}“ verlassen?'**
  String leaveVaultQuestion(Object name);

  /// No description provided for @leaveVaultMessage.
  ///
  /// In de, this message translates to:
  /// **'Du siehst die Konten darin nicht mehr, bis du erneut eingeladen wirst.'**
  String get leaveVaultMessage;

  /// No description provided for @leave.
  ///
  /// In de, this message translates to:
  /// **'Verlassen'**
  String get leave;

  /// No description provided for @editAccount.
  ///
  /// In de, this message translates to:
  /// **'Konto bearbeiten'**
  String get editAccount;

  /// No description provided for @save.
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get save;

  /// No description provided for @newAccount.
  ///
  /// In de, this message translates to:
  /// **'Neues Konto'**
  String get newAccount;

  /// No description provided for @enterKey.
  ///
  /// In de, this message translates to:
  /// **'Schlüssel eingeben …'**
  String get enterKey;

  /// No description provided for @service.
  ///
  /// In de, this message translates to:
  /// **'Dienst'**
  String get service;

  /// No description provided for @serviceExample.
  ///
  /// In de, this message translates to:
  /// **'z. B. GitHub'**
  String get serviceExample;

  /// No description provided for @accountName.
  ///
  /// In de, this message translates to:
  /// **'Konto'**
  String get accountName;

  /// No description provided for @accountExample.
  ///
  /// In de, this message translates to:
  /// **'z. B. name@example.org'**
  String get accountExample;

  /// No description provided for @secretKey.
  ///
  /// In de, this message translates to:
  /// **'Geheimer Schlüssel'**
  String get secretKey;

  /// No description provided for @secretKeyHint.
  ///
  /// In de, this message translates to:
  /// **'Base32, Leerzeichen sind egal'**
  String get secretKeyHint;

  /// No description provided for @groupOptional.
  ///
  /// In de, this message translates to:
  /// **'Gruppe (optional)'**
  String get groupOptional;

  /// No description provided for @groupExample.
  ///
  /// In de, this message translates to:
  /// **'z. B. Arbeit'**
  String get groupExample;

  /// No description provided for @chooseGroup.
  ///
  /// In de, this message translates to:
  /// **'Vorhandene Gruppe wählen'**
  String get chooseGroup;

  /// No description provided for @vault.
  ///
  /// In de, this message translates to:
  /// **'Tresor'**
  String get vault;

  /// No description provided for @favorite.
  ///
  /// In de, this message translates to:
  /// **'Favorit'**
  String get favorite;

  /// No description provided for @favoriteHint.
  ///
  /// In de, this message translates to:
  /// **'Steht oben in der Liste'**
  String get favoriteHint;

  /// No description provided for @icon.
  ///
  /// In de, this message translates to:
  /// **'Symbol'**
  String get icon;

  /// No description provided for @initialLetter.
  ///
  /// In de, this message translates to:
  /// **'Anfangsbuchstabe'**
  String get initialLetter;

  /// No description provided for @iconAutomatic.
  ///
  /// In de, this message translates to:
  /// **'{name} (automatisch)'**
  String iconAutomatic(Object name);

  /// No description provided for @initialLetterNoLogo.
  ///
  /// In de, this message translates to:
  /// **'Anfangsbuchstabe (kein passendes Logo gefunden)'**
  String get initialLetterNoLogo;

  /// No description provided for @unknown.
  ///
  /// In de, this message translates to:
  /// **'Unbekannt'**
  String get unknown;

  /// No description provided for @color.
  ///
  /// In de, this message translates to:
  /// **'Farbe'**
  String get color;

  /// No description provided for @colorAuto.
  ///
  /// In de, this message translates to:
  /// **'Auto'**
  String get colorAuto;

  /// No description provided for @notesOptional.
  ///
  /// In de, this message translates to:
  /// **'Notizen (optional)'**
  String get notesOptional;

  /// No description provided for @advanced.
  ///
  /// In de, this message translates to:
  /// **'Erweitert'**
  String get advanced;

  /// No description provided for @timeBased.
  ///
  /// In de, this message translates to:
  /// **'Zeitbasiert'**
  String get timeBased;

  /// No description provided for @counter.
  ///
  /// In de, this message translates to:
  /// **'Zähler'**
  String get counter;

  /// No description provided for @algorithm.
  ///
  /// In de, this message translates to:
  /// **'Algorithmus'**
  String get algorithm;

  /// No description provided for @digits.
  ///
  /// In de, this message translates to:
  /// **'Stellen'**
  String get digits;

  /// No description provided for @periodSeconds.
  ///
  /// In de, this message translates to:
  /// **'Intervall (s)'**
  String get periodSeconds;

  /// No description provided for @chooseIcon.
  ///
  /// In de, this message translates to:
  /// **'Symbol wählen'**
  String get chooseIcon;

  /// No description provided for @searchServiceExample.
  ///
  /// In de, this message translates to:
  /// **'Dienst suchen, z. B. Google'**
  String get searchServiceExample;

  /// No description provided for @automatic.
  ///
  /// In de, this message translates to:
  /// **'Automatisch'**
  String get automatic;

  /// No description provided for @letter.
  ///
  /// In de, this message translates to:
  /// **'Buchstabe'**
  String get letter;

  /// No description provided for @noLogoFound.
  ///
  /// In de, this message translates to:
  /// **'Kein Logo gefunden'**
  String get noLogoFound;

  /// No description provided for @logosCredit.
  ///
  /// In de, this message translates to:
  /// **'Logos: Simple Icons {version}. Die Marken gehören ihren Inhabern.'**
  String logosCredit(Object version);

  /// No description provided for @digitsCount.
  ///
  /// In de, this message translates to:
  /// **'{count} Stellen'**
  String digitsCount(int count);

  /// No description provided for @unexpectedError.
  ///
  /// In de, this message translates to:
  /// **'Unerwarteter Fehler: {error}'**
  String unexpectedError(Object error);

  /// No description provided for @biometrics.
  ///
  /// In de, this message translates to:
  /// **'Biometrie'**
  String get biometrics;

  /// No description provided for @enterServerAddress.
  ///
  /// In de, this message translates to:
  /// **'Bitte die Server-Adresse eingeben'**
  String get enterServerAddress;

  /// No description provided for @invalidAddress.
  ///
  /// In de, this message translates to:
  /// **'Ungültige Adresse'**
  String get invalidAddress;

  /// No description provided for @httpOnlyLocal.
  ///
  /// In de, this message translates to:
  /// **'Unverschlüsseltes HTTP ist nur im lokalen Netz erlaubt. Bitte https:// verwenden.'**
  String get httpOnlyLocal;

  /// No description provided for @recoveryKeyMismatch.
  ///
  /// In de, this message translates to:
  /// **'Wiederherstellungsschlüssel passt nicht'**
  String get recoveryKeyMismatch;

  /// No description provided for @masterPasswordWrong.
  ///
  /// In de, this message translates to:
  /// **'Master-Passwort ist falsch'**
  String get masterPasswordWrong;

  /// No description provided for @biometricsInvalidatedEnrolled.
  ///
  /// In de, this message translates to:
  /// **'Entsperren mit {method} ist nicht mehr gültig, z. B. weil ein Finger oder Gesicht neu registriert wurde. Bitte mit dem Master-Passwort entsperren und es danach neu einrichten.'**
  String biometricsInvalidatedEnrolled(Object method);

  /// No description provided for @biometricsInvalidated.
  ///
  /// In de, this message translates to:
  /// **'Entsperren mit {method} ist nicht mehr gültig. Bitte mit dem Master-Passwort entsperren.'**
  String biometricsInvalidated(Object method);

  /// No description provided for @biometricsSetupFailed.
  ///
  /// In de, this message translates to:
  /// **'{method} ließ sich nicht einrichten: {reason}'**
  String biometricsSetupFailed(Object method, Object reason);

  /// No description provided for @noSession.
  ///
  /// In de, this message translates to:
  /// **'Keine Sitzung. Bitte sperren und mit Passwort entsperren.'**
  String get noSession;

  /// No description provided for @accountDisabledNotice.
  ///
  /// In de, this message translates to:
  /// **'Dein Konto wurde gesperrt.'**
  String get accountDisabledNotice;

  /// No description provided for @deviceSignedOutNotice.
  ///
  /// In de, this message translates to:
  /// **'Dieses Gerät wurde abgemeldet (Passwort geändert oder Gerät entfernt). Bitte erneut anmelden.'**
  String get deviceSignedOutNotice;

  /// No description provided for @noServerConnection.
  ///
  /// In de, this message translates to:
  /// **'Keine Verbindung zum Server. {reason}.'**
  String noServerConnection(Object reason);

  /// No description provided for @backupWrittenMismatch.
  ///
  /// In de, this message translates to:
  /// **'Die geschriebene Sicherung enthält {found} statt {expected} Konten'**
  String backupWrittenMismatch(Object found, Object expected);

  /// No description provided for @backupFailed.
  ///
  /// In de, this message translates to:
  /// **'Sicherung fehlgeschlagen: {reason}'**
  String backupFailed(Object reason);

  /// No description provided for @backupOtherAccount.
  ///
  /// In de, this message translates to:
  /// **'Die Sicherung wurde für ein anderes Konto eingerichtet. Bitte neu einrichten.'**
  String get backupOtherAccount;

  /// No description provided for @backupNotSetUp.
  ///
  /// In de, this message translates to:
  /// **'Die automatische Sicherung ist nicht eingerichtet'**
  String get backupNotSetUp;

  /// No description provided for @noBackupInFolder.
  ///
  /// In de, this message translates to:
  /// **'Im Ordner liegt keine Sicherung'**
  String get noBackupInFolder;

  /// No description provided for @backupUnreadable.
  ///
  /// In de, this message translates to:
  /// **'Sicherung nicht lesbar: {reason}'**
  String backupUnreadable(Object reason);

  /// No description provided for @vaultKeyRenewed.
  ///
  /// In de, this message translates to:
  /// **'Der Schlüssel des Tresors wurde gerade erneuert. Bitte erneut versuchen.'**
  String get vaultKeyRenewed;

  /// No description provided for @entryChangedElsewhere.
  ///
  /// In de, this message translates to:
  /// **'Der Eintrag wurde inzwischen auf einem anderen Gerät geändert. Die aktuelle Fassung ist geladen, bitte erneut versuchen.'**
  String get entryChangedElsewhere;

  /// No description provided for @vaultReadOnly.
  ///
  /// In de, this message translates to:
  /// **'In diesen Tresor darfst du nicht schreiben'**
  String get vaultReadOnly;

  /// No description provided for @trustedKeysTampered.
  ///
  /// In de, this message translates to:
  /// **'Die gespeicherten Schlüssel deiner Kontakte wurden verändert. Zur Sicherheit wurde abgebrochen. Bitte den Server prüfen.'**
  String get trustedKeysTampered;

  /// No description provided for @aContact.
  ///
  /// In de, this message translates to:
  /// **'einem Kontakt'**
  String get aContact;

  /// No description provided for @memberKeyChanged.
  ///
  /// In de, this message translates to:
  /// **'Der Schlüssel von „{user}“ ist ein anderer als bisher. Ein Benutzerschlüssel ändert sich nie, dieser kommt also nicht von „{user}“. Zur Sicherheit wurde abgebrochen. Bitte den Server prüfen.'**
  String memberKeyChanged(Object user);

  /// No description provided for @currentMasterPasswordWrong.
  ///
  /// In de, this message translates to:
  /// **'Aktuelles Master-Passwort ist falsch'**
  String get currentMasterPasswordWrong;

  /// No description provided for @accountDeletedNotice.
  ///
  /// In de, this message translates to:
  /// **'Dein Konto wurde gelöscht.'**
  String get accountDeletedNotice;

  /// No description provided for @unlockSixora.
  ///
  /// In de, this message translates to:
  /// **'Sixora entsperren'**
  String get unlockSixora;

  /// No description provided for @fingerprint.
  ///
  /// In de, this message translates to:
  /// **'Fingerabdruck'**
  String get fingerprint;

  /// No description provided for @setUpUnlockWith.
  ///
  /// In de, this message translates to:
  /// **'Entsperren mit {method} einrichten'**
  String setUpUnlockWith(Object method);

  /// No description provided for @autoLockImmediately.
  ///
  /// In de, this message translates to:
  /// **'Sofort beim Verlassen'**
  String get autoLockImmediately;

  /// No description provided for @autoLockMinutes.
  ///
  /// In de, this message translates to:
  /// **'{minutes, plural, =1{Nach 1 Minute} other{Nach {minutes} Minuten}}'**
  String autoLockMinutes(int minutes);

  /// No description provided for @autoLockOneHour.
  ///
  /// In de, this message translates to:
  /// **'Nach 1 Stunde'**
  String get autoLockOneHour;

  /// No description provided for @autoLockNever.
  ///
  /// In de, this message translates to:
  /// **'Nie'**
  String get autoLockNever;

  /// No description provided for @users.
  ///
  /// In de, this message translates to:
  /// **'Benutzer'**
  String get users;

  /// No description provided for @invites.
  ///
  /// In de, this message translates to:
  /// **'Einladungen'**
  String get invites;

  /// No description provided for @log.
  ///
  /// In de, this message translates to:
  /// **'Protokoll'**
  String get log;

  /// No description provided for @adminCannotSee.
  ///
  /// In de, this message translates to:
  /// **'Als Administrator siehst du keine Codes anderer Benutzer und kannst keine Passwörter zurücksetzen – das verhindert die Verschlüsselung.'**
  String get adminCannotSee;

  /// No description provided for @since.
  ///
  /// In de, this message translates to:
  /// **'seit {date}'**
  String since(Object date);

  /// No description provided for @deleteUserQuestion.
  ///
  /// In de, this message translates to:
  /// **'{user} löschen?'**
  String deleteUserQuestion(Object user);

  /// No description provided for @deleteUserMessage.
  ///
  /// In de, this message translates to:
  /// **'Das Konto, alle seine Codes und die Tresore, die ihm gehören, werden endgültig gelöscht.'**
  String get deleteUserMessage;

  /// No description provided for @revokeAdmin.
  ///
  /// In de, this message translates to:
  /// **'Administrator entziehen'**
  String get revokeAdmin;

  /// No description provided for @makeAdmin.
  ///
  /// In de, this message translates to:
  /// **'Zum Administrator machen'**
  String get makeAdmin;

  /// No description provided for @unblock.
  ///
  /// In de, this message translates to:
  /// **'Entsperren'**
  String get unblock;

  /// No description provided for @block.
  ///
  /// In de, this message translates to:
  /// **'Sperren'**
  String get block;

  /// No description provided for @createInvite.
  ///
  /// In de, this message translates to:
  /// **'Einladung erstellen'**
  String get createInvite;

  /// No description provided for @createInviteHint.
  ///
  /// In de, this message translates to:
  /// **'Einmal verwendbar, 7 Tage gültig'**
  String get createInviteHint;

  /// No description provided for @inviteFor.
  ///
  /// In de, this message translates to:
  /// **'Für wen? (optional)'**
  String get inviteFor;

  /// No description provided for @create.
  ///
  /// In de, this message translates to:
  /// **'Erstellen'**
  String get create;

  /// No description provided for @invite.
  ///
  /// In de, this message translates to:
  /// **'Einladung'**
  String get invite;

  /// No description provided for @inviteInstructions.
  ///
  /// In de, this message translates to:
  /// **'In der Sixora-App bei „Einladungs-QR-Code scannen“ scannen oder den Link schicken: Server-Adresse und Code sind dann schon eingetragen. Gültig bis {date}, nur einmal verwendbar. Code und Link werden nur jetzt angezeigt.'**
  String inviteInstructions(Object date);

  /// No description provided for @copyLink.
  ///
  /// In de, this message translates to:
  /// **'Link kopieren'**
  String get copyLink;

  /// No description provided for @done.
  ///
  /// In de, this message translates to:
  /// **'Fertig'**
  String get done;

  /// No description provided for @noOpenInvites.
  ///
  /// In de, this message translates to:
  /// **'Keine offenen Einladungen'**
  String get noOpenInvites;

  /// No description provided for @inviteDates.
  ///
  /// In de, this message translates to:
  /// **'Erstellt {created} · gültig bis {expires}'**
  String inviteDates(Object created, Object expires);

  /// No description provided for @withdraw.
  ///
  /// In de, this message translates to:
  /// **'Zurückziehen'**
  String get withdraw;

  /// No description provided for @chooseExportFilesOrImages.
  ///
  /// In de, this message translates to:
  /// **'Export-Dateien oder Bilder auswählen'**
  String get chooseExportFilesOrImages;

  /// No description provided for @nothingNew.
  ///
  /// In de, this message translates to:
  /// **'Nichts Neues gefunden'**
  String get nothingNew;

  /// No description provided for @backupPassword.
  ///
  /// In de, this message translates to:
  /// **'Passwort der Sicherung'**
  String get backupPassword;

  /// No description provided for @decrypt.
  ///
  /// In de, this message translates to:
  /// **'Entschlüsseln'**
  String get decrypt;

  /// No description provided for @accountsImported.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Konto importiert} other{{count} Konten importiert}}'**
  String accountsImported(int count);

  /// No description provided for @supported.
  ///
  /// In de, this message translates to:
  /// **'Unterstützt werden:'**
  String get supported;

  /// No description provided for @supportedFormats.
  ///
  /// In de, this message translates to:
  /// **'• Google Authenticator: „Konten übertragen“ → QR-Codes scannen oder Screenshots wählen (alle auf einmal, bei mehreren Codes)\n• Aegis: Export als unverschlüsseltes JSON\n• 2FAS: Sicherung ohne Passwort (.2fas)\n• Bitwarden: Export als JSON (unverschlüsselt) oder CSV\n• andOTP: unverschlüsselter JSON-Export\n• FreeOTP+: JSON-Export\n• 2FAuth: Export als JSON\n• Sixora: verschlüsselte Sicherung\n• Alles mit otpauth://-Links, z. B. Ente Auth (Export als Text) oder Textdateien'**
  String get supportedFormats;

  /// No description provided for @microsoftNoExport.
  ///
  /// In de, this message translates to:
  /// **'Microsoft Authenticator und Authy bieten keinen Export. Dort jedes Konto beim Dienst neu einrichten oder den QR-Code erneut anzeigen lassen.'**
  String get microsoftNoExport;

  /// No description provided for @chooseFilesOrImages.
  ///
  /// In de, this message translates to:
  /// **'Dateien oder Bilder auswählen'**
  String get chooseFilesOrImages;

  /// No description provided for @missingTransferCodes.
  ///
  /// In de, this message translates to:
  /// **'Es fehlen noch Code {codes}.'**
  String missingTransferCodes(Object codes);

  /// No description provided for @missingTransferCodesHint.
  ///
  /// In de, this message translates to:
  /// **'Google Authenticator verteilt die Konten auf mehrere QR-Codes. Die fehlenden bitte ebenfalls hinzufügen.'**
  String get missingTransferCodesHint;

  /// No description provided for @addMoreFiles.
  ///
  /// In de, this message translates to:
  /// **'Weitere Bilder oder Dateien hinzufügen'**
  String get addMoreFiles;

  /// No description provided for @alreadyPresent.
  ///
  /// In de, this message translates to:
  /// **'schon vorhanden'**
  String get alreadyPresent;

  /// No description provided for @groupForUngrouped.
  ///
  /// In de, this message translates to:
  /// **'Gruppe für Konten ohne Gruppe'**
  String get groupForUngrouped;

  /// No description provided for @progressOf.
  ///
  /// In de, this message translates to:
  /// **'{done} von {total}'**
  String progressOf(Object done, Object total);

  /// No description provided for @importAccounts.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Konto importieren} other{{count} Konten importieren}}'**
  String importAccounts(int count);

  /// No description provided for @tryAgain.
  ///
  /// In de, this message translates to:
  /// **'Erneut versuchen'**
  String get tryAgain;

  /// No description provided for @signedInDevicesHint.
  ///
  /// In de, this message translates to:
  /// **'Ein abgemeldetes Gerät verliert sofort den Zugriff auf den Server und löscht beim nächsten Kontakt seine lokale Kopie.'**
  String get signedInDevicesHint;

  /// No description provided for @thisDevice.
  ///
  /// In de, this message translates to:
  /// **'{device} (dieses Gerät)'**
  String thisDevice(Object device);

  /// No description provided for @sessionDates.
  ///
  /// In de, this message translates to:
  /// **'Angemeldet {created} · zuletzt aktiv {lastSeen}'**
  String sessionDates(Object created, Object lastSeen);

  /// No description provided for @signOutDeviceNamed.
  ///
  /// In de, this message translates to:
  /// **'„{device}“ abmelden?'**
  String signOutDeviceNamed(Object device);

  /// No description provided for @signOutDeviceHint.
  ///
  /// In de, this message translates to:
  /// **'Das Gerät muss sich danach neu anmelden.'**
  String get signOutDeviceHint;

  /// No description provided for @eventRegister.
  ///
  /// In de, this message translates to:
  /// **'Konto erstellt'**
  String get eventRegister;

  /// No description provided for @eventLogin.
  ///
  /// In de, this message translates to:
  /// **'Anmeldung'**
  String get eventLogin;

  /// No description provided for @eventLoginFailed.
  ///
  /// In de, this message translates to:
  /// **'Fehlgeschlagene Anmeldung'**
  String get eventLoginFailed;

  /// No description provided for @eventReauthFailed.
  ///
  /// In de, this message translates to:
  /// **'Falsches Passwort bei Kontoänderung'**
  String get eventReauthFailed;

  /// No description provided for @eventLogout.
  ///
  /// In de, this message translates to:
  /// **'Abmeldung'**
  String get eventLogout;

  /// No description provided for @eventPasswordChanged.
  ///
  /// In de, this message translates to:
  /// **'Master-Passwort geändert'**
  String get eventPasswordChanged;

  /// No description provided for @eventRecoveryUsed.
  ///
  /// In de, this message translates to:
  /// **'Wiederherstellungsschlüssel benutzt'**
  String get eventRecoveryUsed;

  /// No description provided for @eventRecoveryFailed.
  ///
  /// In de, this message translates to:
  /// **'Falscher Wiederherstellungsschlüssel'**
  String get eventRecoveryFailed;

  /// No description provided for @eventRecoveryKeyChanged.
  ///
  /// In de, this message translates to:
  /// **'Neuer Wiederherstellungsschlüssel'**
  String get eventRecoveryKeyChanged;

  /// No description provided for @eventSessionRevoked.
  ///
  /// In de, this message translates to:
  /// **'Gerät abgemeldet'**
  String get eventSessionRevoked;

  /// No description provided for @eventAccountDeleted.
  ///
  /// In de, this message translates to:
  /// **'Konto gelöscht'**
  String get eventAccountDeleted;

  /// No description provided for @eventVaultShared.
  ///
  /// In de, this message translates to:
  /// **'Tresor geteilt'**
  String get eventVaultShared;

  /// No description provided for @eventVaultUnshared.
  ///
  /// In de, this message translates to:
  /// **'Mitglied entfernt'**
  String get eventVaultUnshared;

  /// No description provided for @eventVaultLeft.
  ///
  /// In de, this message translates to:
  /// **'Tresor verlassen'**
  String get eventVaultLeft;

  /// No description provided for @eventVaultDeleted.
  ///
  /// In de, this message translates to:
  /// **'Tresor gelöscht'**
  String get eventVaultDeleted;

  /// No description provided for @eventInviteCreated.
  ///
  /// In de, this message translates to:
  /// **'Einladung erstellt'**
  String get eventInviteCreated;

  /// No description provided for @eventInviteDeleted.
  ///
  /// In de, this message translates to:
  /// **'Einladung gelöscht'**
  String get eventInviteDeleted;

  /// No description provided for @eventUserUpdated.
  ///
  /// In de, this message translates to:
  /// **'Benutzer geändert'**
  String get eventUserUpdated;

  /// No description provided for @eventUserDeleted.
  ///
  /// In de, this message translates to:
  /// **'Benutzer gelöscht'**
  String get eventUserDeleted;

  /// No description provided for @noEntries.
  ///
  /// In de, this message translates to:
  /// **'Keine Einträge'**
  String get noEntries;

  /// No description provided for @accountsFound.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Konto aus {source} gefunden} other{{count} Konten aus {source} gefunden}}'**
  String accountsFound(int count, Object source);

  /// No description provided for @notReadable.
  ///
  /// In de, this message translates to:
  /// **', {count} nicht lesbar'**
  String notReadable(int count);

  /// No description provided for @existingDeselected.
  ///
  /// In de, this message translates to:
  /// **'Bereits vorhandene sind abgewählt.'**
  String get existingDeselected;

  /// No description provided for @blocked.
  ///
  /// In de, this message translates to:
  /// **'gesperrt'**
  String get blocked;

  /// No description provided for @eventVaultKeyRotated.
  ///
  /// In de, this message translates to:
  /// **'Tresorschlüssel erneuert'**
  String get eventVaultKeyRotated;

  /// No description provided for @writingFirstBackup.
  ///
  /// In de, this message translates to:
  /// **'Erste Sicherung wird geschrieben …'**
  String get writingFirstBackup;

  /// No description provided for @autoBackupExplanation.
  ///
  /// In de, this message translates to:
  /// **'Sixora schreibt nach Änderungen eine verschlüsselte Sicherung aller Konten in einen Ordner deiner Wahl, zum Beispiel in die iCloud, in Nextcloud oder auf einen USB-Stick. So bleibt eine Kopie, auch wenn Server oder Konto verloren gehen.\n\nPro Tag entsteht eine Datei, die letzten 14 bleiben. Geschrieben wird nur, solange Sixora entsperrt ist. Öffnen lässt sich eine Sicherung mit ihrem Passwort über „Importieren“, auch in einem neuen Konto.'**
  String get autoBackupExplanation;

  /// No description provided for @chooseFolderAndSetUp.
  ///
  /// In de, this message translates to:
  /// **'Ordner wählen und einrichten'**
  String get chooseFolderAndSetUp;

  /// No description provided for @folder.
  ///
  /// In de, this message translates to:
  /// **'Ordner'**
  String get folder;

  /// No description provided for @lastBackup.
  ///
  /// In de, this message translates to:
  /// **'Letzte Sicherung'**
  String get lastBackup;

  /// No description provided for @lastBackupFailed.
  ///
  /// In de, this message translates to:
  /// **'Letzte Sicherung fehlgeschlagen'**
  String get lastBackupFailed;

  /// No description provided for @backupErrorDetail.
  ///
  /// In de, this message translates to:
  /// **'{error}\nZuletzt erfolgreich: {date}'**
  String backupErrorDetail(Object error, Object date);

  /// No description provided for @backUpNow.
  ///
  /// In de, this message translates to:
  /// **'Jetzt sichern'**
  String get backUpNow;

  /// No description provided for @backupWritten.
  ///
  /// In de, this message translates to:
  /// **'Sicherung geschrieben'**
  String get backupWritten;

  /// No description provided for @verifyBackup.
  ///
  /// In de, this message translates to:
  /// **'Sicherung prüfen'**
  String get verifyBackup;

  /// No description provided for @verifyBackupHint.
  ///
  /// In de, this message translates to:
  /// **'Öffnet die neueste Datei wie beim Zurückspielen'**
  String get verifyBackupHint;

  /// No description provided for @backupOk.
  ///
  /// In de, this message translates to:
  /// **'Sicherung in Ordnung'**
  String get backupOk;

  /// No description provided for @backupNotCurrent.
  ///
  /// In de, this message translates to:
  /// **'Sicherung lesbar, aber nicht aktuell'**
  String get backupNotCurrent;

  /// No description provided for @otherFolderOrPassword.
  ///
  /// In de, this message translates to:
  /// **'Anderen Ordner oder neues Passwort'**
  String get otherFolderOrPassword;

  /// No description provided for @turnOff.
  ///
  /// In de, this message translates to:
  /// **'Ausschalten'**
  String get turnOff;

  /// No description provided for @turnOffHint.
  ///
  /// In de, this message translates to:
  /// **'Vorhandene Dateien bleiben im Ordner'**
  String get turnOffHint;

  /// No description provided for @saveRecoveryKey.
  ///
  /// In de, this message translates to:
  /// **'Wiederherstellungsschlüssel speichern'**
  String get saveRecoveryKey;

  /// No description provided for @newRecoveryKeyShown.
  ///
  /// In de, this message translates to:
  /// **'Dein neuer Wiederherstellungsschlüssel. Der alte gilt nicht mehr.'**
  String get newRecoveryKeyShown;

  /// No description provided for @writeDownKey.
  ///
  /// In de, this message translates to:
  /// **'Schreib dir diesen Schlüssel jetzt auf.'**
  String get writeDownKey;

  /// No description provided for @recoveryKeyExplanation.
  ///
  /// In de, this message translates to:
  /// **'Vergisst du dein Master-Passwort, ist er der einzige Weg zurück an deine Codes. Er wird nur dieses eine Mal angezeigt.'**
  String get recoveryKeyExplanation;

  /// No description provided for @copy.
  ///
  /// In de, this message translates to:
  /// **'Kopieren'**
  String get copy;

  /// No description provided for @copiedRemoveAfterPaste.
  ///
  /// In de, this message translates to:
  /// **'Kopiert – bitte nach dem Einfügen aus der Zwischenablage entfernen'**
  String get copiedRemoveAfterPaste;

  /// No description provided for @saveAsFile.
  ///
  /// In de, this message translates to:
  /// **'Als Datei speichern'**
  String get saveAsFile;

  /// No description provided for @keyStoredSafely.
  ///
  /// In de, this message translates to:
  /// **'Ich habe den Schlüssel sicher aufbewahrt.'**
  String get keyStoredSafely;

  /// No description provided for @trashEmpty.
  ///
  /// In de, this message translates to:
  /// **'Der Papierkorb ist leer'**
  String get trashEmpty;

  /// No description provided for @trashExplanation.
  ///
  /// In de, this message translates to:
  /// **'Gelöschte Konten bleiben 30 Tage verschlüsselt auf dem Server und lassen sich bis dahin wiederherstellen.'**
  String get trashExplanation;

  /// No description provided for @deletedOn.
  ///
  /// In de, this message translates to:
  /// **'gelöscht {date}'**
  String deletedOn(Object date);

  /// No description provided for @restore.
  ///
  /// In de, this message translates to:
  /// **'Wiederherstellen'**
  String get restore;

  /// No description provided for @restored.
  ///
  /// In de, this message translates to:
  /// **'„{name}“ wiederhergestellt'**
  String restored(Object name);

  /// No description provided for @deleteForGood.
  ///
  /// In de, this message translates to:
  /// **'Endgültig löschen'**
  String get deleteForGood;

  /// No description provided for @deleteForGoodQuestion.
  ///
  /// In de, this message translates to:
  /// **'Endgültig löschen?'**
  String get deleteForGoodQuestion;

  /// No description provided for @deleteForGoodMessage.
  ///
  /// In de, this message translates to:
  /// **'„{name}“ lässt sich danach nicht mehr wiederherstellen.'**
  String deleteForGoodMessage(Object name);

  /// No description provided for @transferAccounts.
  ///
  /// In de, this message translates to:
  /// **'Konten übertragen'**
  String get transferAccounts;

  /// No description provided for @noneTransferable.
  ///
  /// In de, this message translates to:
  /// **'Keines der Konten lässt sich so übertragen.'**
  String get noneTransferable;

  /// No description provided for @previousCode.
  ///
  /// In de, this message translates to:
  /// **'Vorheriger Code'**
  String get previousCode;

  /// No description provided for @codeOfTotal.
  ///
  /// In de, this message translates to:
  /// **'Code {page} von {total}'**
  String codeOfTotal(Object page, Object total);

  /// No description provided for @scanInOtherApp.
  ///
  /// In de, this message translates to:
  /// **'In der anderen App „QR-Code scannen“ wählen.'**
  String get scanInOtherApp;

  /// No description provided for @scanInGoogleAuthenticator.
  ///
  /// In de, this message translates to:
  /// **'In Google Authenticator „Konten importieren“ wählen und die Codes nacheinander scannen. Andere Apps wie Aegis lesen dieses Format ebenfalls.'**
  String get scanInGoogleAuthenticator;

  /// No description provided for @skippedTransfer.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Konto (Steam oder ungewöhnliches Intervall) ist nicht enthalten – bitte einzeln übertragen.} other{{count} Konten (Steam oder ungewöhnliche Intervalle) sind nicht enthalten – bitte einzeln übertragen.}}'**
  String skippedTransfer(int count);

  /// No description provided for @switchCamera.
  ///
  /// In de, this message translates to:
  /// **'Kamera wechseln'**
  String get switchCamera;

  /// No description provided for @noCameraAccess.
  ///
  /// In de, this message translates to:
  /// **'Kein Zugriff auf die Kamera. Bitte in den Systemeinstellungen erlauben.'**
  String get noCameraAccess;

  /// No description provided for @cameraUnavailable.
  ///
  /// In de, this message translates to:
  /// **'Kamera nicht verfügbar: {reason}'**
  String cameraUnavailable(Object reason);

  /// No description provided for @codesCaptured.
  ///
  /// In de, this message translates to:
  /// **'{count} von {total} Codes erfasst'**
  String codesCaptured(Object count, Object total);

  /// No description provided for @nextInGoogleAuthenticator.
  ///
  /// In de, this message translates to:
  /// **'In Google Authenticator zum nächsten Code blättern.'**
  String get nextInGoogleAuthenticator;

  /// No description provided for @continueWithCaptured.
  ///
  /// In de, this message translates to:
  /// **'Mit den erfassten weiter'**
  String get continueWithCaptured;

  /// No description provided for @scanHint.
  ///
  /// In de, this message translates to:
  /// **'Halte die Kamera auf den QR-Code, den der Dienst bei der Einrichtung der Zwei-Faktor-Anmeldung anzeigt.'**
  String get scanHint;

  /// No description provided for @shortcutCtrlAltO.
  ///
  /// In de, this message translates to:
  /// **'Strg+Alt+O'**
  String get shortcutCtrlAltO;

  /// No description provided for @openSixora.
  ///
  /// In de, this message translates to:
  /// **'Sixora öffnen'**
  String get openSixora;

  /// No description provided for @searchWithShortcut.
  ///
  /// In de, this message translates to:
  /// **'Suchen … ({shortcut})'**
  String searchWithShortcut(Object shortcut);

  /// No description provided for @favoritesHint.
  ///
  /// In de, this message translates to:
  /// **'Favoriten: Stern bei einem Konto setzen'**
  String get favoritesHint;

  /// No description provided for @unlockEllipsis.
  ///
  /// In de, this message translates to:
  /// **'Entsperren …'**
  String get unlockEllipsis;

  /// No description provided for @quitSixora.
  ///
  /// In de, this message translates to:
  /// **'Sixora beenden'**
  String get quitSixora;

  /// No description provided for @imageNotOpenable.
  ///
  /// In de, this message translates to:
  /// **'Das Bild lässt sich nicht öffnen. Bitte als PNG oder JPEG speichern (z. B. einen Screenshot statt eines HEIC-Fotos).'**
  String get imageNotOpenable;

  /// No description provided for @codeListOfSize.
  ///
  /// In de, this message translates to:
  /// **'{list} von {size}'**
  String codeListOfSize(Object list, Object size);

  /// No description provided for @autoBackupFolder.
  ///
  /// In de, this message translates to:
  /// **'Ordner für die automatische Sicherung'**
  String get autoBackupFolder;

  /// No description provided for @listAnd.
  ///
  /// In de, this message translates to:
  /// **'{first} und {last}'**
  String listAnd(Object first, Object last);

  /// No description provided for @backupVerified.
  ///
  /// In de, this message translates to:
  /// **'{file} lässt sich mit dem Passwort öffnen und enthält {accounts} Konten. Im Ordner liegen {files} Sicherungen.'**
  String backupVerified(Object file, int accounts, int files);

  /// No description provided for @backupMissing.
  ///
  /// In de, this message translates to:
  /// **'Noch nicht enthalten: {names}. „Jetzt sichern“ nimmt sie auf.'**
  String backupMissing(Object names);

  /// No description provided for @recoveryKeyFile.
  ///
  /// In de, this message translates to:
  /// **'Sixora – Wiederherstellungsschlüssel\n\nBenutzer: {user}\nErstellt: {date}\n\n{key}\n\nDamit lässt sich ein neues Master-Passwort setzen. Sicher aufbewahren (z. B. ausgedruckt oder im Passwort-Manager) und niemandem zeigen.\n'**
  String recoveryKeyFile(Object user, Object date, Object key);

  /// No description provided for @checkDuplicate.
  ///
  /// In de, this message translates to:
  /// **'Doppelt gespeichert'**
  String get checkDuplicate;

  /// No description provided for @checkDuplicateHint.
  ///
  /// In de, this message translates to:
  /// **'Gleicher Schlüssel, gleiche Codes. Eine Kopie genügt; die andere kann in den Papierkorb.'**
  String get checkDuplicateHint;

  /// No description provided for @checkWeak.
  ///
  /// In de, this message translates to:
  /// **'Kurzer Schlüssel'**
  String get checkWeak;

  /// No description provided for @checkWeakHint.
  ///
  /// In de, this message translates to:
  /// **'Unter 80 Bit. Einen neuen Schlüssel kann nur der Dienst ausstellen: die Zwei-Faktor-Anmeldung dort neu einrichten.'**
  String get checkWeakHint;

  /// No description provided for @checkInvalid.
  ///
  /// In de, this message translates to:
  /// **'Ungültiger Schlüssel'**
  String get checkInvalid;

  /// No description provided for @checkInvalidHint.
  ///
  /// In de, this message translates to:
  /// **'Daraus lässt sich kein Code berechnen. Bitte den Schlüssel prüfen.'**
  String get checkInvalidHint;

  /// No description provided for @checkUnnamed.
  ///
  /// In de, this message translates to:
  /// **'Ohne Namen'**
  String get checkUnnamed;

  /// No description provided for @checkUnnamedHint.
  ///
  /// In de, this message translates to:
  /// **'Weder Dienst noch Konto: schwer zu erkennen.'**
  String get checkUnnamedHint;

  /// No description provided for @withoutLogo.
  ///
  /// In de, this message translates to:
  /// **'Ohne Logo'**
  String get withoutLogo;

  /// No description provided for @withoutLogoHint.
  ///
  /// In de, this message translates to:
  /// **'Kein passendes Logo gefunden. Im Editor lässt sich eines auswählen oder der Buchstabe festlegen.'**
  String get withoutLogoHint;

  /// No description provided for @allGood.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{Alles in Ordnung: 1 Konto geprüft} other{Alles in Ordnung: {count} Konten geprüft}}'**
  String allGood(int count);

  /// No description provided for @errOffline.
  ///
  /// In de, this message translates to:
  /// **'Server nicht erreichbar'**
  String get errOffline;

  /// No description provided for @errDns.
  ///
  /// In de, this message translates to:
  /// **'Adresse „{host}“ nicht gefunden (DNS). Stimmt die Adresse? Nach einer Änderung kann es bis zu einer Stunde dauern.'**
  String errDns(Object host);

  /// No description provided for @errTls.
  ///
  /// In de, this message translates to:
  /// **'Sichere Verbindung fehlgeschlagen (Zertifikat prüfen)'**
  String get errTls;

  /// No description provided for @errBadRequest.
  ///
  /// In de, this message translates to:
  /// **'Ungültige Anfrage'**
  String get errBadRequest;

  /// No description provided for @errConflict.
  ///
  /// In de, this message translates to:
  /// **'Die Daten wurden inzwischen geändert. Bitte erneut versuchen.'**
  String get errConflict;

  /// No description provided for @errDisabled.
  ///
  /// In de, this message translates to:
  /// **'Konto ist gesperrt'**
  String get errDisabled;

  /// No description provided for @errForbidden.
  ///
  /// In de, this message translates to:
  /// **'Das darf nur der Eigentümer bzw. ein Administrator'**
  String get errForbidden;

  /// No description provided for @errInvalidCredentials.
  ///
  /// In de, this message translates to:
  /// **'Benutzername oder Passwort ist falsch'**
  String get errInvalidCredentials;

  /// No description provided for @errInvalidInvite.
  ///
  /// In de, this message translates to:
  /// **'Einladungscode ist ungültig oder abgelaufen'**
  String get errInvalidInvite;

  /// No description provided for @errInvalidUsername.
  ///
  /// In de, this message translates to:
  /// **'Benutzername: 3–64 Zeichen, Buchstaben, Ziffern und . _ @ + -'**
  String get errInvalidUsername;

  /// No description provided for @errLastAdmin.
  ///
  /// In de, this message translates to:
  /// **'Der letzte Administrator kann nicht entfernt werden. Bitte zuerst einen anderen Benutzer zum Administrator machen.'**
  String get errLastAdmin;

  /// No description provided for @errLimit.
  ///
  /// In de, this message translates to:
  /// **'Zu viele Einträge'**
  String get errLimit;

  /// No description provided for @errNotFound.
  ///
  /// In de, this message translates to:
  /// **'Nicht gefunden'**
  String get errNotFound;

  /// No description provided for @errOwnerCannotLeave.
  ///
  /// In de, this message translates to:
  /// **'Der Eigentümer kann den Tresor nicht verlassen, nur löschen'**
  String get errOwnerCannotLeave;

  /// No description provided for @errPersonalVault.
  ///
  /// In de, this message translates to:
  /// **'Der persönliche Tresor kann weder geteilt noch gelöscht werden'**
  String get errPersonalVault;

  /// No description provided for @errRateLimited.
  ///
  /// In de, this message translates to:
  /// **'Zu viele Versuche. Bitte später erneut versuchen.'**
  String get errRateLimited;

  /// No description provided for @errRegistrationClosed.
  ///
  /// In de, this message translates to:
  /// **'Registrierung ist geschlossen'**
  String get errRegistrationClosed;

  /// No description provided for @errSelf.
  ///
  /// In de, this message translates to:
  /// **'Das geht nicht mit dem eigenen Konto'**
  String get errSelf;

  /// No description provided for @errTooLarge.
  ///
  /// In de, this message translates to:
  /// **'Anfrage ist zu groß'**
  String get errTooLarge;

  /// No description provided for @errUnauthorized.
  ///
  /// In de, this message translates to:
  /// **'Sitzung ist abgelaufen'**
  String get errUnauthorized;

  /// No description provided for @errUsernameTaken.
  ///
  /// In de, this message translates to:
  /// **'Benutzername ist vergeben'**
  String get errUsernameTaken;

  /// No description provided for @errUnexpectedResponse.
  ///
  /// In de, this message translates to:
  /// **'Unerwartete Antwort (Fehler {status}) – ist das ein Sixora-Server?'**
  String errUnexpectedResponse(int status);

  /// No description provided for @errServiceOrAccount.
  ///
  /// In de, this message translates to:
  /// **'Dienst oder Konto angeben'**
  String get errServiceOrAccount;

  /// No description provided for @errBackupOtherPassword.
  ///
  /// In de, this message translates to:
  /// **'Diese Sicherung wurde mit einem anderen Passwort erstellt'**
  String get errBackupOtherPassword;

  /// No description provided for @errDecryptionFailed.
  ///
  /// In de, this message translates to:
  /// **'Entschlüsselung fehlgeschlagen'**
  String get errDecryptionFailed;

  /// No description provided for @errExportDamaged.
  ///
  /// In de, this message translates to:
  /// **'Export-Daten sind beschädigt'**
  String get errExportDamaged;

  /// No description provided for @errPeriodRange.
  ///
  /// In de, this message translates to:
  /// **'Intervall muss zwischen 5 und 600 s liegen'**
  String get errPeriodRange;

  /// No description provided for @errNotGoogleExport.
  ///
  /// In de, this message translates to:
  /// **'Kein Google-Authenticator-Export'**
  String get errNotGoogleExport;

  /// No description provided for @errNotOtpauth.
  ///
  /// In de, this message translates to:
  /// **'Kein otpauth-Link'**
  String get errNotOtpauth;

  /// No description provided for @errNoAccountsInFile.
  ///
  /// In de, this message translates to:
  /// **'Keine Konten in der Datei gefunden'**
  String get errNoAccountsInFile;

  /// No description provided for @errEmptyKey.
  ///
  /// In de, this message translates to:
  /// **'Leerer Schlüssel'**
  String get errEmptyKey;

  /// No description provided for @errBackupPasswordWrong.
  ///
  /// In de, this message translates to:
  /// **'Passwort der Sicherung ist falsch'**
  String get errBackupPasswordWrong;

  /// No description provided for @errKeyMissing.
  ///
  /// In de, this message translates to:
  /// **'Schlüssel fehlt'**
  String get errKeyMissing;

  /// No description provided for @errKeyTooShort.
  ///
  /// In de, this message translates to:
  /// **'Schlüssel ist zu kurz'**
  String get errKeyTooShort;

  /// No description provided for @errDigitsRange.
  ///
  /// In de, this message translates to:
  /// **'Stellen müssen zwischen 4 und 10 liegen'**
  String get errDigitsRange;

  /// No description provided for @errTypeUnsupported.
  ///
  /// In de, this message translates to:
  /// **'Typ nicht unterstützt'**
  String get errTypeUnsupported;

  /// No description provided for @errUnknownFormat.
  ///
  /// In de, this message translates to:
  /// **'Unbekanntes Format'**
  String get errUnknownFormat;

  /// No description provided for @errUnknownBackupFormat.
  ///
  /// In de, this message translates to:
  /// **'Unbekanntes Sicherungsformat'**
  String get errUnknownBackupFormat;

  /// No description provided for @errInvalidKeyCharacter.
  ///
  /// In de, this message translates to:
  /// **'Ungültiges Zeichen im Schlüssel'**
  String get errInvalidKeyCharacter;

  /// No description provided for @errInvalidKeyParameters.
  ///
  /// In de, this message translates to:
  /// **'Unzulässige Schlüsselparameter'**
  String get errInvalidKeyParameters;

  /// No description provided for @errRecoveryKeyInvalid.
  ///
  /// In de, this message translates to:
  /// **'Wiederherstellungsschlüssel ist ungültig'**
  String get errRecoveryKeyInvalid;

  /// No description provided for @errCounterNegative.
  ///
  /// In de, this message translates to:
  /// **'Zähler ist negativ'**
  String get errCounterNegative;

  /// No description provided for @errAegisEncrypted.
  ///
  /// In de, this message translates to:
  /// **'Verschlüsselte Aegis-Sicherung: bitte in Aegis unverschlüsselt exportieren'**
  String get errAegisEncrypted;

  /// No description provided for @choose.
  ///
  /// In de, this message translates to:
  /// **'Auswählen'**
  String get choose;

  /// No description provided for @err2fasEncrypted.
  ///
  /// In de, this message translates to:
  /// **'Verschlüsselte 2FAS-Sicherung: bitte in 2FAS ohne Passwort exportieren'**
  String get err2fasEncrypted;

  /// No description provided for @errBitwardenEncrypted.
  ///
  /// In de, this message translates to:
  /// **'Verschlüsselter Bitwarden-Export: bitte als „.json“ ohne Verschlüsselung exportieren'**
  String get errBitwardenEncrypted;

  /// No description provided for @errEnteEncrypted.
  ///
  /// In de, this message translates to:
  /// **'Verschlüsselte Ente-Auth-Sicherung: bitte unverschlüsselt (als Textdatei) exportieren'**
  String get errEnteEncrypted;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
