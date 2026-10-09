import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Path;
import 'package:path_drawing/path_drawing.dart';
import 'package:sixora_core/sixora_core.dart';

/// One brand logo from Simple Icons: a single SVG path on a 24×24 grid.
class ServiceIcon {
  ServiceIcon(this.title, this.slug, this.hex, this.svgPath, this.aliases);
  final String title;
  final String slug;
  final String hex;
  final String svgPath;
  final List<String> aliases;

  Color get color => Color(0xFF000000 | int.parse(hex, radix: 16));

  Path? _shape;
  Path get shape => _shape ??= parseSvgPathData(svgPath);
}

/// The bundled service icons (built by tool/update_service_icons.py) and the
/// matching of issuer names to them. Everything stays on the device.
class ServiceIcons {
  ServiceIcons._(this.version, this.icons) {
    for (final icon in icons) {
      _bySlug[icon.slug] = icon;
      for (final name in [icon.title, icon.slug, ...icon.aliases]) {
        _byName.putIfAbsent(normalize(name), () => icon);
      }
    }
  }

  final String version;
  final List<ServiceIcon> icons;
  final _bySlug = <String, ServiceIcon>{};
  final _byName = <String, ServiceIcon>{};
  final _guesses = <String, ServiceIcon?>{};

  /// Null until loaded; widgets listen to it.
  static final loaded = ValueNotifier<ServiceIcons?>(null);

  static Future<void> load() async {
    if (loaded.value != null) return;
    try {
      final data = await rootBundle.load('assets/service_icons.json.gz');
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final raw = await Isolate.run(() => _decode(bytes));
      loaded.value = ServiceIcons._(raw.$1, [
        for (final i in raw.$2)
          ServiceIcon(
            i[0] as String,
            i[1] as String,
            i[2] as String,
            i[3] as String,
            (i[4] as List).cast<String>(),
          ),
      ]);
    } on Object catch (e) {
      debugPrint('Dienst-Icons nicht geladen: $e');
    }
  }

  static (String, List<List<Object?>>) _decode(Uint8List bytes) {
    final json = (jsonDecode(utf8.decode(GZipCodec().decode(bytes))) as Map)
        .cast<String, Object?>();
    return (
      json['version'] as String,
      [for (final i in json['icons'] as List) (i as List).cast<Object?>()],
    );
  }

  @visibleForTesting
  static ServiceIcons fromRaw(String version, List<List<Object?>> raw) =>
      ServiceIcons._(version, [
        for (final i in raw)
          ServiceIcon(
            i[0] as String,
            i[1] as String,
            i[2] as String,
            i[3] as String,
            (i[4] as List).cast<String>(),
          ),
      ]);

  static final _umlauts = RegExp('[äöüßéèáàç]');
  static final _other = RegExp('[^a-z0-9]');
  static const _plain = {
    'ä': 'a', 'ö': 'o', 'ü': 'u', 'ß': 'ss', //
    'é': 'e', 'è': 'e', 'á': 'a', 'à': 'a', 'ç': 'c',
  };

  /// Lower case letters and digits only: "Proton Mail" → "protonmail".
  static String normalize(String text) => text
      .toLowerCase()
      .replaceAll('&', 'and')
      .replaceAllMapped(_umlauts, (m) => _plain[m[0]]!)
      .replaceAll(_other, '');

  ServiceIcon? bySlug(String slug) => _bySlug[slug];

  /// The icon to show for [entry]: chosen by the user, or guessed from the
  /// issuer (and, without issuer, from the domain of the account).
  ServiceIcon? forEntry(OtpEntry entry) {
    final chosen = entry.icon;
    if (chosen == OtpEntry.noIcon) return null;
    if (chosen != null) return _bySlug[chosen];
    if (entry.issuer.trim().isNotEmpty) return guess(entry.issuer);
    final at = entry.account.lastIndexOf('@');
    return at < 0 ? null : guess(entry.account.substring(at + 1));
  }

  /// Best match for a service name such as "GitHub", "Proton Mail Bridge"
  /// or "accounts.google.com".
  ServiceIcon? guess(String name) =>
      _guesses.putIfAbsent(name, () => _guess(name.trim()));

  ServiceIcon? _guess(String name) {
    if (name.isEmpty) return null;
    final exact = _byName[normalize(name)];
    if (exact != null) return exact;
    // A host name: the label before the top-level domain.
    final host = RegExp(
      r'^(?:https?://)?([a-z0-9.-]+\.[a-z]{2,})(?:/.*)?$',
    ).firstMatch(name.toLowerCase());
    if (host != null) {
      final labels = host.group(1)!.split('.');
      final label = labels[labels.length - 2];
      final hit = _byName[normalize(label)];
      if (hit != null) return hit;
    }
    // Leading words: "Proton Mail Bridge" → "Proton Mail" → "Proton".
    final words = name
        .split(RegExp(r'[\s:/()\[\]|,–-]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    for (var n = words.length - 1; n >= 1; n--) {
      final key = normalize(words.take(n).join(' '));
      if (key.length < 3) continue;
      final hit = _byName[key];
      if (hit != null) return hit;
    }
    // A name in brackets ("X (Twitter)") or a single distinctive word
    // ("Firma Google Workspace").
    for (final inner in RegExp(r'\(([^)]+)\)').allMatches(name)) {
      final hit = _byName[normalize(inner[1]!)];
      if (hit != null) return hit;
    }
    for (final word in words.skip(1)) {
      final key = normalize(word);
      if (key.length < 4) continue;
      final hit = _byName[key];
      if (hit != null) return hit;
    }
    return null;
  }

  /// Icons whose name contains [query], best matches first.
  List<ServiceIcon> search(String query) {
    final q = normalize(query);
    if (q.isEmpty) return icons;
    final ranked = <(int, ServiceIcon)>[];
    for (final icon in icons) {
      final title = normalize(icon.title);
      final aliases = icon.aliases.map(normalize);
      final rank = title == q || icon.slug == q
          ? 0
          : title.startsWith(q)
          ? 1
          : aliases.any((a) => a == q)
          ? 2
          : aliases.any((a) => a.startsWith(q))
          ? 3
          : title.contains(q) || aliases.any((a) => a.contains(q))
          ? 4
          : -1;
      if (rank >= 0) ranked.add((rank, icon));
    }
    ranked.sort(
      (a, b) => a.$1 != b.$1
          ? a.$1.compareTo(b.$1)
          : a.$2.title.length.compareTo(b.$2.title.length),
    );
    return [for (final r in ranked) r.$2];
  }
}
