import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf_io.dart' as io;
import 'package:sixora_server/sixora_server.dart';
import 'package:sqlite3/sqlite3.dart';

Future<void> main(List<String> args) async {
  final ServerConfig config;
  try {
    config = ServerConfig.load(args);
  } on FormatException catch (e) {
    stderr.writeln('FEHLER: ${e.message}');
    exit(64); // EX_USAGE
  }
  if (config.healthcheck) exit(await _healthcheck(config));

  Directory(config.dataDir).createSync(recursive: true);
  final Database db;
  try {
    db = openSixoraDatabase(p.join(config.dataDir, 'sixora.db'));
  } on Object catch (e) {
    stderr.writeln('FEHLER: Datenbank lässt sich nicht öffnen: $e');
    exit(78); // EX_CONFIG
  }
  final app = SixoraServerApp(
    db: db,
    registration: config.registration,
    serverName: config.serverName,
    trustProxy: config.trustProxy,
    tls: config.tls,
    log: (line) => stdout.writeln('${DateTime.now().toIso8601String()} $line'),
  );

  if (config.command.isNotEmpty) {
    exit(_command(app, db, config.command));
  }

  final HttpServer server;
  final address = InternetAddress.tryParse(config.host) ?? config.host;
  if (config.tls) {
    final context = SecurityContext()
      ..useCertificateChain(config.tlsCert!)
      ..usePrivateKey(config.tlsKey!);
    server = await io.serve(
      app.handler,
      address,
      config.port,
      securityContext: context,
      // No "X-Powered-By": it only tells attackers what runs here.
      poweredByHeader: null,
    );
  } else {
    server = await io.serve(
      app.handler,
      address,
      config.port,
      poweredByHeader: null,
    );
  }
  server.autoCompress = true;
  app.startMaintenance();
  stdout.writeln(
    'Sixora-Server $serverVersion auf ${config.tls ? 'https' : 'http'}://'
    '${config.host}:${server.port} (Registrierung: ${config.registration.name})',
  );
  if (!config.tls) {
    stdout.writeln(
      'Hinweis: ohne TLS. Für den Zugriff aus dem Netz einen Reverse-Proxy mit '
      'HTTPS davorschalten oder SIXORA_TLS_CERT/SIXORA_TLS_KEY setzen.',
    );
  }

  Future<void> shutdown(ProcessSignal signal) async {
    stdout.writeln('Beende …');
    app.close();
    await server.close();
    db.close();
    exit(0);
  }

  ProcessSignal.sigint.watch().listen(shutdown);
  if (!Platform.isWindows) ProcessSignal.sigterm.watch().listen(shutdown);
}

Future<int> _healthcheck(ServerConfig config) async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 3)
    ..badCertificateCallback = (_, _, _) => true;
  try {
    final scheme = config.tls ? 'https' : 'http';
    final request = await client.getUrl(
      Uri.parse('$scheme://127.0.0.1:${config.port}/api/v1/info'),
    );
    final response = await request.close().timeout(const Duration(seconds: 3));
    await response.drain<void>();
    return response.statusCode == 200 ? 0 : 1;
  } catch (_) {
    return 1;
  } finally {
    client.close(force: true);
  }
}

int _command(SixoraServerApp app, Database db, List<String> command) {
  String arg(int i) => command.length > i ? command[i] : '';
  switch (command.first) {
    case 'invite':
      final days = int.tryParse(arg(1)) ?? 7;
      final invite = app.createInvite(
        days: days.clamp(1, 90),
        note: command.skip(2).join(' '),
      );
      stdout
        ..writeln('Einladungscode: ${invite['code']}')
        ..writeln('Gültig bis:     ${invite['expiresAt']}');
      return 0;
    case 'users':
      final rows = db.select(
        'SELECT username, is_admin, disabled, created_at FROM users ORDER BY username',
      );
      if (rows.isEmpty) stdout.writeln('Noch keine Benutzer.');
      for (final r in rows) {
        stdout.writeln(
          '${r['username']}'
          '${r['is_admin'] == 1 ? '  [Administrator]' : ''}'
          '${r['disabled'] == 1 ? '  [gesperrt]' : ''}'
          '  seit ${r['created_at']}',
        );
      }
      return 0;
    case 'admin' || 'disable' || 'enable':
      final name = arg(1);
      final column = command.first == 'admin' ? 'is_admin' : 'disabled';
      final value = command.first == 'enable' ? 0 : 1;
      db.execute('UPDATE users SET $column = ? WHERE username = ?', [
        value,
        name,
      ]);
      if (db.updatedRows == 0) {
        stderr.writeln('Benutzer „$name“ nicht gefunden.');
        return 1;
      }
      if (command.first == 'disable') {
        db.execute(
          'DELETE FROM sessions WHERE user_id = (SELECT id FROM users WHERE username = ?)',
          [name],
        );
      }
      stdout.writeln('Erledigt.');
      return 0;
    default:
      stderr.writeln('Unbekannter Befehl „${command.first}“ (siehe --help).');
      return 64;
  }
}
