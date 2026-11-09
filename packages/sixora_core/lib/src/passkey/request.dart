import 'dart:convert';

import 'passkey.dart';

/// A WebAuthn request. [origin] is what the platform vouches for: the
/// browser's `sender.origin` in the extension, the allowlisted browser or
/// the signing certificate on Android. Everything else comes from the site.
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
    this.clientDataHash,
    this.androidPackage,
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

  /// The options as WebAuthn defines them in JSON (Android hands these on).
  factory PasskeyRequest.fromWebAuthn(
    String origin,
    String requestJson, {
    required bool create,
    List<int>? clientDataHash,
    String? androidPackage,
  }) {
    final j = (jsonDecode(requestJson) as Map).cast<String, Object?>();
    final rp = (j['rp'] as Map?)?.cast<String, Object?>() ?? const {};
    final user = (j['user'] as Map?)?.cast<String, Object?>() ?? const {};
    final selection =
        (j['authenticatorSelection'] as Map?)?.cast<String, Object?>() ??
        const {};
    List<String> ids(Object? list) => [
      for (final c in list as List? ?? const [])
        if (c is Map && c['id'] is String) c['id'] as String,
    ];
    final rpId = (create ? rp['id'] : j['rpId']) as String? ?? '';
    return PasskeyRequest(
      create: create,
      origin: origin,
      rpId: (rpId.isNotEmpty ? rpId : Uri.parse(origin).host).toLowerCase(),
      rpName: rp['name'] as String? ?? '',
      challenge: j['challenge'] as String? ?? '',
      userVerification:
          (create ? selection['userVerification'] : j['userVerification'])
              as String? ??
          'preferred',
      userHandle: user['id'] as String? ?? '',
      userName: user['name'] as String? ?? '',
      displayName: user['displayName'] as String? ?? '',
      algorithms: [
        for (final p in j['pubKeyCredParams'] as List? ?? const [])
          if (p is Map && p['alg'] is num) (p['alg'] as num).toInt(),
      ],
      exclude: ids(j['excludeCredentials']),
      allow: ids(j['allowCredentials']),
      clientDataHash: clientDataHash,
      androidPackage: androidPackage,
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

  /// Set if the caller (a browser on Android) wrote `clientDataJSON` itself:
  /// the signature covers this hash, and the browser sends its own JSON.
  final List<int>? clientDataHash;

  /// The calling app on Android, unless a browser asks for a website.
  final String? androidPackage;

  static const appOriginPrefix = 'android:apk-key-hash:';

  /// An Android app asks, not a website: it has no address to compare the
  /// rpId with (the caller has to check the site's asset links instead).
  bool get fromApp => origin.startsWith(appOriginPrefix);

  String get host => fromApp ? rpId : Uri.parse(origin).host;

  bool get wantsVerification => userVerification != 'discouraged';

  /// The DOMException name the page gets if this must not go on: what a
  /// browser refuses on its own, as this path bypasses its checks.
  String? get problem {
    if (fromApp) {
      if (!WebAuthn.rpIdFits(rpId, rpId)) return 'SecurityError';
    } else {
      final uri = Uri.parse(origin);
      final secure =
          uri.scheme == 'https' ||
          (uri.scheme == 'http' && uri.host == 'localhost');
      if (!secure || !WebAuthn.rpIdFits(rpId, uri.host)) {
        return 'SecurityError';
      }
    }
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

  /// `clientDataJSON` of this ceremony; only a stand-in if the browser has
  /// its own ([clientDataHash]), which it then sends instead.
  List<int> _client(String type) => clientDataHash != null
      ? utf8.encode('{}')
      : WebAuthn.clientData(
          type: type,
          challenge: challenge,
          origin: origin,
          androidPackage: androidPackage,
        );

  /// The answer for the page to a new passkey.
  Map<String, Object?> created(PasskeyEntry p, {required bool userVerified}) {
    final client = _client('webauthn.create');
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
    final client = _client('webauthn.get');
    final a = WebAuthn.assertion(
      p,
      clientDataHash ?? WebAuthn.hash(client),
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

/// The answer to a new passkey as WebAuthn's `RegistrationResponseJSON`.
Map<String, Object?> passkeyRegistrationJson(Map<String, Object?> created) => {
  'id': created['id'],
  'rawId': created['id'],
  'type': 'public-key',
  'authenticatorAttachment': 'platform',
  'response': {
    'clientDataJSON': created['clientDataJSON'],
    'attestationObject': created['attestationObject'],
    'authenticatorData': created['authenticatorData'],
    'publicKey': created['publicKey'],
    'publicKeyAlgorithm': created['publicKeyAlgorithm'],
    'transports': const ['internal', 'hybrid'],
  },
  'clientExtensionResults': const {
    'credProps': {'rk': true},
  },
};

/// The answer to a sign-in as WebAuthn's `AuthenticationResponseJSON`.
Map<String, Object?> passkeyAuthenticationJson(Map<String, Object?> signedIn) =>
    {
      'id': signedIn['id'],
      'rawId': signedIn['id'],
      'type': 'public-key',
      'authenticatorAttachment': 'platform',
      'response': {
        'clientDataJSON': signedIn['clientDataJSON'],
        'authenticatorData': signedIn['authenticatorData'],
        'signature': signedIn['signature'],
        'userHandle': signedIn['userHandle'],
      },
      'clientExtensionResults': const <String, Object?>{},
    };

/// Whether a site's Digital Asset Links let this Android app use its
/// passkeys. [statements] is the parsed `/.well-known/assetlinks.json`,
/// [fingerprint] the SHA-256 of the app's certificate as `AA:BB:…`.
bool assetLinksAllow(
  Object? statements, {
  required String package,
  required String fingerprint,
}) {
  if (statements is! List) return false;
  for (final s in statements) {
    if (s is! Map) continue;
    final relation = s['relation'];
    final target = s['target'];
    if (relation is! List ||
        !relation.contains('delegate_permission/common.get_login_creds') ||
        target is! Map ||
        target['namespace'] != 'android_app' ||
        target['package_name'] != package) {
      continue;
    }
    final prints = target['sha256_cert_fingerprints'];
    if (prints is List &&
        prints.any(
          (p) => p is String && p.toUpperCase() == fingerprint.toUpperCase(),
        )) {
      return true;
    }
  }
  return false;
}

/// Which websites have a passkey, for the part that decides without
/// unlocking whether to offer one at all (extension background, Android
/// service): a window opens only if there is something to offer. Salted hashes, so the
/// browser profile does not list the sites in the clear.
String passkeyIndex(Iterable<String> rpIds, String salt) => jsonEncode({
  'salt': salt,
  'sites': [for (final id in rpIds.toSet()) passkeySiteHash(salt, id)],
});

String passkeySiteHash(String salt, String rpId) =>
    base64.encode(WebAuthn.hash(utf8.encode('$salt|$rpId')));
