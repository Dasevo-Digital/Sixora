/// Invitation as a link or QR code: server address and invite code in one,
/// so new users type nothing.
///
///     sixora://invite?server=https%3A%2F%2Fotp.example.org%2F&code=ABCD-EFGH-…
class InviteLink {
  const InviteLink({required this.server, required this.code});

  final Uri server;
  final String code;

  static const scheme = 'sixora';

  String build() => Uri(
    scheme: scheme,
    host: 'invite',
    queryParameters: {'server': server.toString(), 'code': code},
  ).toString();

  /// Null for anything that is not a well-formed invitation. Only http(s)
  /// servers are accepted; the app shows the address before connecting.
  static InviteLink? parse(String text) {
    final uri = Uri.tryParse(text.trim());
    if (uri == null || uri.scheme != scheme || uri.host != 'invite') {
      return null;
    }
    final server = Uri.tryParse(uri.queryParameters['server'] ?? '');
    final code = (uri.queryParameters['code'] ?? '').trim();
    if (server == null ||
        !{'http', 'https'}.contains(server.scheme) ||
        server.host.isEmpty ||
        server.userInfo.isNotEmpty ||
        code.length < 8 ||
        code.length > 40 ||
        !RegExp(r'^[A-Za-z0-9-]+$').hasMatch(code)) {
      return null;
    }
    return InviteLink(server: server, code: code);
  }
}
