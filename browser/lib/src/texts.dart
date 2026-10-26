import 'package:sixora_core/sixora_core.dart';

import 'extension.dart';

/// The extension's texts in German, English and Spanish, after the
/// browser's language (English for others).
class Texts {
  const Texts._(this.code, this._t);

  factory Texts.of(String language) {
    final code = language.toLowerCase().split(RegExp('[-_]')).first;
    return switch (code) {
      'de' => const Texts._('de', _de),
      'es' => const Texts._('es', _es),
      _ => const Texts._('en', _en),
    };
  }

  final String code;
  final Map<String, String> _t;

  String operator [](String key) => _t[key] ?? _en[key] ?? key;

  String fill(String key, Map<String, Object> values) {
    var text = this[key];
    values.forEach((k, v) => text = text.replaceAll('{$k}', '$v'));
    return text;
  }

  /// A message for any error the extension may meet.
  String error(Object e) => switch (e) {
    ExtensionError(:final code) => this[code],
    // The core's German message names the address.
    ApiException(code: 'dns', :final message) when code == 'de' => message,
    ApiException(:final code) when _t.containsKey('err_$code') =>
      this['err_$code'],
    ApiException(:final status) when status >= 500 => this['err_server'],
    ApiException(:final message) => message,
    CryptoException(:final message) when message.contains('Master-Passwort') =>
      this['wrongPassword'],
    _ => fill('err_unexpected', {'error': e}),
  };
}

const _de = {
  'tagline': 'Deine Einmal-Codes, Ende-zu-Ende-verschlüsselt.',
  'setupTitle': 'Mit Sixora verbinden',
  'setupIntro':
      'Melde dich mit deinem Sixora-Konto an. Die Erweiterung zeigt deine '
      'Codes und fügt sie in Anmeldeseiten ein; Konten legst du in der App an.',
  'setupStart': 'Sixora einrichten',
  'setupNeeded':
      'Einmal mit deinem Sixora-Konto anmelden, dann sind die '
      'Codes hier.',
  'serverAddress': 'Server-Adresse',
  'username': 'Benutzername',
  'masterPassword': 'Master-Passwort',
  'signIn': 'Anmelden',
  'permissionHint':
      'Der Browser fragt gleich, ob Sixora mit diesem Server sprechen darf. '
      'Das Master-Passwort verlässt dieses Gerät nie.',
  'permissionDenied':
      'Ohne Zugriff auf den Server kann Sixora sich nicht anmelden.',
  'setupDone':
      'Fertig. Öffne Sixora über das Symbol in der Symbolleiste '
      '(Alt+Shift+O). Diesen Tab kannst du schließen.',
  'signedOutRemotely':
      'Diese Anmeldung wurde beendet (abgemeldet oder Master-Passwort '
      'geändert). Bitte erneut anmelden.',
  'locked': 'Gesperrt',
  'unlock': 'Entsperren',
  'search': 'Suchen',
  'matching': 'Passend für {site}',
  'allAccounts': 'Alle Konten',
  'noAccounts': 'Noch keine Konten. Lege sie in der Sixora-App an.',
  'noMatches': 'Keine Treffer',
  'copy': 'Kopieren',
  'copied': 'Kopiert',
  'insert': 'In die Seite einfügen',
  'inserted': 'Eingefügt',
  'noField': 'Kein Code-Feld gefunden – der Code ist kopiert.',
  'siteChanged':
      'Die Seite hat gewechselt. Öffne Sixora noch einmal auf der Seite, '
      'die nach dem Code fragt.',
  'mismatchTitle': 'Passt nicht zu dieser Seite',
  'mismatchBody':
      '„{account}“ gehört nicht erkennbar zu {site}. Gefälschte '
      'Anmeldeseiten sehen oft aus wie das Original. Setze den Code nur '
      'ein, wenn du sicher bist, dass du richtig bist.',
  'mismatchInsert': 'Trotzdem einsetzen',
  'cancel': 'Abbrechen',
  'unlockWith': 'Mit {method} entsperren',
  'unlockWithApp': 'Mit der Sixora-App entsperren',
  'orPassword': 'oder mit dem Master-Passwort',
  'confirmInApp': 'In Sixora bestätigen',
  'confirmWithMethod': 'Bestätige in Sixora mit {method}.',
  'confirmWithDialog': 'Bestätige in der Sixora-App.',
  'connectWithApp': 'Mit der Sixora-App verbinden',
  'pairInApp': 'In Sixora verbinden',
  'pairHint':
      'Sixora fragt, ob sich diese Erweiterung künftig über die App '
      'entsperren darf. Verbinde nur, wenn dort derselbe Code steht.',
  'app_not_running':
      'Die Sixora-App läuft nicht. Starte sie oder entsperre mit dem '
      'Master-Passwort.',
  'app_denied': 'In Sixora abgelehnt.',
  'app_locked':
      'Sixora ist gesperrt. Entsperre die App oder schalte dort Touch ID '
      'bzw. Windows Hello ein.',
  'app_other_account': 'Die Sixora-App ist mit einem anderen Konto angemeldet.',
  'app_busy': 'Sixora bearbeitet gerade eine andere Anfrage.',
  'app_timeout': 'Keine Antwort von Sixora.',
  'app_cancelled': 'Abgebrochen.',
  'app_failed': 'Das Entsperren über die Sixora-App hat nicht geklappt.',
  'lock': 'Sperren',
  'settings': 'Einstellungen',
  'back': 'Zurück',
  'signOut': 'Abmelden',
  'signOutHint':
      'Beendet die Anmeldung dieses Browsers und löscht seine Kopie. Die '
      'Codes bleiben auf dem Server.',
  'autoLock': 'Automatisch sperren',
  'afterMinutes': 'Nach {n} Min.',
  'onBrowserClose': 'Wenn der Browser schließt',
  'account': 'Konto',
  'server': 'Server',
  'lastSync': 'Stand: {time}',
  'offline': 'Keine Verbindung – zeigt den letzten Stand.',
  'unreadable': '{n} Konten ließen sich nicht entschlüsseln.',
  'secondsLeft': 'noch {n} s',
  'version': 'Version {v}',
  'readOnlyHint': 'Konten anlegen und ändern geht in der Sixora-App.',
  'enterServerAddress': 'Bitte die Server-Adresse eingeben',
  'invalidAddress': 'Ungültige Adresse',
  'httpOnlyLocal':
      'Unverschlüsseltes http:// nur im eigenen Netz – bitte https:// verwenden',
  'enterUsernameAndPassword': 'Bitte Benutzername und Master-Passwort eingeben',
  'wrongPassword': 'Master-Passwort ist falsch',
  'passwordChanged': 'Das Master-Passwort wurde geändert. Bitte neu anmelden.',
  'err_offline': 'Server nicht erreichbar',
  'err_dns': 'Adresse nicht gefunden (DNS)',
  'err_tls': 'Sichere Verbindung fehlgeschlagen (Zertifikat prüfen)',
  'err_invalid_credentials': 'Benutzername oder Master-Passwort ist falsch',
  'err_rate_limited': 'Zu viele Versuche – bitte später erneut versuchen',
  'err_disabled': 'Dieses Konto ist gesperrt',
  'err_unauthorized': 'Nicht angemeldet',
  'err_server': 'Fehler auf dem Server',
  'err_unexpected': 'Unerwarteter Fehler: {error}',
};

const _en = {
  'tagline': 'Your one-time codes, end-to-end encrypted.',
  'setupTitle': 'Connect to Sixora',
  'setupIntro':
      'Sign in with your Sixora account. The extension shows your codes and '
      'inserts them into sign-in pages; accounts are added in the app.',
  'setupStart': 'Set up Sixora',
  'setupNeeded':
      'Sign in once with your Sixora account to see your codes '
      'here.',
  'serverAddress': 'Server address',
  'username': 'User name',
  'masterPassword': 'Master password',
  'signIn': 'Sign in',
  'permissionHint':
      'The browser will ask whether Sixora may talk to this server. The '
      'master password never leaves this device.',
  'permissionDenied': 'Without access to the server Sixora cannot sign in.',
  'setupDone':
      'Done. Open Sixora with its icon in the toolbar (Alt+Shift+O). You can '
      'close this tab.',
  'signedOutRemotely':
      'This sign-in has ended (signed out or master password changed). '
      'Please sign in again.',
  'locked': 'Locked',
  'unlock': 'Unlock',
  'search': 'Search',
  'matching': 'Matching {site}',
  'allAccounts': 'All accounts',
  'noAccounts': 'No accounts yet. Add them in the Sixora app.',
  'noMatches': 'No matches',
  'copy': 'Copy',
  'copied': 'Copied',
  'insert': 'Insert into the page',
  'inserted': 'Inserted',
  'noField': 'No code field found – the code has been copied.',
  'siteChanged':
      'The page has changed. Open Sixora again on the page that asks for '
      'the code.',
  'mismatchTitle': 'Does not match this site',
  'mismatchBody':
      '“{account}” does not appear to belong to {site}. Fake sign-in pages '
      'often look like the real one. Only insert the code if you are sure '
      'you are in the right place.',
  'mismatchInsert': 'Insert anyway',
  'cancel': 'Cancel',
  'unlockWith': 'Unlock with {method}',
  'unlockWithApp': 'Unlock with the Sixora app',
  'orPassword': 'or with the master password',
  'confirmInApp': 'Confirm in Sixora',
  'confirmWithMethod': 'Confirm with {method} in Sixora.',
  'confirmWithDialog': 'Confirm in the Sixora app.',
  'connectWithApp': 'Connect to the Sixora app',
  'pairInApp': 'Connect in Sixora',
  'pairHint':
      'Sixora asks whether this extension may unlock through the app from '
      'now on. Only connect if it shows the same code.',
  'app_not_running':
      'The Sixora app is not running. Start it or unlock with the master '
      'password.',
  'app_denied': 'Declined in Sixora.',
  'app_locked':
      'Sixora is locked. Unlock the app or turn on Touch ID or Windows Hello '
      'there.',
  'app_other_account': 'The Sixora app is signed in to a different account.',
  'app_busy': 'Sixora is handling another request.',
  'app_timeout': 'No answer from Sixora.',
  'app_cancelled': 'Cancelled.',
  'app_failed': 'Unlocking through the Sixora app did not work.',
  'lock': 'Lock',
  'settings': 'Settings',
  'back': 'Back',
  'signOut': 'Sign out',
  'signOutHint':
      'Ends this browser\'s sign-in and deletes its copy. Your codes stay '
      'on the server.',
  'autoLock': 'Lock automatically',
  'afterMinutes': 'After {n} min',
  'onBrowserClose': 'When the browser closes',
  'account': 'Account',
  'server': 'Server',
  'lastSync': 'As of {time}',
  'offline': 'No connection – showing the last state.',
  'unreadable': '{n} accounts could not be decrypted.',
  'secondsLeft': '{n} s left',
  'version': 'Version {v}',
  'readOnlyHint': 'Accounts are added and changed in the Sixora app.',
  'enterServerAddress': 'Please enter the server address',
  'invalidAddress': 'Invalid address',
  'httpOnlyLocal':
      'Unencrypted http:// only on your own network – please use https://',
  'enterUsernameAndPassword': 'Please enter user name and master password',
  'wrongPassword': 'Master password is wrong',
  'passwordChanged':
      'The master password has been changed. Please sign in again.',
  'err_offline': 'Server not reachable',
  'err_dns': 'Address not found (DNS)',
  'err_tls': 'Secure connection failed (check the certificate)',
  'err_invalid_credentials': 'User name or master password is wrong',
  'err_rate_limited': 'Too many attempts – please try again later',
  'err_disabled': 'This account is disabled',
  'err_unauthorized': 'Not signed in',
  'err_server': 'Error on the server',
  'err_unexpected': 'Unexpected error: {error}',
};

const _es = {
  'tagline': 'Tus códigos de un solo uso, cifrados de extremo a extremo.',
  'setupTitle': 'Conectar con Sixora',
  'setupIntro':
      'Inicia sesión con tu cuenta de Sixora. La extensión muestra tus '
      'códigos y los inserta en las páginas de inicio de sesión; las cuentas '
      'se añaden en la app.',
  'setupStart': 'Configurar Sixora',
  'setupNeeded':
      'Inicia sesión una vez con tu cuenta de Sixora para ver '
      'aquí tus códigos.',
  'serverAddress': 'Dirección del servidor',
  'username': 'Nombre de usuario',
  'masterPassword': 'Contraseña maestra',
  'signIn': 'Iniciar sesión',
  'permissionHint':
      'El navegador preguntará si Sixora puede comunicarse con este '
      'servidor. La contraseña maestra nunca sale de este dispositivo.',
  'permissionDenied': 'Sin acceso al servidor Sixora no puede iniciar sesión.',
  'setupDone':
      'Listo. Abre Sixora con su icono en la barra de herramientas '
      '(Alt+Shift+O). Puedes cerrar esta pestaña.',
  'signedOutRemotely':
      'Esta sesión ha terminado (cerrada o contraseña maestra cambiada). '
      'Inicia sesión de nuevo.',
  'locked': 'Bloqueado',
  'unlock': 'Desbloquear',
  'search': 'Buscar',
  'matching': 'Para {site}',
  'allAccounts': 'Todas las cuentas',
  'noAccounts': 'Aún no hay cuentas. Añádelas en la app de Sixora.',
  'noMatches': 'Sin resultados',
  'copy': 'Copiar',
  'copied': 'Copiado',
  'insert': 'Insertar en la página',
  'inserted': 'Insertado',
  'noField': 'No se encontró ningún campo de código: el código se ha copiado.',
  'siteChanged':
      'La página ha cambiado. Abre Sixora de nuevo en la página que pide '
      'el código.',
  'mismatchTitle': 'No coincide con este sitio',
  'mismatchBody':
      '«{account}» no parece pertenecer a {site}. Las páginas de inicio de '
      'sesión falsas suelen parecerse a la original. Inserta el código '
      'solo si estás seguro de estar en el lugar correcto.',
  'mismatchInsert': 'Insertar de todos modos',
  'cancel': 'Cancelar',
  'unlockWith': 'Desbloquear con {method}',
  'unlockWithApp': 'Desbloquear con la app de Sixora',
  'orPassword': 'o con la contraseña maestra',
  'confirmInApp': 'Confirmar en Sixora',
  'confirmWithMethod': 'Confirma con {method} en Sixora.',
  'confirmWithDialog': 'Confirma en la app de Sixora.',
  'connectWithApp': 'Conectar con la app de Sixora',
  'pairInApp': 'Conectar en Sixora',
  'pairHint':
      'Sixora pregunta si esta extensión podrá desbloquearse a través de la '
      'app a partir de ahora. Conecta solo si muestra el mismo código.',
  'app_not_running':
      'La app de Sixora no está abierta. Ábrela o desbloquea con la '
      'contraseña maestra.',
  'app_denied': 'Rechazado en Sixora.',
  'app_locked':
      'Sixora está bloqueada. Desbloquea la app o activa allí Touch ID o '
      'Windows Hello.',
  'app_other_account': 'La app de Sixora usa otra cuenta.',
  'app_busy': 'Sixora está atendiendo otra solicitud.',
  'app_timeout': 'Sixora no responde.',
  'app_cancelled': 'Cancelado.',
  'app_failed': 'No se pudo desbloquear con la app de Sixora.',
  'lock': 'Bloquear',
  'settings': 'Ajustes',
  'back': 'Atrás',
  'signOut': 'Cerrar sesión',
  'signOutHint':
      'Cierra la sesión de este navegador y borra su copia. Tus códigos '
      'siguen en el servidor.',
  'autoLock': 'Bloquear automáticamente',
  'afterMinutes': 'Tras {n} min',
  'onBrowserClose': 'Al cerrar el navegador',
  'account': 'Cuenta',
  'server': 'Servidor',
  'lastSync': 'Estado: {time}',
  'offline': 'Sin conexión: se muestra el último estado.',
  'unreadable': 'No se pudieron descifrar {n} cuentas.',
  'secondsLeft': 'quedan {n} s',
  'version': 'Versión {v}',
  'readOnlyHint': 'Las cuentas se añaden y cambian en la app de Sixora.',
  'enterServerAddress': 'Introduce la dirección del servidor',
  'invalidAddress': 'Dirección no válida',
  'httpOnlyLocal': 'http:// sin cifrar solo en tu propia red: usa https://',
  'enterUsernameAndPassword':
      'Introduce el nombre de usuario y la contraseña maestra',
  'wrongPassword': 'La contraseña maestra es incorrecta',
  'passwordChanged':
      'La contraseña maestra ha cambiado. Inicia sesión de nuevo.',
  'err_offline': 'No se puede conectar con el servidor',
  'err_dns': 'Dirección no encontrada (DNS)',
  'err_tls': 'Falló la conexión segura (revisa el certificado)',
  'err_invalid_credentials':
      'El nombre de usuario o la contraseña maestra son incorrectos',
  'err_rate_limited': 'Demasiados intentos: inténtalo más tarde',
  'err_disabled': 'Esta cuenta está bloqueada',
  'err_unauthorized': 'Sin sesión iniciada',
  'err_server': 'Error en el servidor',
  'err_unexpected': 'Error inesperado: {error}',
};
