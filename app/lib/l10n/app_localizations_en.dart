// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Sixora';

  @override
  String get signedOut => 'Signed out';

  @override
  String get cancel => 'Cancel';

  @override
  String get backupPasswordTitle => 'Password for the backup';

  @override
  String get backupPasswordHint =>
      'At least 10 characters. Without this password the backup cannot be opened.';

  @override
  String get password => 'Password';

  @override
  String get continueAction => 'Continue';

  @override
  String get passwordTooShort => 'The password needs at least 10 characters';

  @override
  String get repeatPassword => 'Repeat password';

  @override
  String get passwordsDoNotMatch => 'The passwords do not match';

  @override
  String get paste => 'Paste';

  @override
  String get selectAll => 'Select all';

  @override
  String get clipboardEmpty => 'The clipboard is empty';

  @override
  String get hide => 'Hide';

  @override
  String get show => 'Show';

  @override
  String get strengthWeak => 'Weak';

  @override
  String get strengthFair => 'Fair';

  @override
  String get strengthGood => 'Good';

  @override
  String get strengthVeryGood => 'Very good';

  @override
  String get enterSixoraMasterPassword =>
      'Please enter the Sixora master password.';

  @override
  String get signOutQuestion => 'Sign out?';

  @override
  String get signOutLocalCopyMessage =>
      'The local copy will be removed from this device. Your codes stay on the server and on your other devices.';

  @override
  String get signOut => 'Sign out';

  @override
  String get locked => 'Locked';

  @override
  String get unlock => 'Unlock';

  @override
  String unlockWith(Object method) {
    return 'Unlock with $method';
  }

  @override
  String get notAnInviteCode => 'This is not a Sixora invite code';

  @override
  String get usernameTooShort => 'User name: at least 3 characters';

  @override
  String get masterPasswordTooShort =>
      'The master password needs at least 10 characters';

  @override
  String get enterUsernameAndPassword => 'Enter user name and master password';

  @override
  String get tagline =>
      'Your one-time codes, end-to-end encrypted on your own server.';

  @override
  String get serverAddressOrInvite => 'Server address or invite link';

  @override
  String get connect => 'Connect';

  @override
  String get scanInviteQr => 'Scan invite QR code';

  @override
  String get change => 'Change';

  @override
  String get signIn => 'Sign in';

  @override
  String get register => 'Register';

  @override
  String get forgotten => 'Forgotten';

  @override
  String get newServerFirstAdmin =>
      'This server is new. The first account becomes the administrator.';

  @override
  String get username => 'User name';

  @override
  String get recoveryKey => 'Recovery key';

  @override
  String get newMasterPassword => 'New master password';

  @override
  String get masterPassword => 'Master password';

  @override
  String strengthLabel(Object strength) {
    return 'Strength: $strength';
  }

  @override
  String get repeatMasterPassword => 'Repeat master password';

  @override
  String get inviteCode => 'Invite code';

  @override
  String get masterPasswordNeverLeaves =>
      'The master password never leaves this device and nobody can reset it – not even the administrator. Only the recovery key gets you back in without the password.';

  @override
  String get createAccount => 'Create account';

  @override
  String get setNewPassword => 'Set new password';

  @override
  String get generatingKeys => 'Generating keys …';

  @override
  String get keyInvalidShort => 'Invalid key';

  @override
  String get codeHidden => 'Code hidden';

  @override
  String spokenCode(Object digits) {
    return 'Code $digits';
  }

  @override
  String secondsLeft(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds left',
      one: '1 second left',
    );
    return '$_temp0';
  }

  @override
  String get showCode => 'Show code';

  @override
  String get copyCode => 'Copy code';

  @override
  String get moreActions => 'More actions';

  @override
  String nextCodeLabel(Object code) {
    return 'Next: $code';
  }

  @override
  String get keyIsInvalid => 'The key is invalid';

  @override
  String get nextCode => 'Next code';

  @override
  String get more => 'More';

  @override
  String get code => 'Code';

  @override
  String copied(Object what) {
    return '$what copied';
  }

  @override
  String copiedClearsSoon(Object what) {
    return '$what copied – removed from the clipboard after 30 s';
  }

  @override
  String serverVersion(Object version) {
    return 'Version $version';
  }

  @override
  String get noHttpsWarning => 'Without HTTPS – use only on your own network!';

  @override
  String get settings => 'Settings';

  @override
  String get sectionSecurity => 'Security';

  @override
  String get autoLock => 'Lock automatically';

  @override
  String get quickUnlockHardwareHint =>
      'Instead of the master password. The key is bound to this device\'s biometrics; if a new finger or face is enrolled, the password is needed again.';

  @override
  String get quickUnlockKeychainHint =>
      'Instead of the master password. The key is kept in this device\'s keychain for this.';

  @override
  String get hideCodes => 'Hide codes';

  @override
  String get hideCodesHint => 'Show only after a tap';

  @override
  String get clearClipboard => 'Clear clipboard';

  @override
  String get clearClipboardHint => 'Remove copied codes after 30 seconds';

  @override
  String get allowScreenshots => 'Allow screenshots';

  @override
  String get allowScreenshotsHint =>
      'Otherwise screenshots and screen recordings are blocked';

  @override
  String get changeMasterPassword => 'Change master password';

  @override
  String get newRecoveryKey => 'New recovery key';

  @override
  String get newRecoveryKeyHint => 'The previous one stops working';

  @override
  String get signedInDevices => 'Signed-in devices';

  @override
  String get trash => 'Recycle bin';

  @override
  String get trashHint => 'Accounts deleted in the last 30 days';

  @override
  String get activity => 'Activity';

  @override
  String get activityHint => 'Sign-ins and changes to the account';

  @override
  String get sectionDesktop => 'Desktop';

  @override
  String get keepInMenuBar => 'Keep running in the menu bar';

  @override
  String get keepInTray => 'Keep running in the notification area';

  @override
  String get keepInTrayHint =>
      'Sixora stays at hand when the window is closed. The icon copies the codes of favourites or searches all accounts.';

  @override
  String shortcutTitle(Object shortcut) {
    return 'Keyboard shortcut $shortcut';
  }

  @override
  String get shortcutHint =>
      'Brings Sixora to the front from anywhere, with the cursor in the search.';

  @override
  String get sectionDisplay => 'Display';

  @override
  String get showNextCode => 'Show next code';

  @override
  String get showNextCodeHint => 'In the last 5 seconds of a code';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get sectionVaultsData => 'Vaults and data';

  @override
  String get vaultsAndSharing => 'Vaults and sharing';

  @override
  String get importAction => 'Import';

  @override
  String get exportAction => 'Export';

  @override
  String get exportHint => 'Encrypted backup, text file or QR codes';

  @override
  String get autoBackup => 'Automatic backup';

  @override
  String get off => 'Off';

  @override
  String errorWith(Object error) {
    return 'Error: $error';
  }

  @override
  String backupFolderLast(Object folder, Object time) {
    return '$folder · last $time';
  }

  @override
  String get accountCheck => 'Account check';

  @override
  String get accountCheckHint => 'Duplicate accounts, weak keys, missing logos';

  @override
  String get sectionServer => 'Server';

  @override
  String get administration => 'Administration';

  @override
  String get administrationHint => 'Users, invites, log';

  @override
  String get sectionAccount => 'Account';

  @override
  String get signOutHint => 'Removes the local copy from this device';

  @override
  String get signOutMessage =>
      'Your codes stay on the server. To sign in again you need your user name and master password.';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get sectionAbout => 'About';

  @override
  String get currentPassword => 'Current password';

  @override
  String get newPassword => 'New password';

  @override
  String get newPasswordHint =>
      'At least 10 characters. Other devices are signed out.';

  @override
  String get repeatNewPassword => 'Repeat new password';

  @override
  String get newPasswordTooShort =>
      'The new password needs at least 10 characters';

  @override
  String get newPasswordsDoNotMatch => 'The new passwords do not match';

  @override
  String get changingPassword => 'Changing password …';

  @override
  String get masterPasswordChanged =>
      'Master password changed. Other devices have to sign in again.';

  @override
  String get newRecoveryKeyConfirm =>
      'Enter the master password to confirm. The previous key stops working.';

  @override
  String get generate => 'Generate';

  @override
  String get deleteAccountQuestion => 'Delete the account for good?';

  @override
  String get deleteAccountMessage =>
      'All your codes and the vaults you own – shared ones too – are deleted on the server. This cannot be undone. First turn off two-factor sign-in with the services or export your accounts.';

  @override
  String get confirmMasterPassword => 'Confirm master password';

  @override
  String get nothingToExport => 'No accounts to export';

  @override
  String get encryptedBackup => 'Encrypted backup';

  @override
  String get encryptedBackupHint =>
      'With its own password, can be imported into Sixora';

  @override
  String get googleAuthenticatorQr => 'QR codes for Google Authenticator';

  @override
  String get googleAuthenticatorQrHint => 'To move them to another app';

  @override
  String get plainTextFile => 'Unencrypted text file';

  @override
  String get plainTextFileHint =>
      'otpauth links, for other apps – only with care';

  @override
  String get encryptingBackup => 'Encrypting backup …';

  @override
  String get exportUnencryptedQuestion => 'Export unencrypted?';

  @override
  String get exportUnencryptedMessage =>
      'The file contains every secret key in plain text. Anyone who reads it can generate your codes. Delete it right after the import.';

  @override
  String get saveAs => 'Save as';

  @override
  String get saved => 'Saved';

  @override
  String get openOtpauthLinks => 'Open otpauth links with Sixora';

  @override
  String get otpauthLinksOpenSixora =>
      'Links for setting up accounts open Sixora.';

  @override
  String notChanged(Object reason) {
    return 'Not changed: $reason';
  }

  @override
  String get useSixora => 'Use Sixora';

  @override
  String get administrator => 'Administrator';

  @override
  String lastSynced(Object time) {
    return 'Last synced: $time';
  }

  @override
  String get aboutText =>
      'Codes are computed on your devices. The server stores encrypted data only.';

  @override
  String get linksOpenOtherApp => 'Another app opens them at the moment.';

  @override
  String linksOpenApp(Object app) {
    return 'At the moment “$app” opens them.';
  }

  @override
  String vaultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vaults',
      one: '1 vault',
    );
    return '$_temp0';
  }

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String offerBiometricsTitle(Object method) {
    return 'Unlock with $method?';
  }

  @override
  String offerBiometricsMessage(Object method) {
    return 'Then $method is enough to unlock instead of the master password. You still need the password for account changes and on new devices.';
  }

  @override
  String get notNow => 'Not now';

  @override
  String get setUp => 'Set up';

  @override
  String biometricsEnabled(Object method) {
    return 'Sixora can now be unlocked with $method';
  }

  @override
  String get setUpLaterInSettings => 'Can be set up later in the settings';

  @override
  String codeFor(Object name) {
    return 'Code for $name';
  }

  @override
  String get scanQrCode => 'Scan QR code';

  @override
  String get withCamera => 'With the camera';

  @override
  String get qrFromImage => 'QR code from image';

  @override
  String get qrFromImageHint => 'Choose a screenshot or photo';

  @override
  String get linkFromClipboard => 'Link from clipboard';

  @override
  String get linkFromClipboardHint => 'Paste otpauth://…';

  @override
  String get enterManually => 'Enter manually';

  @override
  String get enterManuallyHint => 'Type in the key';

  @override
  String get importHint => 'Google Authenticator, Aegis, 2FAuth, Sixora …';

  @override
  String get chooseQrImages => 'Choose images with QR codes';

  @override
  String get searchingQr => 'Looking for a QR code …';

  @override
  String searchingQrInImages(int count) {
    return 'Looking for QR codes in $count images …';
  }

  @override
  String get noQrInImage => 'No QR code found in the image';

  @override
  String get noQrInImages => 'No QR code found in the images';

  @override
  String linkIncomplete(Object reason) {
    return 'Link is incomplete: $reason';
  }

  @override
  String get notA2faLink => 'This is not a 2FA code (otpauth://…)';

  @override
  String get noWritableVault => 'No vault with write access';

  @override
  String get alreadyThere => 'Already there';

  @override
  String get alreadyThereMessage =>
      'This account is already saved. Add it again anyway?';

  @override
  String get addAnyway => 'Add';

  @override
  String get edit => 'Edit';

  @override
  String get removeFavorite => 'No longer a favourite';

  @override
  String get makeFavorite => 'Mark as favourite';

  @override
  String get moveToVault => 'Move to another vault';

  @override
  String get transferQr => 'Transfer (QR code)';

  @override
  String get delete => 'Delete';

  @override
  String get showSecretQuestion => 'Show the secret key?';

  @override
  String get showSecretMessage =>
      'The QR code contains the secret key. Anyone who sees or photographs it can generate your codes.';

  @override
  String deleteEntryQuestion(Object name) {
    return 'Delete “$name”?';
  }

  @override
  String entryDeleted(Object name) {
    return '“$name” deleted';
  }

  @override
  String get undo => 'Undo';

  @override
  String get moveTo => 'Move to';

  @override
  String get synchronize => 'Synchronize';

  @override
  String get lock => 'Lock';

  @override
  String get add => 'Add';

  @override
  String get all => 'All';

  @override
  String get favorites => 'Favourites';

  @override
  String syncErrorBanner(Object error) {
    return '$error\nThe codes still work; changes need a connection.';
  }

  @override
  String undecryptableEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries cannot be decrypted.',
      one: '1 entry cannot be decrypted.',
    );
    return '$_temp0';
  }

  @override
  String get noMatches => 'No matches';

  @override
  String get noAccountsYet => 'No accounts yet';

  @override
  String get noAccountsHint =>
      'Turn on two-factor sign-in with a service and scan the QR code it shows – or import your accounts from another app.';

  @override
  String get addAccount => 'Add account';

  @override
  String get search => 'Search';

  @override
  String get clear => 'Clear';

  @override
  String get signOutDeviceQuestion => 'Sign out the device?';

  @override
  String signOutDeviceMessage(Object device) {
    return '“$device” loses access right away. If that was not you, change your master password afterwards too: whoever could sign in knows it.';
  }

  @override
  String get deviceSignedOut => 'Device signed out';

  @override
  String newSignIn(Object device, Object platform, Object time) {
    return 'New sign-in: $device$platform, $time';
  }

  @override
  String get thatWasMe => 'That was me';

  @override
  String get deleteEntryMessage =>
      'The entry disappears on all devices. For 30 days it can be restored from the recycle bin (settings).';

  @override
  String get deleteEntrySharedMessage =>
      'The entry disappears on all devices and for everyone the vault is shared with. For 30 days it can be restored from the recycle bin (settings).';

  @override
  String get newVault => 'New vault';

  @override
  String get newVaultMessage =>
      'A vault of your own can be shared with other users of this server, e.g. “Team” or “Family”.';

  @override
  String get name => 'Name';

  @override
  String get vaultsExplanation =>
      'Every vault has a key of its own. When sharing, it is encrypted with the recipient\'s public key – the server never sees the codes.';

  @override
  String get personal => 'Personal';

  @override
  String ownedBy(Object owner) {
    return 'from $owner';
  }

  @override
  String get roleOwner => 'Owner';

  @override
  String get roleWrite => 'Read and write';

  @override
  String get roleRead => 'Read only';

  @override
  String accountCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts',
      one: '1 account',
    );
    return '$_temp0';
  }

  @override
  String memberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get shareWith => 'Share with';

  @override
  String get thatIsYou => 'That is you';

  @override
  String shareWithUser(Object user) {
    return 'Share with $user';
  }

  @override
  String get compareFingerprint =>
      'To be safe, compare the key fingerprint, e.g. on the phone. The other person finds it under “Vaults and sharing”. If it does not match, do not share.';

  @override
  String fingerprintOf(Object user) {
    return 'Fingerprint of $user:';
  }

  @override
  String get roleReadHint => 'See and copy codes';

  @override
  String get roleWriteHint => 'Also add, change and delete accounts';

  @override
  String get share => 'Share';

  @override
  String get vaultGone => 'Vault no longer available';

  @override
  String get rename => 'Rename';

  @override
  String get personalVaultNotShared => 'Your personal vault cannot be shared.';

  @override
  String get personalVaultNotSharedHint =>
      'Create a vault of its own for shared accounts and move them there.';

  @override
  String get yourFingerprint => 'Your key fingerprint';

  @override
  String get members => 'Members';

  @override
  String memberYou(Object user) {
    return '$user (you)';
  }

  @override
  String get remove => 'Remove';

  @override
  String removeMemberQuestion(Object user) {
    return 'Remove $user?';
  }

  @override
  String removeMemberMessage(Object user) {
    return '$user loses access to this vault. Sixora then renews the vault\'s key so the old one opens nothing any more. Keys of accounts $user has already seen stay known, though – set them up again with the service if needed.';
  }

  @override
  String get deleteVault => 'Delete vault';

  @override
  String get deleteVaultHint => 'With all accounts in it, for all members';

  @override
  String deleteVaultQuestion(Object name) {
    return 'Delete “$name”?';
  }

  @override
  String get deleteVaultMessage =>
      'All accounts in this vault are deleted for all members.';

  @override
  String get leaveVault => 'Leave vault';

  @override
  String leaveVaultQuestion(Object name) {
    return 'Leave “$name”?';
  }

  @override
  String get leaveVaultMessage =>
      'You no longer see the accounts in it until you are invited again.';

  @override
  String get leave => 'Leave';

  @override
  String get editAccount => 'Edit account';

  @override
  String get save => 'Save';

  @override
  String get newAccount => 'New account';

  @override
  String get enterKey => 'Enter the key …';

  @override
  String get service => 'Service';

  @override
  String get serviceExample => 'e.g. GitHub';

  @override
  String get accountName => 'Account';

  @override
  String get accountExample => 'e.g. name@example.org';

  @override
  String get secretKey => 'Secret key';

  @override
  String get secretKeyHint => 'Base32, spaces do not matter';

  @override
  String get groupOptional => 'Group (optional)';

  @override
  String get groupExample => 'e.g. Work';

  @override
  String get chooseGroup => 'Choose an existing group';

  @override
  String get vault => 'Vault';

  @override
  String get favorite => 'Favourite';

  @override
  String get favoriteHint => 'Listed at the top';

  @override
  String get icon => 'Icon';

  @override
  String get initialLetter => 'Initial letter';

  @override
  String iconAutomatic(Object name) {
    return '$name (automatic)';
  }

  @override
  String get initialLetterNoLogo => 'Initial letter (no matching logo found)';

  @override
  String get unknown => 'Unknown';

  @override
  String get color => 'Colour';

  @override
  String get colorAuto => 'Auto';

  @override
  String get notesOptional => 'Notes (optional)';

  @override
  String get advanced => 'Advanced';

  @override
  String get timeBased => 'Time-based';

  @override
  String get counter => 'Counter';

  @override
  String get algorithm => 'Algorithm';

  @override
  String get digits => 'Digits';

  @override
  String get periodSeconds => 'Interval (s)';

  @override
  String get chooseIcon => 'Choose icon';

  @override
  String get searchServiceExample => 'Search a service, e.g. Google';

  @override
  String get automatic => 'Automatic';

  @override
  String get letter => 'Letter';

  @override
  String get noLogoFound => 'No logo found';

  @override
  String logosCredit(Object version) {
    return 'Logos: Simple Icons $version. The trademarks belong to their owners.';
  }

  @override
  String digitsCount(int count) {
    return '$count digits';
  }

  @override
  String unexpectedError(Object error) {
    return 'Unexpected error: $error';
  }

  @override
  String get biometrics => 'Biometrics';

  @override
  String get enterServerAddress => 'Please enter the server address';

  @override
  String get invalidAddress => 'Invalid address';

  @override
  String get httpOnlyLocal =>
      'Unencrypted HTTP is only allowed on the local network. Please use https://.';

  @override
  String get recoveryKeyMismatch => 'The recovery key does not match';

  @override
  String get masterPasswordWrong => 'Master password is wrong';

  @override
  String biometricsInvalidatedEnrolled(Object method) {
    return 'Unlocking with $method is no longer valid, e.g. because a finger or face was enrolled again. Please unlock with the master password and set it up again afterwards.';
  }

  @override
  String biometricsInvalidated(Object method) {
    return 'Unlocking with $method is no longer valid. Please unlock with the master password.';
  }

  @override
  String biometricsSetupFailed(Object method, Object reason) {
    return '$method could not be set up: $reason';
  }

  @override
  String get noSession =>
      'No session. Please lock and unlock with the password.';

  @override
  String get accountDisabledNotice => 'Your account has been disabled.';

  @override
  String get deviceSignedOutNotice =>
      'This device has been signed out (password changed or device removed). Please sign in again.';

  @override
  String noServerConnection(Object reason) {
    return 'No connection to the server. $reason.';
  }

  @override
  String backupWrittenMismatch(Object found, Object expected) {
    return 'The written backup contains $found instead of $expected accounts';
  }

  @override
  String backupFailed(Object reason) {
    return 'Backup failed: $reason';
  }

  @override
  String get backupOtherAccount =>
      'The backup was set up for another account. Please set it up again.';

  @override
  String get backupNotSetUp => 'The automatic backup is not set up';

  @override
  String get noBackupInFolder => 'There is no backup in the folder';

  @override
  String backupUnreadable(Object reason) {
    return 'Backup not readable: $reason';
  }

  @override
  String get vaultKeyRenewed =>
      'The vault\'s key has just been renewed. Please try again.';

  @override
  String get entryChangedElsewhere =>
      'The entry was changed on another device meanwhile. The current version is loaded, please try again.';

  @override
  String get vaultReadOnly => 'You may not write to this vault';

  @override
  String get trustedKeysTampered =>
      'The stored keys of your contacts have been altered. Stopped to be safe. Please check the server.';

  @override
  String get aContact => 'a contact';

  @override
  String memberKeyChanged(Object user) {
    return 'The key of “$user” differs from before. A user\'s key never changes, so this one does not come from “$user”. Stopped to be safe. Please check the server.';
  }

  @override
  String get currentMasterPasswordWrong => 'Current master password is wrong';

  @override
  String get accountDeletedNotice => 'Your account has been deleted.';

  @override
  String get unlockSixora => 'Unlock Sixora';

  @override
  String get fingerprint => 'Fingerprint';

  @override
  String setUpUnlockWith(Object method) {
    return 'Set up unlocking with $method';
  }

  @override
  String get autoLockImmediately => 'Immediately on leaving';

  @override
  String autoLockMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'After $minutes minutes',
      one: 'After 1 minute',
    );
    return '$_temp0';
  }

  @override
  String get autoLockOneHour => 'After 1 hour';

  @override
  String get autoLockNever => 'Never';

  @override
  String get users => 'Users';

  @override
  String get invites => 'Invites';

  @override
  String get log => 'Log';

  @override
  String get adminCannotSee =>
      'As administrator you cannot see other users\' codes and cannot reset passwords – the encryption prevents that.';

  @override
  String since(Object date) {
    return 'since $date';
  }

  @override
  String deleteUserQuestion(Object user) {
    return 'Delete $user?';
  }

  @override
  String get deleteUserMessage =>
      'The account, all its codes and the vaults it owns are deleted for good.';

  @override
  String get revokeAdmin => 'Remove administrator rights';

  @override
  String get makeAdmin => 'Make administrator';

  @override
  String get unblock => 'Unblock';

  @override
  String get block => 'Block';

  @override
  String get createInvite => 'Create invite';

  @override
  String get createInviteHint => 'Single use, valid for 7 days';

  @override
  String get inviteFor => 'For whom? (optional)';

  @override
  String get create => 'Create';

  @override
  String get invite => 'Invite';

  @override
  String inviteInstructions(Object date) {
    return 'Scan it in the Sixora app with “Scan invite QR code” or send the link: server address and code are then filled in. Valid until $date, single use. Code and link are shown only now.';
  }

  @override
  String get copyLink => 'Copy link';

  @override
  String get done => 'Done';

  @override
  String get noOpenInvites => 'No open invites';

  @override
  String inviteDates(Object created, Object expires) {
    return 'Created $created · valid until $expires';
  }

  @override
  String get withdraw => 'Withdraw';

  @override
  String get chooseExportFilesOrImages => 'Choose export files or images';

  @override
  String get nothingNew => 'Nothing new found';

  @override
  String get backupPassword => 'Password of the backup';

  @override
  String get decrypt => 'Decrypt';

  @override
  String accountsImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts imported',
      one: '1 account imported',
    );
    return '$_temp0';
  }

  @override
  String get supported => 'Supported:';

  @override
  String get supportedFormats =>
      '• Google Authenticator: “Transfer accounts” → scan the QR codes or choose screenshots (all at once if there are several codes)\n• Aegis: export as unencrypted JSON\n• 2FAS: backup without password (.2fas)\n• Bitwarden: export as JSON (unencrypted) or CSV\n• andOTP: unencrypted JSON export\n• FreeOTP+: JSON export\n• 2FAuth: export as JSON\n• Sixora: encrypted backup\n• Anything with otpauth:// links, e.g. Ente Auth (text export) or text files';

  @override
  String get microsoftNoExport =>
      'Microsoft Authenticator and Authy offer no export. Set up each account again with the service or have the QR code shown again.';

  @override
  String get chooseFilesOrImages => 'Choose files or images';

  @override
  String missingTransferCodes(Object codes) {
    return 'Code $codes is still missing.';
  }

  @override
  String get missingTransferCodesHint =>
      'Google Authenticator spreads the accounts over several QR codes. Please add the missing ones too.';

  @override
  String get addMoreFiles => 'Add more images or files';

  @override
  String get alreadyPresent => 'already there';

  @override
  String get groupForUngrouped => 'Group for accounts without a group';

  @override
  String progressOf(Object done, Object total) {
    return '$done of $total';
  }

  @override
  String importAccounts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Import $count accounts',
      one: 'Import 1 account',
    );
    return '$_temp0';
  }

  @override
  String get tryAgain => 'Try again';

  @override
  String get signedInDevicesHint =>
      'A signed-out device loses access to the server right away and deletes its local copy the next time it connects.';

  @override
  String thisDevice(Object device) {
    return '$device (this device)';
  }

  @override
  String sessionDates(Object created, Object lastSeen) {
    return 'Signed in $created · last active $lastSeen';
  }

  @override
  String signOutDeviceNamed(Object device) {
    return 'Sign out “$device”?';
  }

  @override
  String get signOutDeviceHint => 'The device has to sign in again afterwards.';

  @override
  String get eventRegister => 'Account created';

  @override
  String get eventLogin => 'Sign-in';

  @override
  String get eventLoginFailed => 'Failed sign-in';

  @override
  String get eventReauthFailed => 'Wrong password for an account change';

  @override
  String get eventLogout => 'Sign-out';

  @override
  String get eventPasswordChanged => 'Master password changed';

  @override
  String get eventRecoveryUsed => 'Recovery key used';

  @override
  String get eventRecoveryFailed => 'Wrong recovery key';

  @override
  String get eventRecoveryKeyChanged => 'New recovery key';

  @override
  String get eventSessionRevoked => 'Device signed out';

  @override
  String get eventAccountDeleted => 'Account deleted';

  @override
  String get eventVaultShared => 'Vault shared';

  @override
  String get eventVaultUnshared => 'Member removed';

  @override
  String get eventVaultLeft => 'Vault left';

  @override
  String get eventVaultDeleted => 'Vault deleted';

  @override
  String get eventInviteCreated => 'Invite created';

  @override
  String get eventInviteDeleted => 'Invite deleted';

  @override
  String get eventUserUpdated => 'User changed';

  @override
  String get eventUserDeleted => 'User deleted';

  @override
  String get noEntries => 'No entries';

  @override
  String accountsFound(int count, Object source) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts found in $source',
      one: '1 account found in $source',
    );
    return '$_temp0';
  }

  @override
  String notReadable(int count) {
    return ', $count not readable';
  }

  @override
  String get existingDeselected => 'Existing ones are deselected.';

  @override
  String get blocked => 'blocked';

  @override
  String get eventVaultKeyRotated => 'Vault key renewed';

  @override
  String get writingFirstBackup => 'Writing the first backup …';

  @override
  String get autoBackupExplanation =>
      'After changes, Sixora writes an encrypted backup of all accounts to a folder of your choice, for example iCloud, Nextcloud or a USB stick. That way a copy remains even if the server or the account is lost.\n\nThere is one file per day; the last 14 are kept. Backups are only written while Sixora is unlocked. A backup can be opened with its password via “Import”, also in a new account.';

  @override
  String get chooseFolderAndSetUp => 'Choose a folder and set up';

  @override
  String get folder => 'Folder';

  @override
  String get lastBackup => 'Last backup';

  @override
  String get lastBackupFailed => 'Last backup failed';

  @override
  String backupErrorDetail(Object error, Object date) {
    return '$error\nLast successful: $date';
  }

  @override
  String get backUpNow => 'Back up now';

  @override
  String get backupWritten => 'Backup written';

  @override
  String get verifyBackup => 'Check backup';

  @override
  String get verifyBackupHint => 'Opens the newest file as a restore would';

  @override
  String get backupOk => 'Backup is fine';

  @override
  String get backupNotCurrent => 'Backup readable, but not up to date';

  @override
  String get otherFolderOrPassword => 'Another folder or a new password';

  @override
  String get turnOff => 'Turn off';

  @override
  String get turnOffHint => 'Existing files stay in the folder';

  @override
  String get saveRecoveryKey => 'Save recovery key';

  @override
  String get newRecoveryKeyShown =>
      'Your new recovery key. The old one is no longer valid.';

  @override
  String get writeDownKey => 'Write this key down now.';

  @override
  String get recoveryKeyExplanation =>
      'If you forget your master password, it is the only way back to your codes. It is shown only this once.';

  @override
  String get copy => 'Copy';

  @override
  String get copiedRemoveAfterPaste =>
      'Copied – please remove it from the clipboard after pasting';

  @override
  String get saveAsFile => 'Save as file';

  @override
  String get keyStoredSafely => 'I have stored the key safely.';

  @override
  String get trashEmpty => 'The recycle bin is empty';

  @override
  String get trashExplanation =>
      'Deleted accounts stay on the server, encrypted, for 30 days and can be restored until then.';

  @override
  String deletedOn(Object date) {
    return 'deleted $date';
  }

  @override
  String get restore => 'Restore';

  @override
  String restored(Object name) {
    return '“$name” restored';
  }

  @override
  String get deleteForGood => 'Delete for good';

  @override
  String get deleteForGoodQuestion => 'Delete for good?';

  @override
  String deleteForGoodMessage(Object name) {
    return '“$name” can no longer be restored afterwards.';
  }

  @override
  String get transferAccounts => 'Transfer accounts';

  @override
  String get noneTransferable =>
      'None of the accounts can be transferred this way.';

  @override
  String get previousCode => 'Previous code';

  @override
  String codeOfTotal(Object page, Object total) {
    return 'Code $page of $total';
  }

  @override
  String get scanInOtherApp => 'Choose “Scan QR code” in the other app.';

  @override
  String get scanInGoogleAuthenticator =>
      'In Google Authenticator choose “Import accounts” and scan the codes one after the other. Other apps such as Aegis read this format too.';

  @override
  String skippedTransfer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count accounts (Steam or unusual intervals) are not included – please transfer them one by one.',
      one:
          '1 account (Steam or an unusual interval) is not included – please transfer it on its own.',
    );
    return '$_temp0';
  }

  @override
  String get switchCamera => 'Switch camera';

  @override
  String get noCameraAccess =>
      'No access to the camera. Please allow it in the system settings.';

  @override
  String cameraUnavailable(Object reason) {
    return 'Camera not available: $reason';
  }

  @override
  String codesCaptured(Object count, Object total) {
    return '$count of $total codes captured';
  }

  @override
  String get nextInGoogleAuthenticator =>
      'Go to the next code in Google Authenticator.';

  @override
  String get continueWithCaptured => 'Continue with the captured ones';

  @override
  String get scanHint =>
      'Point the camera at the QR code the service shows when you set up two-factor sign-in.';

  @override
  String get shortcutCtrlAltO => 'Ctrl+Alt+O';

  @override
  String get openSixora => 'Open Sixora';

  @override
  String searchWithShortcut(Object shortcut) {
    return 'Search … ($shortcut)';
  }

  @override
  String get favoritesHint => 'Favourites: star an account';

  @override
  String get unlockEllipsis => 'Unlock …';

  @override
  String get quitSixora => 'Quit Sixora';

  @override
  String get imageNotOpenable =>
      'The image cannot be opened. Please save it as PNG or JPEG (e.g. a screenshot instead of a HEIC photo).';

  @override
  String codeListOfSize(Object list, Object size) {
    return '$list of $size';
  }

  @override
  String get autoBackupFolder => 'Folder for the automatic backup';

  @override
  String listAnd(Object first, Object last) {
    return '$first and $last';
  }

  @override
  String backupVerified(Object file, int accounts, int files) {
    return '$file opens with the password and contains $accounts accounts. The folder holds $files backups.';
  }

  @override
  String backupMissing(Object names) {
    return 'Not included yet: $names. “Back up now” adds them.';
  }

  @override
  String recoveryKeyFile(Object user, Object date, Object key) {
    return 'Sixora – recovery key\n\nUser: $user\nCreated: $date\n\n$key\n\nIt lets you set a new master password. Keep it safe (e.g. printed or in a password manager) and show it to no one.\n';
  }

  @override
  String get checkDuplicate => 'Saved twice';

  @override
  String get checkDuplicateHint =>
      'Same key, same codes. One copy is enough; the other can go to the recycle bin.';

  @override
  String get checkWeak => 'Short key';

  @override
  String get checkWeakHint =>
      'Below 80 bits. Only the service can issue a new key: set up two-factor sign-in there again.';

  @override
  String get checkInvalid => 'Invalid key';

  @override
  String get checkInvalidHint =>
      'No code can be computed from it. Please check the key.';

  @override
  String get checkUnnamed => 'Without a name';

  @override
  String get checkUnnamedHint =>
      'Neither service nor account: hard to recognise.';

  @override
  String get withoutLogo => 'Without a logo';

  @override
  String get withoutLogoHint =>
      'No matching logo found. In the editor you can choose one or set the letter.';

  @override
  String allGood(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'All good: $count accounts checked',
      one: 'All good: 1 account checked',
    );
    return '$_temp0';
  }

  @override
  String get errOffline => 'Server not reachable';

  @override
  String errDns(Object host) {
    return 'Address “$host” not found (DNS). Is the address right? After a change it can take up to an hour.';
  }

  @override
  String get errTls => 'Secure connection failed (check the certificate)';

  @override
  String get errBadRequest => 'Invalid request';

  @override
  String get errConflict => 'The data was changed meanwhile. Please try again.';

  @override
  String get errDisabled => 'The account is blocked';

  @override
  String get errForbidden => 'Only the owner or an administrator may do this';

  @override
  String get errInvalidCredentials => 'User name or password is wrong';

  @override
  String get errInvalidInvite => 'The invite code is invalid or has expired';

  @override
  String get errInvalidUsername =>
      'User name: 3–64 characters, letters, digits and . _ @ + -';

  @override
  String get errLastAdmin =>
      'The last administrator cannot be removed. Please make another user administrator first.';

  @override
  String get errLimit => 'Too many entries';

  @override
  String get errNotFound => 'Not found';

  @override
  String get errOwnerCannotLeave =>
      'The owner cannot leave the vault, only delete it';

  @override
  String get errPersonalVault =>
      'The personal vault can be neither shared nor deleted';

  @override
  String get errRateLimited => 'Too many attempts. Please try again later.';

  @override
  String get errRegistrationClosed => 'Registration is closed';

  @override
  String get errSelf => 'Not possible with your own account';

  @override
  String get errTooLarge => 'The request is too large';

  @override
  String get errUnauthorized => 'The session has expired';

  @override
  String get errUsernameTaken => 'The user name is taken';

  @override
  String errUnexpectedResponse(int status) {
    return 'Unexpected response (error $status) – is this a Sixora server?';
  }

  @override
  String get errServiceOrAccount => 'Enter a service or an account';

  @override
  String get errBackupOtherPassword =>
      'This backup was created with another password';

  @override
  String get errDecryptionFailed => 'Decryption failed';

  @override
  String get errExportDamaged => 'The export data is damaged';

  @override
  String get errPeriodRange => 'The interval must be between 5 and 600 s';

  @override
  String get errNotGoogleExport => 'Not a Google Authenticator export';

  @override
  String get errNotOtpauth => 'Not an otpauth link';

  @override
  String get errNoAccountsInFile => 'No accounts found in the file';

  @override
  String get errEmptyKey => 'Empty key';

  @override
  String get errBackupPasswordWrong => 'The backup password is wrong';

  @override
  String get errKeyMissing => 'The key is missing';

  @override
  String get errKeyTooShort => 'The key is too short';

  @override
  String get errDigitsRange => 'Digits must be between 4 and 10';

  @override
  String get errTypeUnsupported => 'Type not supported';

  @override
  String get errUnknownFormat => 'Unknown format';

  @override
  String get errUnknownBackupFormat => 'Unknown backup format';

  @override
  String get errInvalidKeyCharacter => 'Invalid character in the key';

  @override
  String get errInvalidKeyParameters => 'Invalid key parameters';

  @override
  String get errRecoveryKeyInvalid => 'The recovery key is invalid';

  @override
  String get errCounterNegative => 'The counter is negative';

  @override
  String get errAegisEncrypted =>
      'Encrypted Aegis backup: please export it unencrypted in Aegis';

  @override
  String get choose => 'Choose';

  @override
  String get err2fasEncrypted =>
      'Encrypted 2FAS backup: please export it without a password in 2FAS';

  @override
  String get errBitwardenEncrypted =>
      'Encrypted Bitwarden export: please export as “.json” without encryption';

  @override
  String get errEnteEncrypted =>
      'Encrypted Ente Auth backup: please export it unencrypted (as a text file)';
}
