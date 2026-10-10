import 'package:sixora_core/sixora_core.dart';

/// "123 456" like in the apps; Steam codes stay as they are.
String groupCode(String code) {
  if (code.length < 6 || RegExp('[A-Z]').hasMatch(code)) return code;
  final half = code.length ~/ 2;
  return '${code.substring(0, half)} ${code.substring(half)}';
}

/// The avatar's colour, the same as in the apps: the chosen one, or one
/// derived from the name.
String avatarColor(OtpEntry e) {
  if (e.color case final c?) {
    return '#${(c & 0xffffff).toRadixString(16).padLeft(6, '0')}';
  }
  var hash = 0;
  for (final unit in e.displayName.toLowerCase().codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return 'hsl(${hash % 360}, 55%, 45%)';
}

/// The website of a tab, for matching accounts; null for browser pages.
String? siteOf(String? url) {
  final uri = Uri.tryParse(url ?? '');
  if (uri == null || !{'http', 'https'}.contains(uri.scheme)) return null;
  return uri.host.isEmpty ? null : uri.host;
}

/// The permission the extension asks for: this one server. Match patterns
/// have no port, so it covers the host (a port in it would be accepted but
/// not honoured by Firefox).
String hostPattern(Uri server) {
  final host = server.host.contains(':') ? '[${server.host}]' : server.host;
  return '${server.scheme}://$host/*';
}

/// Seconds until the code changes.
int secondsLeft(OtpEntry e, DateTime now) {
  final period = e.period;
  return period - (now.millisecondsSinceEpoch ~/ 1000) % period;
}
