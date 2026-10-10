import 'dart:io';

import 'package:flutter/services.dart';
import 'package:sixora_core/sixora_core.dart';

import '../data/app_controller.dart';

/// Android autofill: Sixora offers "insert code" in the one-time code field
/// of another app or website (`SixoraAutofillService`). Tapping it opens a
/// small Sixora window (`AutofillActivity`, Dart entry point `autofillMain`)
/// that unlocks, lets the user pick the account and hands the current code
/// back; Android puts it into the field.
abstract final class Autofill {
  static const _channel = MethodChannel('sixora/autofill');

  /// Android 8 and later have the autofill framework.
  static Future<({bool supported, bool enabled})> status() async {
    if (!Platform.isAndroid) return (supported: false, enabled: false);
    try {
      final s = await _channel.invokeMapMethod<String, Object?>('status');
      return (
        supported: s?['supported'] == true,
        enabled: s?['enabled'] == true,
      );
    } on MissingPluginException {
      return (supported: false, enabled: false);
    }
  }

  /// Opens the system dialog that makes Sixora the autofill service;
  /// true if the user chose it.
  static Future<bool> enable() async =>
      await _channel.invokeMethod<bool>('enable') ?? false;

  /// Inside the autofill window: which app or website asks.
  static Future<AutofillRequest> request() async {
    final r = await _channel.invokeMapMethod<String, Object?>('request');
    return AutofillRequest(
      domain: r?['domain'] as String?,
      package: r?['package'] as String?,
    );
  }

  /// Hands [code] to the field and closes the window.
  static Future<void> fill(String code) =>
      _channel.invokeMethod<void>('fill', code);

  /// Closes the window without a code.
  static Future<void> cancel() => _channel.invokeMethod<void>('cancel');
}

/// The app or website whose field is to be filled.
class AutofillRequest {
  const AutofillRequest({this.domain, this.package});

  /// Website in a browser, e.g. `github.com`.
  final String? domain;

  /// Android package of the app, e.g. `com.github.android`.
  final String? package;

  /// For the title: the website if there is one, else the app.
  String get label => (domain?.isNotEmpty ?? false) ? domain! : package ?? '';

  /// Words that name the service: "github" from `github.com` or
  /// `com.github.android`. A browser's own package says nothing about the
  /// website, so with a domain only the domain counts.
  Set<String> get words {
    const generic = {
      'www',
      'app',
      'apps',
      'login',
      'signin',
      'auth',
      'account',
      'accounts',
      'secure',
      'mobile',
      'web',
      'sso',
      'portal',
      'my',
      'id',
      'com',
      'org',
      'net',
      'edu',
      'gov',
      'android',
      'client',
      'beta',
      'release',
      'debug',
    };
    final source = (domain?.isNotEmpty ?? false) ? domain! : package ?? '';
    return {
      for (final part in source.toLowerCase().split('.'))
        if (_letters(part) case final w
            when w.length >= 3 && !generic.contains(w))
          w,
    };
  }

  /// Whether [entry] belongs to this app or website (by its service name).
  bool matches(OtpEntry entry) {
    final issuer = _letters(entry.issuer.toLowerCase());
    if (issuer.length < 3) return false;
    return words.any(
      (w) =>
          w == issuer ||
          (w.length >= 4 && issuer.contains(w)) ||
          (issuer.length >= 4 && w.contains(issuer)),
    );
  }

  static String _letters(String s) => s.replaceAll(RegExp('[^a-z0-9]'), '');
}

/// Accounts for the picker: the matching ones first, then the rest. HOTP
/// is left out: using its code moves the counter, which needs the server.
({List<Item> matching, List<Item> others}) autofillChoices(
  List<Item> items,
  AutofillRequest request,
) {
  final usable = [
    for (final i in items)
      if (i.entry.type != OtpType.hotp) i,
  ];
  return (
    matching: [
      for (final i in usable)
        if (request.matches(i.entry)) i,
    ],
    others: [
      for (final i in usable)
        if (!request.matches(i.entry)) i,
    ],
  );
}
