import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

final _random = Random.secure();

Uint8List randomBytes(int n) =>
    Uint8List.fromList(List.generate(n, (_) => _random.nextInt(256)));

String sha256Hex(String value) => sha256.convert(utf8.encode(value)).toString();

String newToken() => base64Url.encode(randomBytes(32)).replaceAll('=', '');

String newUuid() {
  final b = randomBytes(16);
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

final uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// Constant-time comparison of two strings of the same alphabet.
bool constantTimeEquals(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}

/// Invite code: 80 random bits as four groups of base32.
String newInviteCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final b = randomBytes(16);
  final chars = [for (final x in b) alphabet[x % alphabet.length]].join();
  return [for (var i = 0; i < 16; i += 4) chars.substring(i, i + 4)].join('-');
}

String normalizeInviteCode(String code) =>
    code.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

/// Counts failed attempts per key (user name, IP) in a sliding window.
class FailureLimiter {
  FailureLimiter({
    required this.max,
    required this.window,
    this.maxKeys = 50000,
  }) : assert(maxKeys > 0);

  final int max;
  final Duration window;
  final int maxKeys;
  final _failures = <String, List<DateTime>>{};
  DateTime? _nextSweep;

  bool blocked(String key, [DateTime? now]) {
    final list = _bucket(key, now ?? DateTime.now(), create: false);
    return (list?.length ?? 0) >= max;
  }

  void fail(String key, [DateTime? now]) {
    final t = now ?? DateTime.now();
    _bucket(key, t, create: true)!.add(t);
  }

  void reset(String key) => _failures.remove(key);

  List<DateTime>? _bucket(String key, DateTime now, {required bool create}) {
    _sweep(now);
    // Remove and reinsert active keys so insertion order is also LRU order.
    final list = _failures.remove(key);
    if (list != null) {
      _removeExpired(list, now);
      if (list.isNotEmpty) {
        _failures[key] = list;
        return list;
      }
    }
    if (!create) return null;
    final fresh = <DateTime>[];
    _failures[key] = fresh;
    while (_failures.length > maxKeys) {
      _failures.remove(_failures.keys.first);
    }
    return fresh;
  }

  void _sweep(DateTime now) {
    final next = _nextSweep;
    if (next != null && now.isBefore(next)) return;
    _failures.removeWhere((_, failures) {
      _removeExpired(failures, now);
      return failures.isEmpty;
    });
    _nextSweep = now.add(window);
  }

  void _removeExpired(List<DateTime> failures, DateTime now) {
    failures.removeWhere((failure) => now.difference(failure) > window);
  }
}
