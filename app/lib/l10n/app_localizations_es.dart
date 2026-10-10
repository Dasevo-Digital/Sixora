// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Sixora';

  @override
  String get signedOut => 'Sesión cerrada';

  @override
  String get cancel => 'Cancelar';

  @override
  String get backupPasswordTitle => 'Contraseña de la copia de seguridad';

  @override
  String get backupPasswordHint =>
      'Al menos 10 caracteres. Sin esta contraseña no se puede abrir la copia de seguridad.';

  @override
  String get password => 'Contraseña';

  @override
  String get continueAction => 'Continuar';

  @override
  String get passwordTooShort =>
      'La contraseña necesita al menos 10 caracteres';

  @override
  String get repeatPassword => 'Repetir contraseña';

  @override
  String get passwordsDoNotMatch => 'Las contraseñas no coinciden';

  @override
  String get paste => 'Pegar';

  @override
  String get selectAll => 'Seleccionar todo';

  @override
  String get clipboardEmpty => 'El portapapeles está vacío';

  @override
  String get hide => 'Ocultar';

  @override
  String get show => 'Mostrar';

  @override
  String get strengthWeak => 'Débil';

  @override
  String get strengthFair => 'Media';

  @override
  String get strengthGood => 'Buena';

  @override
  String get strengthVeryGood => 'Muy buena';

  @override
  String get enterSixoraMasterPassword =>
      'Introduce la contraseña maestra de Sixora.';

  @override
  String get signOutQuestion => '¿Cerrar sesión?';

  @override
  String get signOutLocalCopyMessage =>
      'La copia local se eliminará de este dispositivo. Tus códigos se conservan en el servidor y en tus otros dispositivos.';

  @override
  String get signOut => 'Cerrar sesión';

  @override
  String get locked => 'Bloqueado';

  @override
  String get unlock => 'Desbloquear';

  @override
  String unlockWith(Object method) {
    return 'Desbloquear con $method';
  }

  @override
  String get notAnInviteCode => 'Esto no es un código de invitación de Sixora';

  @override
  String get usernameTooShort => 'Nombre de usuario: al menos 3 caracteres';

  @override
  String get masterPasswordTooShort =>
      'La contraseña maestra necesita al menos 10 caracteres';

  @override
  String get enterUsernameAndPassword =>
      'Introduce el nombre de usuario y la contraseña maestra';

  @override
  String get tagline =>
      'Tus códigos de un solo uso, cifrados de extremo a extremo en tu propio servidor.';

  @override
  String get serverAddressOrInvite =>
      'Dirección del servidor o enlace de invitación';

  @override
  String get connect => 'Conectar';

  @override
  String get scanInviteQr => 'Escanear código QR de invitación';

  @override
  String get change => 'Cambiar';

  @override
  String get signIn => 'Iniciar sesión';

  @override
  String get register => 'Registrarse';

  @override
  String get forgotten => 'Olvidada';

  @override
  String get newServerFirstAdmin =>
      'Este servidor es nuevo. La primera cuenta será la de administrador.';

  @override
  String get username => 'Nombre de usuario';

  @override
  String get recoveryKey => 'Clave de recuperación';

  @override
  String get newMasterPassword => 'Nueva contraseña maestra';

  @override
  String get masterPassword => 'Contraseña maestra';

  @override
  String strengthLabel(Object strength) {
    return 'Seguridad: $strength';
  }

  @override
  String get repeatMasterPassword => 'Repetir contraseña maestra';

  @override
  String get inviteCode => 'Código de invitación';

  @override
  String get masterPasswordNeverLeaves =>
      'La contraseña maestra nunca sale de este dispositivo y nadie puede restablecerla, ni siquiera el administrador. Solo con la clave de recuperación puedes volver a entrar sin la contraseña.';

  @override
  String get createAccount => 'Crear cuenta';

  @override
  String get setNewPassword => 'Establecer nueva contraseña';

  @override
  String get generatingKeys => 'Generando claves…';

  @override
  String get keyInvalidShort => 'Clave no válida';

  @override
  String get codeHidden => 'Código oculto';

  @override
  String spokenCode(Object digits) {
    return 'Código $digits';
  }

  @override
  String secondsLeft(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'quedan $seconds segundos',
      one: 'queda 1 segundo',
    );
    return '$_temp0';
  }

  @override
  String get showCode => 'Mostrar código';

  @override
  String get copyCode => 'Copiar código';

  @override
  String get moreActions => 'Más acciones';

  @override
  String nextCodeLabel(Object code) {
    return 'Siguiente: $code';
  }

  @override
  String get keyIsInvalid => 'La clave no es válida';

  @override
  String get nextCode => 'Siguiente código';

  @override
  String get more => 'Más';

  @override
  String get code => 'Código';

  @override
  String copied(Object what) {
    return '$what copiado';
  }

  @override
  String copiedClearsSoon(Object what) {
    return '$what copiado: se borrará del portapapeles en 30 s';
  }

  @override
  String serverVersion(Object version) {
    return 'Versión $version';
  }

  @override
  String get noHttpsWarning => 'Sin HTTPS: ¡úsalo solo en tu propia red!';

  @override
  String get settings => 'Ajustes';

  @override
  String get sectionSecurity => 'Seguridad';

  @override
  String get autoLock => 'Bloquear automáticamente';

  @override
  String get quickUnlockHardwareHint =>
      'En lugar de la contraseña maestra. La clave está ligada a la biometría de este dispositivo; si se registra un dedo o una cara nuevos, vuelve a hacer falta la contraseña.';

  @override
  String get quickUnlockKeychainHint =>
      'En lugar de la contraseña maestra. Para ello, la clave se guarda en el llavero de este dispositivo.';

  @override
  String get hideCodes => 'Ocultar códigos';

  @override
  String get hideCodesHint => 'Mostrar solo al tocar';

  @override
  String get clearClipboard => 'Vaciar portapapeles';

  @override
  String get clearClipboardHint =>
      'Borrar los códigos copiados tras 30 segundos';

  @override
  String get allowScreenshots => 'Permitir capturas de pantalla';

  @override
  String get allowScreenshotsHint =>
      'Si no, las capturas y grabaciones de pantalla están bloqueadas';

  @override
  String get changeMasterPassword => 'Cambiar contraseña maestra';

  @override
  String get newRecoveryKey => 'Nueva clave de recuperación';

  @override
  String get newRecoveryKeyHint => 'La anterior deja de ser válida';

  @override
  String get signedInDevices => 'Dispositivos con sesión iniciada';

  @override
  String get trash => 'Papelera';

  @override
  String get trashHint => 'Cuentas eliminadas en los últimos 30 días';

  @override
  String get activity => 'Actividad';

  @override
  String get activityHint => 'Inicios de sesión y cambios en la cuenta';

  @override
  String get sectionDesktop => 'Escritorio';

  @override
  String get keepInMenuBar => 'Seguir en la barra de menús';

  @override
  String get keepInTray => 'Seguir en el área de notificación';

  @override
  String get keepInTrayHint =>
      'Sixora sigue disponible al cerrar la ventana. Desde el icono se copian los códigos de los favoritos o se buscan todas las cuentas.';

  @override
  String shortcutTitle(Object shortcut) {
    return 'Atajo de teclado $shortcut';
  }

  @override
  String get shortcutHint =>
      'Trae Sixora al frente desde cualquier lugar, con el cursor en la búsqueda.';

  @override
  String get sectionDisplay => 'Pantalla';

  @override
  String get showNextCode => 'Mostrar el código siguiente';

  @override
  String get showNextCodeHint => 'En los últimos 5 segundos de un código';

  @override
  String get appearance => 'Apariencia';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get sectionVaultsData => 'Bóvedas y datos';

  @override
  String get vaultsAndSharing => 'Bóvedas y compartir';

  @override
  String get importAction => 'Importar';

  @override
  String get exportAction => 'Exportar';

  @override
  String get exportHint => 'Copia cifrada, archivo de texto o códigos QR';

  @override
  String get autoBackup => 'Copia de seguridad automática';

  @override
  String get off => 'Desactivada';

  @override
  String errorWith(Object error) {
    return 'Error: $error';
  }

  @override
  String backupFolderLast(Object folder, Object time) {
    return '$folder · última $time';
  }

  @override
  String get accountCheck => 'Revisión de cuentas';

  @override
  String get accountCheckHint =>
      'Cuentas duplicadas, claves débiles, logotipos que faltan';

  @override
  String get sectionServer => 'Servidor';

  @override
  String get administration => 'Administración';

  @override
  String get administrationHint => 'Usuarios, invitaciones, registro';

  @override
  String get sectionAccount => 'Cuenta';

  @override
  String get signOutHint => 'Elimina la copia local de este dispositivo';

  @override
  String get signOutMessage =>
      'Tus códigos se quedan en el servidor. Para volver a iniciar sesión necesitas el nombre de usuario y la contraseña maestra.';

  @override
  String get deleteAccount => 'Eliminar cuenta';

  @override
  String get sectionAbout => 'Acerca de';

  @override
  String get currentPassword => 'Contraseña actual';

  @override
  String get newPassword => 'Nueva contraseña';

  @override
  String get newPasswordHint =>
      'Al menos 10 caracteres. Se cerrará la sesión en los demás dispositivos.';

  @override
  String get repeatNewPassword => 'Repetir nueva contraseña';

  @override
  String get newPasswordTooShort =>
      'La nueva contraseña necesita al menos 10 caracteres';

  @override
  String get newPasswordsDoNotMatch => 'Las nuevas contraseñas no coinciden';

  @override
  String get changingPassword => 'Cambiando la contraseña…';

  @override
  String get masterPasswordChanged =>
      'Contraseña maestra cambiada. Los demás dispositivos tienen que volver a iniciar sesión.';

  @override
  String get newRecoveryKeyConfirm =>
      'Introduce la contraseña maestra para confirmar. La clave anterior dejará de ser válida.';

  @override
  String get generate => 'Generar';

  @override
  String get deleteAccountQuestion => '¿Eliminar la cuenta definitivamente?';

  @override
  String get deleteAccountMessage =>
      'Todos tus códigos y las bóvedas que te pertenecen, también las compartidas, se eliminarán del servidor. No se puede deshacer. Antes desactiva el inicio de sesión en dos pasos en los servicios o exporta tus cuentas.';

  @override
  String get confirmMasterPassword => 'Confirmar contraseña maestra';

  @override
  String get nothingToExport => 'No hay cuentas para exportar';

  @override
  String get encryptedBackup => 'Copia de seguridad cifrada';

  @override
  String get encryptedBackupHint =>
      'Con contraseña propia; se puede importar en Sixora';

  @override
  String get googleAuthenticatorQr => 'Códigos QR para Google Authenticator';

  @override
  String get googleAuthenticatorQrHint => 'Para pasarlas a otra app';

  @override
  String get plainTextFile => 'Archivo de texto sin cifrar';

  @override
  String get plainTextFileHint =>
      'Enlaces otpauth para otras apps: solo con precaución';

  @override
  String get encryptingBackup => 'Cifrando la copia de seguridad…';

  @override
  String get exportUnencryptedQuestion => '¿Exportar sin cifrar?';

  @override
  String get exportUnencryptedMessage =>
      'El archivo contiene todas las claves secretas en texto plano. Quien lo lea puede generar tus códigos. Bórralo justo después de importarlo.';

  @override
  String get saveAs => 'Guardar como';

  @override
  String get saved => 'Guardado';

  @override
  String get openOtpauthLinks => 'Abrir enlaces otpauth con Sixora';

  @override
  String get otpauthLinksOpenSixora =>
      'Los enlaces para configurar cuentas abren Sixora.';

  @override
  String notChanged(Object reason) {
    return 'Sin cambios: $reason';
  }

  @override
  String get useSixora => 'Usar Sixora';

  @override
  String get administrator => 'Administrador';

  @override
  String lastSynced(Object time) {
    return 'Última sincronización: $time';
  }

  @override
  String get aboutText =>
      'Los códigos se calculan en tus dispositivos. El servidor solo guarda datos cifrados.';

  @override
  String get linksOpenOtherApp => 'Ahora mismo los abre otra app.';

  @override
  String linksOpenApp(Object app) {
    return 'Ahora mismo los abre «$app».';
  }

  @override
  String vaultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bóvedas',
      one: '1 bóveda',
    );
    return '$_temp0';
  }

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Sistema';

  @override
  String offerBiometricsTitle(Object method) {
    return '¿Desbloquear con $method?';
  }

  @override
  String offerBiometricsMessage(Object method) {
    return 'Así bastará con $method para desbloquear en lugar de la contraseña maestra. Seguirás necesitando la contraseña para cambios en la cuenta y en dispositivos nuevos.';
  }

  @override
  String get notNow => 'Ahora no';

  @override
  String get setUp => 'Configurar';

  @override
  String biometricsEnabled(Object method) {
    return 'Ahora Sixora se puede desbloquear con $method';
  }

  @override
  String get setUpLaterInSettings =>
      'Se puede configurar más tarde en los ajustes';

  @override
  String codeFor(Object name) {
    return 'Código de $name';
  }

  @override
  String get scanQrCode => 'Escanear código QR';

  @override
  String get withCamera => 'Con la cámara';

  @override
  String get qrFromImage => 'Código QR de una imagen';

  @override
  String get qrFromImageHint => 'Elegir una captura o foto';

  @override
  String get linkFromClipboard => 'Enlace del portapapeles';

  @override
  String get linkFromClipboardHint => 'Pegar otpauth://…';

  @override
  String get enterManually => 'Introducir manualmente';

  @override
  String get enterManuallyHint => 'Escribir la clave';

  @override
  String get importHint => 'Google Authenticator, Aegis, 2FAuth, Sixora…';

  @override
  String get chooseQrImages => 'Elegir imágenes con códigos QR';

  @override
  String get searchingQr => 'Buscando un código QR…';

  @override
  String searchingQrInImages(int count) {
    return 'Buscando códigos QR en $count imágenes…';
  }

  @override
  String get noQrInImage => 'No se encontró ningún código QR en la imagen';

  @override
  String get noQrInImages => 'No se encontró ningún código QR en las imágenes';

  @override
  String linkIncomplete(Object reason) {
    return 'El enlace está incompleto: $reason';
  }

  @override
  String get notA2faLink => 'Esto no es un código 2FA (otpauth://…)';

  @override
  String get noWritableVault =>
      'No hay ninguna bóveda con permiso de escritura';

  @override
  String get alreadyThere => 'Ya existe';

  @override
  String get alreadyThereMessage =>
      'Esta cuenta ya está guardada. ¿Añadirla de nuevo de todos modos?';

  @override
  String get addAnyway => 'Añadir';

  @override
  String get edit => 'Editar';

  @override
  String get removeFavorite => 'Quitar de favoritos';

  @override
  String get makeFavorite => 'Marcar como favorito';

  @override
  String get moveToVault => 'Mover a otra bóveda';

  @override
  String get transferQr => 'Transferir (código QR)';

  @override
  String get delete => 'Eliminar';

  @override
  String get showSecretQuestion => '¿Mostrar la clave secreta?';

  @override
  String get showSecretMessage =>
      'El código QR contiene la clave secreta. Quien lo vea o lo fotografíe puede generar tus códigos.';

  @override
  String deleteEntryQuestion(Object name) {
    return '¿Eliminar «$name»?';
  }

  @override
  String entryDeleted(Object name) {
    return '«$name» eliminado';
  }

  @override
  String get undo => 'Deshacer';

  @override
  String get moveTo => 'Mover a';

  @override
  String get synchronize => 'Sincronizar';

  @override
  String get lock => 'Bloquear';

  @override
  String get add => 'Añadir';

  @override
  String get all => 'Todas';

  @override
  String get favorites => 'Favoritos';

  @override
  String syncErrorBanner(Object error) {
    return '$error\nLos códigos siguen funcionando; los cambios necesitan conexión.';
  }

  @override
  String undecryptableEntries(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entradas no se pueden descifrar.',
      one: '1 entrada no se puede descifrar.',
    );
    return '$_temp0';
  }

  @override
  String get noMatches => 'Sin resultados';

  @override
  String get noAccountsYet => 'Aún no hay cuentas';

  @override
  String get noAccountsHint =>
      'Activa el inicio de sesión en dos pasos en un servicio y escanea el código QR que aparece, o importa tus cuentas desde otra app.';

  @override
  String get addAccount => 'Añadir cuenta';

  @override
  String get search => 'Buscar';

  @override
  String get clear => 'Borrar';

  @override
  String get signOutDeviceQuestion => '¿Cerrar la sesión del dispositivo?';

  @override
  String signOutDeviceMessage(Object device) {
    return '«$device» pierde el acceso de inmediato. Si no fuiste tú, cambia también después tu contraseña maestra: quien pudo iniciar sesión la conoce.';
  }

  @override
  String get deviceSignedOut => 'Sesión del dispositivo cerrada';

  @override
  String newSignIn(Object device, Object platform, Object time) {
    return 'Nuevo inicio de sesión: $device$platform, $time';
  }

  @override
  String get thatWasMe => 'Fui yo';

  @override
  String get deleteEntryMessage =>
      'La entrada desaparece en todos los dispositivos. Durante 30 días se puede restaurar desde la papelera (ajustes).';

  @override
  String get deleteEntrySharedMessage =>
      'La entrada desaparece en todos los dispositivos y para todas las personas con las que se comparte la bóveda. Durante 30 días se puede restaurar desde la papelera (ajustes).';

  @override
  String get newVault => 'Nueva bóveda';

  @override
  String get newVaultMessage =>
      'Una bóveda propia se puede compartir con otros usuarios de este servidor, p. ej. «Equipo» o «Familia».';

  @override
  String get name => 'Nombre';

  @override
  String get vaultsExplanation =>
      'Cada bóveda tiene su propia clave. Al compartir, se cifra con la clave pública del destinatario: el servidor nunca ve los códigos.';

  @override
  String get personal => 'Personal';

  @override
  String ownedBy(Object owner) {
    return 'de $owner';
  }

  @override
  String get roleOwner => 'Propietario';

  @override
  String get roleWrite => 'Lectura y escritura';

  @override
  String get roleRead => 'Solo lectura';

  @override
  String accountCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cuentas',
      one: '1 cuenta',
    );
    return '$_temp0';
  }

  @override
  String memberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count miembros',
      one: '1 miembro',
    );
    return '$_temp0';
  }

  @override
  String get shareWith => 'Compartir con';

  @override
  String get thatIsYou => 'Eres tú';

  @override
  String shareWithUser(Object user) {
    return 'Compartir con $user';
  }

  @override
  String get compareFingerprint =>
      'Por seguridad, comparad la huella de la clave, p. ej. por teléfono. La otra persona la encuentra en «Bóvedas y compartir». Si no coincide, no compartas.';

  @override
  String fingerprintOf(Object user) {
    return 'Huella de $user:';
  }

  @override
  String get roleReadHint => 'Ver y copiar códigos';

  @override
  String get roleWriteHint => 'También añadir, cambiar y eliminar cuentas';

  @override
  String get share => 'Compartir';

  @override
  String get vaultGone => 'La bóveda ya no está disponible';

  @override
  String get rename => 'Renombrar';

  @override
  String get personalVaultNotShared =>
      'Tu bóveda personal no se puede compartir.';

  @override
  String get personalVaultNotSharedHint =>
      'Crea una bóveda propia para las cuentas compartidas y muévelas allí.';

  @override
  String get yourFingerprint => 'La huella de tu clave';

  @override
  String get members => 'Miembros';

  @override
  String memberYou(Object user) {
    return '$user (tú)';
  }

  @override
  String get remove => 'Quitar';

  @override
  String removeMemberQuestion(Object user) {
    return '¿Quitar a $user?';
  }

  @override
  String removeMemberMessage(Object user) {
    return '$user pierde el acceso a esta bóveda. Después Sixora renueva la clave de la bóveda para que la antigua ya no abra nada. Las claves de las cuentas que $user ya vio siguen siendo conocidas: si hace falta, configúralas de nuevo en el servicio.';
  }

  @override
  String get deleteVault => 'Eliminar bóveda';

  @override
  String get deleteVaultHint =>
      'Con todas sus cuentas, para todos los miembros';

  @override
  String deleteVaultQuestion(Object name) {
    return '¿Eliminar «$name»?';
  }

  @override
  String get deleteVaultMessage =>
      'Todas las cuentas de esta bóveda se eliminarán para todos los miembros.';

  @override
  String get leaveVault => 'Salir de la bóveda';

  @override
  String leaveVaultQuestion(Object name) {
    return '¿Salir de «$name»?';
  }

  @override
  String get leaveVaultMessage =>
      'Dejarás de ver sus cuentas hasta que te vuelvan a invitar.';

  @override
  String get leave => 'Salir';

  @override
  String get editAccount => 'Editar cuenta';

  @override
  String get save => 'Guardar';

  @override
  String get newAccount => 'Nueva cuenta';

  @override
  String get enterKey => 'Introduce la clave…';

  @override
  String get service => 'Servicio';

  @override
  String get serviceExample => 'p. ej. GitHub';

  @override
  String get accountName => 'Cuenta';

  @override
  String get accountExample => 'p. ej. nombre@example.org';

  @override
  String get secretKey => 'Clave secreta';

  @override
  String get secretKeyHint => 'Base32, los espacios no importan';

  @override
  String get groupOptional => 'Grupo (opcional)';

  @override
  String get groupExample => 'p. ej. Trabajo';

  @override
  String get chooseGroup => 'Elegir un grupo existente';

  @override
  String get vault => 'Bóveda';

  @override
  String get favorite => 'Favorito';

  @override
  String get favoriteHint => 'Aparece arriba en la lista';

  @override
  String get icon => 'Icono';

  @override
  String get initialLetter => 'Letra inicial';

  @override
  String iconAutomatic(Object name) {
    return '$name (automático)';
  }

  @override
  String get initialLetterNoLogo =>
      'Letra inicial (no se encontró un logotipo)';

  @override
  String get unknown => 'Desconocido';

  @override
  String get color => 'Color';

  @override
  String get colorAuto => 'Auto';

  @override
  String get notesOptional => 'Notas (opcional)';

  @override
  String get advanced => 'Avanzado';

  @override
  String get timeBased => 'Por tiempo';

  @override
  String get counter => 'Contador';

  @override
  String get algorithm => 'Algoritmo';

  @override
  String get digits => 'Dígitos';

  @override
  String get periodSeconds => 'Intervalo (s)';

  @override
  String get chooseIcon => 'Elegir icono';

  @override
  String get searchServiceExample => 'Buscar un servicio, p. ej. Google';

  @override
  String get automatic => 'Automático';

  @override
  String get letter => 'Letra';

  @override
  String get noLogoFound => 'No se encontró ningún logotipo';

  @override
  String logosCredit(Object version) {
    return 'Logotipos: Simple Icons $version. Las marcas pertenecen a sus propietarios.';
  }

  @override
  String digitsCount(int count) {
    return '$count dígitos';
  }

  @override
  String unexpectedError(Object error) {
    return 'Error inesperado: $error';
  }

  @override
  String get biometrics => 'Biometría';

  @override
  String get enterServerAddress => 'Introduce la dirección del servidor';

  @override
  String get invalidAddress => 'Dirección no válida';

  @override
  String get httpOnlyLocal =>
      'El HTTP sin cifrar solo se permite en la red local. Usa https://.';

  @override
  String get recoveryKeyMismatch => 'La clave de recuperación no coincide';

  @override
  String get masterPasswordWrong => 'La contraseña maestra es incorrecta';

  @override
  String biometricsInvalidatedEnrolled(Object method) {
    return 'El desbloqueo con $method ya no es válido, p. ej. porque se registró de nuevo un dedo o una cara. Desbloquea con la contraseña maestra y vuelve a configurarlo después.';
  }

  @override
  String biometricsInvalidated(Object method) {
    return 'El desbloqueo con $method ya no es válido. Desbloquea con la contraseña maestra.';
  }

  @override
  String biometricsSetupFailed(Object method, Object reason) {
    return 'No se pudo configurar $method: $reason';
  }

  @override
  String get noSession =>
      'No hay sesión. Bloquea y desbloquea con la contraseña.';

  @override
  String get accountDisabledNotice => 'Tu cuenta ha sido bloqueada.';

  @override
  String get deviceSignedOutNotice =>
      'Se cerró la sesión en este dispositivo (contraseña cambiada o dispositivo eliminado). Vuelve a iniciar sesión.';

  @override
  String noServerConnection(Object reason) {
    return 'Sin conexión con el servidor. $reason.';
  }

  @override
  String backupWrittenMismatch(Object found, Object expected) {
    return 'La copia escrita contiene $found cuentas en lugar de $expected';
  }

  @override
  String backupFailed(Object reason) {
    return 'Error en la copia de seguridad: $reason';
  }

  @override
  String get backupOtherAccount =>
      'La copia de seguridad se configuró para otra cuenta. Vuelve a configurarla.';

  @override
  String get backupNotSetUp =>
      'La copia de seguridad automática no está configurada';

  @override
  String get noBackupInFolder =>
      'No hay ninguna copia de seguridad en la carpeta';

  @override
  String backupUnreadable(Object reason) {
    return 'No se puede leer la copia de seguridad: $reason';
  }

  @override
  String get vaultKeyRenewed =>
      'La clave de la bóveda se acaba de renovar. Inténtalo de nuevo.';

  @override
  String get entryChangedElsewhere =>
      'La entrada se cambió entretanto en otro dispositivo. Se ha cargado la versión actual; inténtalo de nuevo.';

  @override
  String get vaultReadOnly => 'No puedes escribir en esta bóveda';

  @override
  String get trustedKeysTampered =>
      'Las claves guardadas de tus contactos han sido modificadas. Se ha cancelado por seguridad. Revisa el servidor.';

  @override
  String get aContact => 'un contacto';

  @override
  String memberKeyChanged(Object user) {
    return 'La clave de «$user» es distinta de la anterior. La clave de un usuario nunca cambia, así que esta no viene de «$user». Se ha cancelado por seguridad. Revisa el servidor.';
  }

  @override
  String get currentMasterPasswordWrong =>
      'La contraseña maestra actual es incorrecta';

  @override
  String get accountDeletedNotice => 'Tu cuenta ha sido eliminada.';

  @override
  String get unlockSixora => 'Desbloquear Sixora';

  @override
  String get fingerprint => 'Huella dactilar';

  @override
  String setUpUnlockWith(Object method) {
    return 'Configurar el desbloqueo con $method';
  }

  @override
  String get autoLockImmediately => 'Al salir';

  @override
  String autoLockMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'Tras $minutes minutos',
      one: 'Tras 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get autoLockOneHour => 'Tras 1 hora';

  @override
  String get autoLockNever => 'Nunca';

  @override
  String get users => 'Usuarios';

  @override
  String get invites => 'Invitaciones';

  @override
  String get log => 'Registro';

  @override
  String get adminCannotSee =>
      'Como administrador no ves los códigos de otros usuarios ni puedes restablecer contraseñas: el cifrado lo impide.';

  @override
  String since(Object date) {
    return 'desde $date';
  }

  @override
  String deleteUserQuestion(Object user) {
    return '¿Eliminar a $user?';
  }

  @override
  String get deleteUserMessage =>
      'La cuenta, todos sus códigos y las bóvedas que le pertenecen se eliminarán definitivamente.';

  @override
  String get revokeAdmin => 'Quitar derechos de administrador';

  @override
  String get makeAdmin => 'Hacer administrador';

  @override
  String get unblock => 'Desbloquear';

  @override
  String get block => 'Bloquear';

  @override
  String get createInvite => 'Crear invitación';

  @override
  String get createInviteHint => 'Un solo uso, válida 7 días';

  @override
  String get inviteFor => '¿Para quién? (opcional)';

  @override
  String get create => 'Crear';

  @override
  String get invite => 'Invitación';

  @override
  String inviteInstructions(Object date) {
    return 'Escanéala en la app de Sixora con «Escanear código QR de invitación» o envía el enlace: la dirección del servidor y el código ya quedan rellenados. Válida hasta el $date, de un solo uso. El código y el enlace solo se muestran ahora.';
  }

  @override
  String get copyLink => 'Copiar enlace';

  @override
  String get done => 'Listo';

  @override
  String get noOpenInvites => 'No hay invitaciones abiertas';

  @override
  String inviteDates(Object created, Object expires) {
    return 'Creada $created · válida hasta $expires';
  }

  @override
  String get withdraw => 'Retirar';

  @override
  String get chooseExportFilesOrImages =>
      'Elegir archivos de exportación o imágenes';

  @override
  String get nothingNew => 'No se encontró nada nuevo';

  @override
  String get backupPassword => 'Contraseña de la copia de seguridad';

  @override
  String get decrypt => 'Descifrar';

  @override
  String accountsImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cuentas importadas',
      one: '1 cuenta importada',
    );
    return '$_temp0';
  }

  @override
  String get supported => 'Compatibles:';

  @override
  String get supportedFormats =>
      '• Google Authenticator: «Transferir cuentas» → escanear los códigos QR o elegir capturas (todas a la vez si hay varios códigos)\n• Aegis: exportación como JSON sin cifrar\n• 2FAS: copia sin contraseña (.2fas)\n• Bitwarden: exportación como JSON (sin cifrar) o CSV\n• andOTP: exportación JSON sin cifrar\n• FreeOTP+: exportación JSON\n• 2FAuth: exportación como JSON\n• Sixora: copia de seguridad cifrada\n• Todo lo que tenga enlaces otpauth://, p. ej. Ente Auth (exportación como texto) o archivos de texto';

  @override
  String get microsoftNoExport =>
      'Microsoft Authenticator y Authy no permiten exportar. Configura de nuevo cada cuenta en el servicio o vuelve a mostrar el código QR.';

  @override
  String get chooseFilesOrImages => 'Elegir archivos o imágenes';

  @override
  String missingTransferCodes(Object codes) {
    return 'Aún falta el código $codes.';
  }

  @override
  String get missingTransferCodesHint =>
      'Google Authenticator reparte las cuentas en varios códigos QR. Añade también los que faltan.';

  @override
  String get addMoreFiles => 'Añadir más imágenes o archivos';

  @override
  String get alreadyPresent => 'ya existe';

  @override
  String get groupForUngrouped => 'Grupo para cuentas sin grupo';

  @override
  String progressOf(Object done, Object total) {
    return '$done de $total';
  }

  @override
  String importAccounts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Importar $count cuentas',
      one: 'Importar 1 cuenta',
    );
    return '$_temp0';
  }

  @override
  String get tryAgain => 'Reintentar';

  @override
  String get signedInDevicesHint =>
      'Un dispositivo con la sesión cerrada pierde enseguida el acceso al servidor y borra su copia local la próxima vez que se conecte.';

  @override
  String thisDevice(Object device) {
    return '$device (este dispositivo)';
  }

  @override
  String sessionDates(Object created, Object lastSeen) {
    return 'Sesión iniciada $created · última actividad $lastSeen';
  }

  @override
  String signOutDeviceNamed(Object device) {
    return '¿Cerrar la sesión de «$device»?';
  }

  @override
  String get signOutDeviceHint =>
      'Después el dispositivo tendrá que volver a iniciar sesión.';

  @override
  String get eventRegister => 'Cuenta creada';

  @override
  String get eventLogin => 'Inicio de sesión';

  @override
  String get eventLoginFailed => 'Inicio de sesión fallido';

  @override
  String get eventReauthFailed => 'Contraseña incorrecta al cambiar la cuenta';

  @override
  String get eventLogout => 'Cierre de sesión';

  @override
  String get eventPasswordChanged => 'Contraseña maestra cambiada';

  @override
  String get eventRecoveryUsed => 'Clave de recuperación usada';

  @override
  String get eventRecoveryFailed => 'Clave de recuperación incorrecta';

  @override
  String get eventRecoveryKeyChanged => 'Nueva clave de recuperación';

  @override
  String get eventSessionRevoked => 'Sesión de dispositivo cerrada';

  @override
  String get eventAccountDeleted => 'Cuenta eliminada';

  @override
  String get eventVaultShared => 'Bóveda compartida';

  @override
  String get eventVaultUnshared => 'Miembro quitado';

  @override
  String get eventVaultLeft => 'Bóveda abandonada';

  @override
  String get eventVaultDeleted => 'Bóveda eliminada';

  @override
  String get eventInviteCreated => 'Invitación creada';

  @override
  String get eventInviteDeleted => 'Invitación eliminada';

  @override
  String get eventUserUpdated => 'Usuario modificado';

  @override
  String get eventUserDeleted => 'Usuario eliminado';

  @override
  String get noEntries => 'No hay entradas';

  @override
  String accountsFound(int count, Object source) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cuentas encontradas en $source',
      one: '1 cuenta encontrada en $source',
    );
    return '$_temp0';
  }

  @override
  String notReadable(int count) {
    return ', $count ilegibles';
  }

  @override
  String get existingDeselected => 'Las que ya existen están desmarcadas.';

  @override
  String get blocked => 'bloqueado';

  @override
  String get eventVaultKeyRotated => 'Clave de bóveda renovada';

  @override
  String get writingFirstBackup => 'Escribiendo la primera copia de seguridad…';

  @override
  String get autoBackupExplanation =>
      'Tras los cambios, Sixora escribe una copia de seguridad cifrada de todas las cuentas en una carpeta que elijas, por ejemplo en iCloud, Nextcloud o una memoria USB. Así queda una copia aunque se pierdan el servidor o la cuenta.\n\nSe crea un archivo al día y se conservan los 14 últimos. Solo se escribe mientras Sixora está desbloqueado. Una copia se abre con su contraseña desde «Importar», también en una cuenta nueva.';

  @override
  String get chooseFolderAndSetUp => 'Elegir carpeta y configurar';

  @override
  String get folder => 'Carpeta';

  @override
  String get lastBackup => 'Última copia de seguridad';

  @override
  String get lastBackupFailed => 'La última copia de seguridad falló';

  @override
  String backupErrorDetail(Object error, Object date) {
    return '$error\nÚltima correcta: $date';
  }

  @override
  String get backUpNow => 'Hacer copia ahora';

  @override
  String get backupWritten => 'Copia de seguridad escrita';

  @override
  String get verifyBackup => 'Comprobar copia de seguridad';

  @override
  String get verifyBackupHint =>
      'Abre el archivo más reciente como al restaurar';

  @override
  String get backupOk => 'La copia de seguridad está bien';

  @override
  String get backupNotCurrent => 'Copia legible, pero no actualizada';

  @override
  String get otherFolderOrPassword => 'Otra carpeta o una contraseña nueva';

  @override
  String get turnOff => 'Desactivar';

  @override
  String get turnOffHint => 'Los archivos existentes se quedan en la carpeta';

  @override
  String get saveRecoveryKey => 'Guardar clave de recuperación';

  @override
  String get newRecoveryKeyShown =>
      'Tu nueva clave de recuperación. La anterior ya no es válida.';

  @override
  String get writeDownKey => 'Anota esta clave ahora.';

  @override
  String get recoveryKeyExplanation =>
      'Si olvidas tu contraseña maestra, es la única forma de recuperar tus códigos. Solo se muestra esta vez.';

  @override
  String get copy => 'Copiar';

  @override
  String get copiedRemoveAfterPaste =>
      'Copiada: bórrala del portapapeles después de pegarla';

  @override
  String get saveAsFile => 'Guardar como archivo';

  @override
  String get keyStoredSafely => 'He guardado la clave en un lugar seguro.';

  @override
  String get trashEmpty => 'La papelera está vacía';

  @override
  String get trashExplanation =>
      'Las cuentas eliminadas se quedan cifradas en el servidor durante 30 días y hasta entonces se pueden restaurar.';

  @override
  String deletedOn(Object date) {
    return 'eliminada $date';
  }

  @override
  String get restore => 'Restaurar';

  @override
  String restored(Object name) {
    return '«$name» restaurado';
  }

  @override
  String get deleteForGood => 'Eliminar definitivamente';

  @override
  String get deleteForGoodQuestion => '¿Eliminar definitivamente?';

  @override
  String deleteForGoodMessage(Object name) {
    return 'Después ya no se podrá restaurar «$name».';
  }

  @override
  String get transferAccounts => 'Transferir cuentas';

  @override
  String get noneTransferable =>
      'Ninguna de las cuentas se puede transferir así.';

  @override
  String get previousCode => 'Código anterior';

  @override
  String codeOfTotal(Object page, Object total) {
    return 'Código $page de $total';
  }

  @override
  String get scanInOtherApp => 'Elige «Escanear código QR» en la otra app.';

  @override
  String get scanInGoogleAuthenticator =>
      'En Google Authenticator elige «Importar cuentas» y escanea los códigos uno tras otro. Otras apps como Aegis también leen este formato.';

  @override
  String skippedTransfer(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count cuentas (Steam o intervalos poco habituales) no están incluidas: transfiérelas una a una.',
      one:
          '1 cuenta (Steam o un intervalo poco habitual) no está incluida: transfiérela por separado.',
    );
    return '$_temp0';
  }

  @override
  String get switchCamera => 'Cambiar de cámara';

  @override
  String get noCameraAccess =>
      'Sin acceso a la cámara. Permítelo en los ajustes del sistema.';

  @override
  String cameraUnavailable(Object reason) {
    return 'Cámara no disponible: $reason';
  }

  @override
  String codesCaptured(Object count, Object total) {
    return '$count de $total códigos capturados';
  }

  @override
  String get nextInGoogleAuthenticator =>
      'Pasa al siguiente código en Google Authenticator.';

  @override
  String get continueWithCaptured => 'Continuar con los capturados';

  @override
  String get scanHint =>
      'Apunta la cámara al código QR que muestra el servicio al configurar el inicio de sesión en dos pasos.';

  @override
  String get shortcutCtrlAltO => 'Ctrl+Alt+O';

  @override
  String get openSixora => 'Abrir Sixora';

  @override
  String searchWithShortcut(Object shortcut) {
    return 'Buscar… ($shortcut)';
  }

  @override
  String get favoritesHint => 'Favoritos: marca una cuenta con una estrella';

  @override
  String get unlockEllipsis => 'Desbloquear…';

  @override
  String get quitSixora => 'Salir de Sixora';

  @override
  String get imageNotOpenable =>
      'No se puede abrir la imagen. Guárdala como PNG o JPEG (p. ej. una captura en lugar de una foto HEIC).';

  @override
  String codeListOfSize(Object list, Object size) {
    return '$list de $size';
  }

  @override
  String get autoBackupFolder =>
      'Carpeta para la copia de seguridad automática';

  @override
  String listAnd(Object first, Object last) {
    return '$first y $last';
  }

  @override
  String backupVerified(Object file, int accounts, int files) {
    return '$file se abre con la contraseña y contiene $accounts cuentas. En la carpeta hay $files copias de seguridad.';
  }

  @override
  String backupMissing(Object names) {
    return 'Aún no incluidas: $names. «Hacer copia ahora» las añade.';
  }

  @override
  String recoveryKeyFile(Object user, Object date, Object key) {
    return 'Sixora – clave de recuperación\n\nUsuario: $user\nCreada: $date\n\n$key\n\nPermite establecer una nueva contraseña maestra. Guárdala en un lugar seguro (p. ej. impresa o en un gestor de contraseñas) y no se la enseñes a nadie.\n';
  }

  @override
  String get checkDuplicate => 'Guardada dos veces';

  @override
  String get checkDuplicateHint =>
      'Misma clave, mismos códigos. Basta con una copia; la otra puede ir a la papelera.';

  @override
  String get checkWeak => 'Clave corta';

  @override
  String get checkWeakHint =>
      'Menos de 80 bits. Solo el servicio puede emitir una clave nueva: vuelve a configurar allí el inicio de sesión en dos pasos.';

  @override
  String get checkInvalid => 'Clave no válida';

  @override
  String get checkInvalidHint =>
      'Con ella no se puede calcular ningún código. Revisa la clave.';

  @override
  String get checkUnnamed => 'Sin nombre';

  @override
  String get checkUnnamedHint => 'Ni servicio ni cuenta: difícil de reconocer.';

  @override
  String get withoutLogo => 'Sin logotipo';

  @override
  String get withoutLogoHint =>
      'No se encontró un logotipo adecuado. En el editor puedes elegir uno o fijar la letra.';

  @override
  String allGood(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Todo en orden: $count cuentas revisadas',
      one: 'Todo en orden: 1 cuenta revisada',
    );
    return '$_temp0';
  }

  @override
  String get errOffline => 'Servidor no accesible';

  @override
  String errDns(Object host) {
    return 'No se encontró la dirección «$host» (DNS). ¿Es correcta? Tras un cambio puede tardar hasta una hora.';
  }

  @override
  String get errTls => 'Falló la conexión segura (revisa el certificado)';

  @override
  String get errBadRequest => 'Solicitud no válida';

  @override
  String get errConflict =>
      'Los datos han cambiado entretanto. Inténtalo de nuevo.';

  @override
  String get errDisabled => 'La cuenta está bloqueada';

  @override
  String get errForbidden =>
      'Solo el propietario o un administrador puede hacerlo';

  @override
  String get errInvalidCredentials =>
      'El nombre de usuario o la contraseña son incorrectos';

  @override
  String get errInvalidInvite =>
      'El código de invitación no es válido o ha caducado';

  @override
  String get errInvalidUsername =>
      'Nombre de usuario: 3–64 caracteres, letras, cifras y . _ @ + -';

  @override
  String get errLastAdmin =>
      'No se puede quitar al último administrador. Primero haz administrador a otro usuario.';

  @override
  String get errLimit => 'Demasiadas entradas';

  @override
  String get errNotFound => 'No encontrado';

  @override
  String get errOwnerCannotLeave =>
      'El propietario no puede salir de la bóveda, solo eliminarla';

  @override
  String get errPersonalVault =>
      'La bóveda personal no se puede compartir ni eliminar';

  @override
  String get errRateLimited => 'Demasiados intentos. Inténtalo más tarde.';

  @override
  String get errRegistrationClosed => 'El registro está cerrado';

  @override
  String get errSelf => 'No es posible con tu propia cuenta';

  @override
  String get errTooLarge => 'La solicitud es demasiado grande';

  @override
  String get errUnauthorized => 'La sesión ha caducado';

  @override
  String get errUsernameTaken => 'El nombre de usuario ya está en uso';

  @override
  String errUnexpectedResponse(int status) {
    return 'Respuesta inesperada (error $status): ¿es un servidor Sixora?';
  }

  @override
  String get errServiceOrAccount => 'Indica un servicio o una cuenta';

  @override
  String get errBackupOtherPassword =>
      'Esta copia de seguridad se creó con otra contraseña';

  @override
  String get errDecryptionFailed => 'Error al descifrar';

  @override
  String get errExportDamaged => 'Los datos de exportación están dañados';

  @override
  String get errPeriodRange => 'El intervalo debe estar entre 5 y 600 s';

  @override
  String get errNotGoogleExport =>
      'No es una exportación de Google Authenticator';

  @override
  String get errNotOtpauth => 'No es un enlace otpauth';

  @override
  String get errNoAccountsInFile => 'No se encontraron cuentas en el archivo';

  @override
  String get errEmptyKey => 'Clave vacía';

  @override
  String get errBackupPasswordWrong =>
      'La contraseña de la copia de seguridad es incorrecta';

  @override
  String get errKeyMissing => 'Falta la clave';

  @override
  String get errKeyTooShort => 'La clave es demasiado corta';

  @override
  String get errDigitsRange => 'Los dígitos deben estar entre 4 y 10';

  @override
  String get errTypeUnsupported => 'Tipo no compatible';

  @override
  String get errUnknownFormat => 'Formato desconocido';

  @override
  String get errUnknownBackupFormat =>
      'Formato de copia de seguridad desconocido';

  @override
  String get errInvalidKeyCharacter => 'Carácter no válido en la clave';

  @override
  String get errInvalidKeyParameters => 'Parámetros de clave no válidos';

  @override
  String get errRecoveryKeyInvalid => 'La clave de recuperación no es válida';

  @override
  String get errCounterNegative => 'El contador es negativo';

  @override
  String get errAegisEncrypted =>
      'Copia de Aegis cifrada: expórtala sin cifrar en Aegis';

  @override
  String get choose => 'Elegir';

  @override
  String get err2fasEncrypted =>
      'Copia de 2FAS cifrada: expórtala sin contraseña en 2FAS';

  @override
  String get errBitwardenEncrypted =>
      'Exportación de Bitwarden cifrada: expórtala como «.json» sin cifrar';

  @override
  String get errEnteEncrypted =>
      'Copia de Ente Auth cifrada: expórtala sin cifrar (como archivo de texto)';

  @override
  String get searchEllipsis => 'Buscar…';

  @override
  String get qrFromScreen => 'Código QR de la pantalla';

  @override
  String get qrFromScreenAreaHint =>
      'Selecciona una zona, p. ej. en el navegador';

  @override
  String get qrFromScreenWholeHint => 'Buscar un código en toda la pantalla';

  @override
  String get noQrOnScreen =>
      'No se encontró ningún código QR. El código debe verse completo y legible.';

  @override
  String get noScreenshotTool =>
      'No se encontró ninguna herramienta de capturas (Spectacle, GNOME Screenshot, grim y slurp o scrot).';

  @override
  String get qrFromScreenWindowHint =>
      'Elige una ventana o pantalla, p. ej. el navegador';

  @override
  String get useWithoutServer => 'Usar sin servidor';

  @override
  String get useWithoutServerHint =>
      'Tus códigos se quedan cifrados en este dispositivo. Puedes conectar un servidor más adelante.';

  @override
  String get thisDeviceOnly => 'Solo en este dispositivo';

  @override
  String get localModeHint =>
      'Sin servidor: configura una copia de seguridad automática; si no, los códigos se pierden con el dispositivo.';

  @override
  String get localModeNew =>
      'Elige una contraseña maestra. Protege los códigos en este dispositivo.';

  @override
  String get deleteLocalData => 'Borrar datos locales';

  @override
  String get deleteLocalDataMessage =>
      'Todos los códigos de este dispositivo se borran definitivamente. No se puede deshacer.';

  @override
  String get localBanner =>
      'Tus códigos están solo en este dispositivo. Una copia automática te protege de perderlos.';

  @override
  String get signOutLocalMessage =>
      'Tus códigos se quedan cifrados en este dispositivo. Para abrirlos, elige «Usar sin servidor» e introduce la contraseña maestra.';

  @override
  String get deleteLocalAccountMessage =>
      'Se borran todos tus códigos de este dispositivo. No se puede deshacer. Antes desactiva el inicio de sesión en dos pasos en los servicios o exporta tus cuentas.';

  @override
  String get connectServer => 'Conectar con un servidor';

  @override
  String get connectServerHint =>
      'Pasa tus códigos a tu propio servidor y úsalos en varios dispositivos';

  @override
  String get moveIntro =>
      'Los códigos de este dispositivo se pasan al servidor, cifrados para tu cuenta allí; el servidor nunca los ve en claro. Se omiten los códigos que la cuenta ya tiene. Después se borran los datos locales.';

  @override
  String get moveButton => 'Transferir';

  @override
  String get moveContinue => 'Seguir transfiriendo';

  @override
  String moveProgress(int done, int total) {
    return '$done de $total transferidos';
  }

  @override
  String moveDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count códigos transferidos',
      one: '1 código transferido',
      zero: 'Listo: el servidor ya tenía todos los códigos',
    );
    return '$_temp0';
  }

  @override
  String moveIncomplete(String error) {
    return 'La transferencia se interrumpió ($error). Los códigos restantes siguen en este dispositivo; «Seguir transfiriendo» continúa.';
  }

  @override
  String get moveLost =>
      'Sixora se bloqueó entretanto. Los códigos restantes siguen cifrados en este dispositivo: cierra sesión, elige «Usar sin servidor», ábrelo y transfiere de nuevo.';
}
