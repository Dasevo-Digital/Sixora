import 'dart:convert';

import 'package:sixora_core/sixora_core.dart';
import 'package:test/test.dart';

/// Export files of other apps, shaped like the real ones.
void main() {
  const secret = 'JBSWY3DPEHPK3PXP';

  test('2FAS without password, with groups and HOTP', () async {
    final file = jsonEncode({
      'schemaVersion': 4,
      'groups': [
        {'id': 'g1', 'name': 'Arbeit'},
      ],
      'services': [
        {
          'name': 'GitHub',
          'secret': secret,
          'groupId': 'g1',
          'otp': {
            'account': 'alice',
            'issuer': 'GitHub',
            'digits': 6,
            'period': 30,
            'algorithm': 'SHA1',
            'tokenType': 'TOTP',
          },
        },
        {
          'name': 'Bank',
          'secret': secret,
          'otp': {'label': 'konto', 'tokenType': 'HOTP', 'counter': 4},
        },
        {
          'name': 'Kaputt',
          'secret': '!!!',
          'otp': {'tokenType': 'TOTP'},
        },
      ],
    });
    final r = await Importers.read(file);
    expect(r.source, '2FAS');
    expect(r.entries.map((e) => e.issuer), ['GitHub', 'Bank']);
    expect(r.entries.first.group, 'Arbeit');
    expect(r.entries.last.type, OtpType.hotp);
    expect(r.entries.last.counter, 4);
    expect(r.skipped, 1);
  });

  test('an encrypted 2FAS backup asks for an export without password', () {
    final file = jsonEncode({
      'schemaVersion': 4,
      'services': [],
      'servicesEncrypted': 'abc:def:ghi',
    });
    expect(
      Importers.read(file),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('2FAS'),
        ),
      ),
    );
  });

  test('Bitwarden JSON: otpauth links, bare and steam secrets', () async {
    final file = jsonEncode({
      'encrypted': false,
      'folders': [
        {'id': 'f1', 'name': 'Privat'},
      ],
      'items': [
        {
          'type': 1,
          'name': 'GitHub',
          'folderId': 'f1',
          'favorite': true,
          'login': {
            'username': 'alice',
            'totp': 'otpauth://totp/alice?secret=$secret',
          },
        },
        {
          'type': 1,
          'name': 'Mail',
          'login': {'username': 'bob', 'totp': 'jbsw y3dp ehpk 3pxp'},
        },
        {
          'type': 1,
          'name': 'Steam',
          'login': {'username': 'gamer', 'totp': 'steam://$secret'},
        },
        {
          'type': 1,
          'name': 'Ohne 2FA',
          'login': {'username': 'x', 'totp': null},
        },
        {'type': 2, 'name': 'Notiz'},
      ],
    });
    final r = await Importers.read(file);
    expect(r.source, 'Bitwarden');
    expect(r.entries.map((e) => e.issuer), ['GitHub', 'Mail', 'Steam']);
    expect(r.entries[0].group, 'Privat');
    expect(r.entries[0].favorite, isTrue);
    expect(r.entries[1].account, 'bob');
    expect(r.entries[1].secret, secret);
    expect(r.entries[2].type, OtpType.steam);
  });

  test('Bitwarden CSV with quotes and commas', () async {
    const file =
        'folder,favorite,type,name,notes,fields,reprompt,login_uri,'
        'login_username,login_password,login_totp\n'
        'Privat,1,login,"Firma, GmbH","Notiz mit ""Zitat""",,0,'
        'https://example.org,alice,pw,$secret\n'
        ',,login,Ohne,,,0,,bob,pw,\n';
    final r = await Importers.read(file);
    expect(r.source, 'Bitwarden');
    expect(r.entries.single.issuer, 'Firma, GmbH');
    expect(r.entries.single.account, 'alice');
    expect(r.entries.single.group, 'Privat');
  });

  test('andOTP plain JSON, also with the old Issuer:account label', () async {
    final file = jsonEncode([
      {
        'secret': secret,
        'issuer': 'GitHub',
        'label': 'alice',
        'digits': 6,
        'type': 'TOTP',
        'algorithm': 'SHA1',
        'period': 30,
        'tags': ['Arbeit'],
      },
      {'secret': secret, 'label': 'Bank:konto', 'type': 'TOTP'},
    ]);
    final r = await Importers.read(file);
    expect(r.source, 'andOTP');
    expect(r.entries.first.group, 'Arbeit');
    expect(r.entries.last.issuer, 'Bank');
    expect(r.entries.last.account, 'konto');
  });

  test('FreeOTP+ with signed secret bytes', () async {
    final bytes = Base32.decode(secret);
    final file = jsonEncode({
      'tokens': [
        {
          'algo': 'SHA256',
          'digits': 8,
          'issuerExt': 'GitHub',
          'label': 'alice',
          'period': 60,
          'secret': [for (final b in bytes) b > 127 ? b - 256 : b],
          'type': 'TOTP',
        },
      ],
    });
    final r = await Importers.read(file);
    expect(r.source, 'FreeOTP+');
    final e = r.entries.single;
    expect(e.secret, secret);
    expect(e.algorithm, OtpAlgorithm.sha256);
    expect(e.digits, 8);
    expect(e.period, 60);
  });

  test(
    'Ente Auth: plain text export is read, encrypted one explained',
    () async {
      final r = await Importers.read(
        'otpauth://totp/GitHub:alice?secret=$secret&issuer=GitHub\n'
        'otpauth://totp/Mail:bob?secret=$secret&issuer=Mail\n',
      );
      expect(r.entries, hasLength(2));
      expect(
        Importers.read(
          jsonEncode({
            'version': 1,
            'kdfParams': {'memLimit': 1},
            'encryptedData': 'x',
            'encryptionNonce': 'y',
          }),
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Ente'),
          ),
        ),
      );
    },
  );
}
