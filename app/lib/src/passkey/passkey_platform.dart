import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:sixora_core/sixora_core.dart';

/// A passkey request as Android hands it to `PasskeyActivity`, with what
/// the system vouches for about the caller.
class PasskeyCall {
  const PasskeyCall({
    required this.create,
    required this.requestJson,
    required this.package,
    required this.certificate,
    this.origin,
    this.clientDataHash,
    this.refused = false,
  });

  factory PasskeyCall.fromMap(Map<String, Object?> m) => PasskeyCall(
    create: m['create'] == true,
    requestJson: m['requestJson']! as String,
    package: m['package']! as String,
    certificate: m['certificate']! as Uint8List,
    origin: m['origin'] as String?,
    clientDataHash: m['clientDataHash'] as Uint8List?,
    refused: m['refused'] == true,
  );

  final bool create;
  final String requestJson;

  /// The calling app.
  final String package;

  /// SHA-256 of its signing certificate.
  final Uint8List certificate;

  /// The website, only if a known browser asks for it.
  final String? origin;
  final Uint8List? clientDataHash;

  /// The caller claims a website but is no known browser.
  final bool refused;

  /// `AA:BB:…`, as asset links write it.
  String get fingerprint => [
    for (final b in certificate)
      b.toRadixString(16).padLeft(2, '0').toUpperCase(),
  ].join(':');

  PasskeyRequest parse({bool relatedOrigin = false}) =>
      PasskeyRequest.fromWebAuthn(
        origin ??
            '${PasskeyRequest.appOriginPrefix}${Base64Url.encode(certificate)}',
        requestJson,
        create: create,
        clientDataHash: clientDataHash,
        androidPackage: origin == null ? package : null,
        relatedOrigin: relatedOrigin,
      );
}

/// Whether the website [rpId] lets the calling app use its passkeys
/// (Digital Asset Links). No answer means no.
Future<bool> appMayUsePasskeysOf(String rpId, PasskeyCall call) async =>
    assetLinksAllow(
      await _siteFile(rpId, '/.well-known/assetlinks.json'),
      package: call.package,
      fingerprint: call.fingerprint,
    );

/// Whether the website [rpId] names [origin] as using its passkeys, as
/// openai.com does for chatgpt.com. No answer means no.
Future<bool> originMayUsePasskeysOf(String rpId, String origin) async =>
    relatedOriginsAllow(await _siteFile(rpId, '/.well-known/webauthn'), origin);

/// A site's own JSON file, without following redirects; null if unusable.
Future<Object?> _siteFile(String rpId, String path) async {
  const limit = 512 * 1024;
  const wait = Duration(seconds: 8);
  final client = HttpClient()..connectionTimeout = wait;
  try {
    final request = await client.getUrl(Uri.https(rpId, path)).timeout(wait);
    request.followRedirects = false;
    final response = await request.close().timeout(wait);
    if (response.statusCode != HttpStatus.ok) return null;
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(wait)) {
      bytes.add(chunk);
      if (bytes.length > limit) return null;
    }
    return jsonDecode(utf8.decode(bytes.takeBytes()));
  } on Object {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// The Android side of passkeys (`sixora/passkeys`).
abstract final class PasskeyPlatform {
  static const _channel = MethodChannel('sixora/passkeys');

  /// Android 14 and later have the provider interface.
  static Future<({bool supported, bool enabled})> status() async {
    if (!Platform.isAndroid) return (supported: false, enabled: false);
    final s = await _channel.invokeMapMethod<String, Object?>('status');
    return (supported: s?['supported'] == true, enabled: s?['enabled'] == true);
  }

  /// Android's own page for choosing the passkey providers.
  static Future<void> openSettings() =>
      _channel.invokeMethod<void>('openSettings');

  /// Salted hashes of the sites with a passkey; null forgets them.
  static Future<void> setIndex(String? json) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('setIndex', json);
  }

  /// In the passkey window: what is asked and by whom.
  static Future<PasskeyCall?> request() async {
    final m = await _channel.invokeMapMethod<String, Object?>('request');
    return m == null ? null : PasskeyCall.fromMap(m);
  }

  static Future<void> finishSignIn(Map<String, Object?> json) =>
      _channel.invokeMethod<void>('finishGet', jsonEncode(json));

  static Future<void> finishCreate(Map<String, Object?> json) =>
      _channel.invokeMethod<void>('finishCreate', jsonEncode(json));

  /// `cancelled`, `exists`, `none`, `security` or anything else as unknown.
  static Future<void> fail(String why) =>
      _channel.invokeMethod<void>('fail', why);
}
