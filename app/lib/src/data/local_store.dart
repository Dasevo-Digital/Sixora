import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sixora_core/sixora_core.dart';

/// What this device keeps between starts: the account's wrapped key
/// material and the vaults and entries exactly as the server sends them,
/// i.e. encrypted. Unlocking always needs the master password (or the
/// quick unlock key from the keystore), also offline.
class CachedAccount {
  CachedAccount({
    required this.server,
    required this.serverName,
    required this.account,
    this.cursor = 0,
    Map<String, VaultDto>? vaults,
    Map<String, EntryDto>? entries,
    this.lastSync,
  }) : vaults = vaults ?? {},
       entries = entries ?? {};

  final Uri server;
  String serverName;
  AccountBundle account;
  int cursor;
  final Map<String, VaultDto> vaults;
  final Map<String, EntryDto> entries;
  DateTime? lastSync;

  Map<String, Object?> toJson() => {
    'version': 1,
    'server': server.toString(),
    'serverName': serverName,
    'account': account.toJson(),
    'cursor': cursor,
    'vaults': [for (final v in vaults.values) v.toJson()],
    'entries': [for (final e in entries.values) e.toJson()],
    'lastSync': lastSync?.toUtc().toIso8601String(),
  };

  factory CachedAccount.fromJson(Map<String, Object?> j) => CachedAccount(
    server: Uri.parse(j['server'] as String),
    serverName: j['serverName'] as String? ?? 'Sixora',
    account: AccountBundle.fromJson((j['account'] as Map).cast()),
    cursor: (j['cursor'] as num?)?.toInt() ?? 0,
    vaults: {
      for (final v in j['vaults'] as List? ?? const [])
        (v as Map)['id'] as String: VaultDto.fromJson(v.cast()),
    },
    entries: {
      for (final e in j['entries'] as List? ?? const [])
        (e as Map)['id'] as String: EntryDto.fromJson(e.cast()),
    },
    lastSync: DateTime.tryParse(j['lastSync'] as String? ?? '')?.toLocal(),
  );
}

enum AutoLock {
  immediately(0, 'Sofort beim Verlassen'),
  oneMinute(1, 'Nach 1 Minute'),
  fiveMinutes(5, 'Nach 5 Minuten'),
  fifteenMinutes(15, 'Nach 15 Minuten'),
  oneHour(60, 'Nach 1 Stunde'),
  never(-1, 'Nie');

  const AutoLock(this.minutes, this.label);
  final int minutes;
  final String label;

  static AutoLock parse(Object? v) =>
      values.firstWhere((a) => a.name == v, orElse: () => fiveMinutes);
}

class AppSettings {
  AutoLock autoLock = AutoLock.fiveMinutes;
  bool hideCodes = false;
  bool quickUnlock = false;

  /// The offer to unlock with biometrics was shown (or answered).
  bool biometricsOffered = false;

  /// Desktop: closing the window keeps Sixora in the menu bar / tray.
  bool keepInTray = true;

  /// Desktop: ⌥⌘O / Strg+Alt+O brings Sixora to the front.
  bool globalHotkey = true;
  bool clearClipboard = true;
  bool showNextCode = true;
  bool allowScreenshots = false;
  String themeMode = 'system';

  Map<String, Object?> toJson() => {
    'autoLock': autoLock.name,
    'hideCodes': hideCodes,
    'quickUnlock': quickUnlock,
    'biometricsOffered': biometricsOffered,
    'keepInTray': keepInTray,
    'globalHotkey': globalHotkey,
    'clearClipboard': clearClipboard,
    'showNextCode': showNextCode,
    'allowScreenshots': allowScreenshots,
    'themeMode': themeMode,
  };

  static AppSettings fromJson(Map<String, Object?> j) => AppSettings()
    ..autoLock = AutoLock.parse(j['autoLock'])
    ..hideCodes = j['hideCodes'] as bool? ?? false
    ..quickUnlock = j['quickUnlock'] as bool? ?? false
    ..biometricsOffered = j['biometricsOffered'] as bool? ?? false
    ..keepInTray = j['keepInTray'] as bool? ?? true
    ..globalHotkey = j['globalHotkey'] as bool? ?? true
    ..clearClipboard = j['clearClipboard'] as bool? ?? true
    ..showNextCode = j['showNextCode'] as bool? ?? true
    ..allowScreenshots = j['allowScreenshots'] as bool? ?? false
    ..themeMode = j['themeMode'] as String? ?? 'system';
}

/// JSON files in the app's private support folder, written atomically.
class LocalStore {
  LocalStore(this.dir);
  final Directory dir;

  File get _account => File(p.join(dir.path, 'account.json'));
  File get _settings => File(p.join(dir.path, 'settings.json'));

  CachedAccount? loadAccount() {
    final json = _read(_account);
    if (json == null) return null;
    try {
      return CachedAccount.fromJson(json);
    } on Object {
      return null;
    }
  }

  Future<void> saveAccount(CachedAccount account) =>
      _write(_account, account.toJson());

  Future<void> deleteAccount() async {
    if (_account.existsSync()) await _account.delete();
  }

  AppSettings loadSettings() {
    final json = _read(_settings);
    return json == null ? AppSettings() : AppSettings.fromJson(json);
  }

  Future<void> saveSettings(AppSettings settings) =>
      _write(_settings, settings.toJson());

  Map<String, Object?>? _read(File file) {
    if (!file.existsSync()) return null;
    try {
      return (jsonDecode(file.readAsStringSync()) as Map).cast();
    } on Object {
      return null;
    }
  }

  /// Writes go one after another, each through its own temporary file:
  /// sync and edits can save at the same moment.
  Future<void> _queue = Future.value();
  int _serial = 0;

  Future<void> _write(File file, Map<String, Object?> json) {
    final text = jsonEncode(json);
    final tmp = File('${file.path}.${pid}_${_serial++}.tmp');
    final done = _queue.then((_) async {
      await tmp.writeAsString(text, flush: true);
      await tmp.rename(file.path);
    });
    // A failed write must not block the ones after it.
    _queue = done.catchError((Object _) {});
    return done;
  }
}
