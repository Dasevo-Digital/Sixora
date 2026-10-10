import 'entry.dart';

/// Which accounts belong to an app or a website, by the words that name
/// the service: "github" from `github.com` or `com.github.android`. Used by
/// Android autofill and the browser extension to put them first.
class ServiceMatch {
  /// A browser's own package says nothing about the website, so with a
  /// [domain] only the domain counts.
  ServiceMatch({String? domain, String? package})
    : words = _words((domain?.isNotEmpty ?? false) ? domain! : package ?? '');

  final Set<String> words;

  static const _generic = {
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

  static Set<String> _words(String source) => {
    for (final part in source.toLowerCase().split('.'))
      if (_letters(part) case final w
          when w.length >= 3 && !_generic.contains(w))
        w,
  };

  /// Whether [entry] belongs to the service (by its issuer).
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
