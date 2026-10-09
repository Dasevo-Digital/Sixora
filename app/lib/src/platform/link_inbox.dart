import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:sixora_core/sixora_core.dart';

/// Links the app was opened with: `otpauth://` (a new account),
/// `otpauth-migration://` (Google Authenticator transfer) and
/// `sixora://invite` (invitation). They wait here until a screen that can
/// handle them takes them – e.g. after unlocking.
class LinkInbox extends ValueNotifier<String?> {
  LinkInbox._() : super(null);

  static final instance = LinkInbox._();
  StreamSubscription<Uri>? _sub;

  /// Linux needs an installed desktop file for custom schemes; not yet.
  static bool get supported => !Platform.isLinux;

  Future<void> start() async {
    if (!supported || _sub != null) return;
    try {
      final links = AppLinks();
      _sub = links.uriLinkStream.listen(_receive);
      final initial = await links.getInitialLink();
      if (initial != null) _receive(initial);
    } on Object catch (e) {
      debugPrint('Links nicht verfügbar: $e');
    }
  }

  void _receive(Uri uri) {
    final text = uri.toString();
    if (OtpAuthUri.looksLike(text) ||
        GoogleMigration.looksLike(text) ||
        InviteLink.parse(text) != null) {
      value = text;
    }
  }

  /// Takes the waiting link if [accept] wants it.
  String? take(bool Function(String link) accept) {
    final link = value;
    if (link == null || !accept(link)) return null;
    value = null;
    return link;
  }
}
