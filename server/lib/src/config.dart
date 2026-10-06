import 'dart:io';

import 'package:args/args.dart';

enum Registration {
  open,
  invite,
  closed;

  static Registration parse(String? v) => switch (v?.toLowerCase().trim()) {
    'open' => open,
    'closed' => closed,
    null || '' || 'invite' => invite,
    _ => throw FormatException('SIXORA_REGISTRATION: unbekannter Wert „$v“'),
  };
}

/// Server settings from command line arguments and environment variables
/// (arguments win).
class ServerConfig {
  ServerConfig({
    required this.dataDir,
    required this.host,
    required this.port,
    required this.registration,
    required this.trustProxy,
    required this.tlsCert,
    required this.tlsKey,
    required this.serverName,
    this.command = const [],
    this.healthcheck = false,
  });

  final String dataDir;
  final String host;
  final int port;
  final Registration registration;

  /// Take the client address from `X-Forwarded-For` (only behind a reverse
  /// proxy that sets it!).
  final bool trustProxy;
  final String? tlsCert;
  final String? tlsKey;
  final String serverName;

  /// Administrative sub command, e.g. `invite` or `users`.
  final List<String> command;
  final bool healthcheck;

  bool get tls => tlsCert != null && tlsKey != null;

  static final parser = ArgParser()
    ..addOption('data-dir', help: 'Datenverzeichnis (SIXORA_DATA_DIR)')
    ..addOption('host', help: 'Adresse, auf der gelauscht wird (SIXORA_HOST)')
    ..addOption('port', help: 'Port (SIXORA_PORT, Standard 8080)')
    ..addOption(
      'registration',
      help: 'open, invite oder closed (SIXORA_REGISTRATION)',
    )
    ..addOption('tls-cert', help: 'Zertifikatskette PEM (SIXORA_TLS_CERT)')
    ..addOption('tls-key', help: 'Privater Schlüssel PEM (SIXORA_TLS_KEY)')
    ..addFlag('healthcheck', negatable: false, help: 'Für Docker')
    ..addFlag('help', abbr: 'h', negatable: false);

  static ServerConfig load(List<String> args, {Map<String, String>? env}) {
    final e = env ?? Platform.environment;
    final r = parser.parse(args);
    if (r.flag('help')) {
      stdout
        ..writeln('Sixora-Server')
        ..writeln()
        ..writeln('Aufruf: server [Optionen] [Befehl]')
        ..writeln()
        ..writeln('Befehle:')
        ..writeln('  invite [Tage] [Notiz]   Einladungscode erzeugen')
        ..writeln('  users                   Benutzer auflisten')
        ..writeln('  admin <Name>            Benutzer zum Administrator machen')
        ..writeln('  disable <Name>          Benutzer sperren')
        ..writeln('  enable <Name>           Benutzer entsperren')
        ..writeln()
        ..writeln(parser.usage);
      exit(0);
    }
    String? opt(String name, String envName) {
      final v = r.option(name) ?? e[envName];
      return v == null || v.trim().isEmpty ? null : v.trim();
    }

    final port = int.tryParse(opt('port', 'SIXORA_PORT') ?? '8080');
    if (port == null || port < 1 || port > 65535) {
      throw const FormatException('SIXORA_PORT ist ungültig');
    }
    return ServerConfig(
      dataDir: opt('data-dir', 'SIXORA_DATA_DIR') ?? 'data',
      host: opt('host', 'SIXORA_HOST') ?? '0.0.0.0',
      port: port,
      registration: Registration.parse(
        opt('registration', 'SIXORA_REGISTRATION'),
      ),
      trustProxy: _bool(e['SIXORA_TRUST_PROXY']),
      tlsCert: opt('tls-cert', 'SIXORA_TLS_CERT'),
      tlsKey: opt('tls-key', 'SIXORA_TLS_KEY'),
      serverName: e['SIXORA_SERVER_NAME']?.trim().isNotEmpty == true
          ? e['SIXORA_SERVER_NAME']!.trim()
          : 'Sixora',
      command: r.rest,
      healthcheck: r.flag('healthcheck'),
    );
  }

  static bool _bool(String? v) =>
      const {'1', 'true', 'yes', 'ja', 'on'}.contains(v?.toLowerCase().trim());
}
