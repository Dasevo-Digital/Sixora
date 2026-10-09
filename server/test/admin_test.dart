import 'package:sixora_core/sixora_core.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

/// Administration.
void main() {
  late Harness h;
  setUp(() async {
    h = Harness();
    await h.start();
  });
  tearDown(() => h.stop());

  test('admin can disable users and is protected as last admin', () async {
    final alice = await TestUser.register(h, 'alice');
    final invite = await alice.api.adminCreateInvite();
    final bob = await TestUser.register(h, 'bob', invite: invite.code);
    final users = await alice.api.adminUsers();
    final bobId = users.firstWhere((u) => u.username == 'bob').id;

    await alice.api.adminUpdateUser(bobId, disabled: true);
    await expectLater(
      bob.api.sync(0),
      throwsA(isA<ApiException>().having((e) => e.unauthorized, '401', true)),
    );
    await expectLater(
      alice.api.adminUpdateUser(alice.account.id, isAdmin: false),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'self')),
    );
    final pre = await h.api().prelogin('alice');
    final keys = VaultCrypto.derivePasswordKeys(
      alice.password,
      pre.salt,
      testKdf,
    );
    await expectLater(
      alice.api.deleteAccount(keys.authKeyB64),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'last_admin')),
    );
    final events = await alice.api.adminAudit();
    expect(events.map((e) => e.event), contains('admin_user_updated'));
  });
}
