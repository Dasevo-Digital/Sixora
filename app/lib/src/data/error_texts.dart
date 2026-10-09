import 'package:sixora_core/sixora_core.dart';

import '../l10n.dart';

/// Server and core library speak German. In another language their
/// messages are replaced: server errors by their code, core messages by
/// their text. Unknown ones stay as they are.
String apiErrorText(ApiException e) {
  if (t.localeName == 'de') return e.message;
  return switch (e.code) {
    'offline' => t.errOffline,
    'dns' => t.errDns(
      RegExp('„([^“]+)“').firstMatch(e.message)?.group(1) ?? '',
    ),
    'tls' => t.errTls,
    'bad_request' => t.errBadRequest,
    'conflict' => t.errConflict,
    'disabled' => t.errDisabled,
    'forbidden' => t.errForbidden,
    'invalid_credentials' => t.errInvalidCredentials,
    'invalid_invite' => t.errInvalidInvite,
    'invalid_username' => t.errInvalidUsername,
    'key_changed' => t.vaultKeyRenewed,
    'last_admin' => t.errLastAdmin,
    'limit' => t.errLimit,
    'not_found' => t.errNotFound,
    'owner' => t.errOwnerCannotLeave,
    'personal' => t.errPersonalVault,
    'rate_limited' => t.errRateLimited,
    'read_only' => t.vaultReadOnly,
    'registration_closed' => t.errRegistrationClosed,
    'self' => t.errSelf,
    'too_large' => t.errTooLarge,
    'unauthorized' => t.errUnauthorized,
    'username_taken' => t.errUsernameTaken,
    _ when e.code.startsWith('http_') => t.errUnexpectedResponse(e.status),
    _ => e.message,
  };
}

String coreErrorText(String message) {
  if (t.localeName == 'de') return message;
  final known = {
    'Dienst oder Konto angeben': t.errServiceOrAccount,
    'Diese Sicherung wurde mit einem anderen Passwort erstellt':
        t.errBackupOtherPassword,
    'Entschlüsselung fehlgeschlagen': t.errDecryptionFailed,
    'Export-Daten sind beschädigt': t.errExportDamaged,
    'Intervall muss zwischen 5 und 600 s liegen': t.errPeriodRange,
    'Kein Google-Authenticator-Export': t.errNotGoogleExport,
    'Kein otpauth-Link': t.errNotOtpauth,
    'Keine Konten in der Datei gefunden': t.errNoAccountsInFile,
    'Leerer Schlüssel': t.errEmptyKey,
    'Master-Passwort ist falsch': t.masterPasswordWrong,
    'Passwort der Sicherung ist falsch': t.errBackupPasswordWrong,
    'Schlüssel fehlt': t.errKeyMissing,
    'Schlüssel ist zu kurz': t.errKeyTooShort,
    'Stellen müssen zwischen 4 und 10 liegen': t.errDigitsRange,
    'Typ nicht unterstützt': t.errTypeUnsupported,
    'Unbekanntes Format': t.errUnknownFormat,
    'Unbekanntes Sicherungsformat': t.errUnknownBackupFormat,
    'Ungültiger Schlüssel': t.keyInvalidShort,
    'Ungültiges Zeichen im Schlüssel': t.errInvalidKeyCharacter,
    'Unzulässige Schlüsselparameter': t.errInvalidKeyParameters,
    'Wiederherstellungsschlüssel ist ungültig': t.errRecoveryKeyInvalid,
    'Zähler ist negativ': t.errCounterNegative,
  };
  if (known[message] case final text?) return text;
  if (message.startsWith('Unbekannter Typ')) return t.errTypeUnsupported;
  if (message.startsWith('Verschlüsselte Aegis-Sicherung')) {
    return t.errAegisEncrypted;
  }
  return message;
}
