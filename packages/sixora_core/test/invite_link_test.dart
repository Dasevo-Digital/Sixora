import 'package:sixora_core/sixora_core.dart';
import 'package:test/test.dart';

void main() {
  test('round trip', () {
    final link = InviteLink(
      server: Uri.parse('https://otp.example.org/'),
      code: 'ABCD-EFGH-JKLM-NPQR',
    ).build();
    expect(link, startsWith('sixora://invite?'));
    final back = InviteLink.parse(link)!;
    expect(back.server.toString(), 'https://otp.example.org/');
    expect(back.code, 'ABCD-EFGH-JKLM-NPQR');
  });

  test('rejects anything odd', () {
    for (final bad in [
      'https://otp.example.org',
      'sixora://other?server=https%3A%2F%2Fa.org&code=ABCD-EFGH',
      'sixora://invite?server=javascript%3Aalert(1)&code=ABCD-EFGH',
      'sixora://invite?server=ftp%3A%2F%2Fa.org&code=ABCD-EFGH',
      'sixora://invite?server=https%3A%2F%2Fuser%3Apw%40a.org&code=ABCD-EFGH',
      'sixora://invite?server=https%3A%2F%2Fa.org&code=ab',
      'sixora://invite?server=https%3A%2F%2Fa.org&code=%3Cscript%3E1234',
      'sixora://invite?code=ABCD-EFGH',
    ]) {
      expect(InviteLink.parse(bad), isNull, reason: bad);
    }
  });
}
