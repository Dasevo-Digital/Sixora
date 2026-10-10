import 'dart:io';

import '../api/api_client.dart';

/// Turns a network error of `dart:io` into a message for the user; null
/// for anything else.
ApiException? transportError(Object error, Uri uri) {
  if (error is SocketException) {
    // A failed name lookup is a DNS problem, not a server problem: say so,
    // otherwise a wrong or stale DNS record looks like a server outage.
    if (error.message.contains('host lookup') ||
        error.osError?.message.contains('nodename nor servname') == true ||
        error.osError?.message.contains('No address associated') == true) {
      return ApiException(
        0,
        'dns',
        'Adresse „${uri.host}“ nicht gefunden (DNS). Stimmt die Adresse? '
            'Nach einer Änderung kann es bis zu einer Stunde dauern.',
      );
    }
    return const ApiException(0, 'offline', 'Server nicht erreichbar');
  }
  if (error is HandshakeException) {
    return const ApiException(
      0,
      'tls',
      'Sichere Verbindung fehlgeschlagen (Zertifikat prüfen)',
    );
  }
  return null;
}
