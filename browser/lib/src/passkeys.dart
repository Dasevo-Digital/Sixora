import 'dart:convert';

import 'package:sixora_core/sixora_core.dart';

/// A passkey with its place in the vault.
class StoredPasskey {
  StoredPasskey(this.id, this.vaultId, this.revision, this.passkey);
  final String id;
  final String vaultId;
  final int revision;
  final PasskeyEntry passkey;
}

/// A WebAuthn request of a web page. [origin] comes from the browser
/// (`sender.origin`), everything else from the page.
class PasskeyRequest {
  PasskeyRequest({
    required this.create,
    required this.origin,
    required this.rpId,
    required this.rpName,
    required this.challenge,
    required this.userVerification,
    this.userHandle = '',
    this.userName = '',
    this.displayName = '',
    this.algorithms = const [],
    this.exclude = const [],
    this.allow = const [],
  });

  factory PasskeyRequest.fromJson(String origin, Map<String, Object?> j) {
    final uri = Uri.parse(origin);
    final user = (j['user'] as Map?)?.cast<String, Object?>() ?? const {};
    List<String> ids(Object? list) => [
      for (final id in list as List? ?? const [])
        if (id is String) id,
    ];
    final rp = j['rpId'];
    return PasskeyRequest(
      create: j['kind'] == 'create',
      origin: origin,
      rpId: (rp is String && rp.isNotEmpty ? rp : uri.host).toLowerCase(),
      rpName: j['rpName'] as String? ?? '',
      challenge: j['challenge'] as String? ?? '',
      userVerification: j['userVerification'] as String? ?? 'preferred',
      userHandle: user['id'] as String? ?? '',
      userName: user['name'] as String? ?? '',
      displayName: user['displayName'] as String? ?? '',
      algorithms: [
        for (final a in j['algorithms'] as List? ?? const [])
          if (a is num) a.toInt(),
      ],
      exclude: ids(j['exclude']),
      allow: ids(j['allow']),
    );
  }

  final bool create;
  final String origin;
  final String rpId;
  final String rpName;

  /// base64url.
  final String challenge;

  /// `required`, `preferred` or `discouraged`.
  final String userVerification;
  final String userHandle;
  final String userName;
  final String displayName;
  final List<int> algorithms;
  final List<String> exclude;
  final List<String> allow;

  String get host => Uri.parse(origin).host;

  bool get wantsVerification => userVerification != 'discouraged';

  /// The DOMException name the page gets if this must not go on: what a
  /// browser refuses on its own, as this path bypasses its checks.
  String? get problem {
    final uri = Uri.parse(origin);
    final secure =
        uri.scheme == 'https' ||
        (uri.scheme == 'http' && uri.host == 'localhost');
    if (!secure || !WebAuthn.rpIdFits(rpId, uri.host)) return 'SecurityError';
    if (challenge.isEmpty) return 'TypeError';
    if (create) {
      if (userHandle.isEmpty) return 'TypeError';
      if (algorithms.isNotEmpty &&
          !algorithms.contains(WebAuthn.algorithmEs256)) {
        return 'NotSupportedError';
      }
    }
    return null;
  }

  /// The answer for the page to a new passkey.
  Map<String, Object?> created(PasskeyEntry p, {required bool userVerified}) {
    final client = WebAuthn.clientData(
      type: 'webauthn.create',
      challenge: challenge,
      origin: origin,
    );
    final a = WebAuthn.attest(p, userVerified: userVerified);
    return {
      'id': p.credentialId,
      'clientDataJSON': Base64Url.encode(client),
      'attestationObject': Base64Url.encode(a.attestationObject),
      'authenticatorData': Base64Url.encode(a.authenticatorData),
      'publicKey': Base64Url.encode(a.publicKey),
      'publicKeyAlgorithm': WebAuthn.algorithmEs256,
    };
  }

  /// The answer for the page to a sign-in with [p].
  Map<String, Object?> signedIn(PasskeyEntry p, {required bool userVerified}) {
    final client = WebAuthn.clientData(
      type: 'webauthn.get',
      challenge: challenge,
      origin: origin,
    );
    final a = WebAuthn.assertion(
      p,
      WebAuthn.hash(client),
      userVerified: userVerified,
    );
    return {
      'id': p.credentialId,
      'clientDataJSON': Base64Url.encode(client),
      'authenticatorData': Base64Url.encode(a.authenticatorData),
      'signature': Base64Url.encode(a.signature),
      'userHandle': p.userHandle,
    };
  }
}

/// Which websites have a passkey, for the background script: it opens a
/// window only if there is something to offer. Salted hashes, so the
/// browser profile does not list the sites in the clear.
String passkeyIndex(Iterable<String> rpIds, String salt) => jsonEncode({
  'salt': salt,
  'sites': [for (final id in rpIds.toSet()) passkeySiteHash(salt, id)],
});

String passkeySiteHash(String salt, String rpId) =>
    base64.encode(WebAuthn.hash(utf8.encode('$salt|$rpId')));
