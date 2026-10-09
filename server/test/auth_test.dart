import 'dart:convert';
import 'dart:io';

import 'package:sixora_core/sixora_core.dart';
import 'package:sixora_server/sixora_server.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

/// Registration, sign-in, limits and sessions.
void main() {
  late Harness h;
  setUp(() async {
    h = Harness();
    await h.start();
  });
  tearDown(() => h.stop());

  test('first user becomes admin, then registration needs an invite', () async {
    final info = await h.api().info();
    expect(info.hasUsers, isFalse);
    expect(info.registration, RegistrationMode.invite);

    final alice = await TestUser.register(h, 'alice');
    expect(alice.account.isAdmin, isTrue);
    expect((await h.api().info()).hasUsers, isTrue);

    await expectLater(
      TestUser.register(h, 'bob'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'invalid_invite'),
      ),
    );
    final invite = await alice.api.adminCreateInvite(note: 'Bob');
    final bob = await TestUser.register(
      h,
      'bob',
      invite: invite.code!.toLowerCase(),
    );
    expect(bob.account.isAdmin, isFalse);
    // Invites are single use.
    await expectLater(
      TestUser.register(h, 'carol', invite: invite.code),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      bob.api.adminUsers(),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
    );
  });

  test('login, wrong password and enumeration-safe prelogin', () async {
    final alice = await TestUser.register(h, 'alice');
    final api = h.api();
    final pre = await api.prelogin('ALICE');
    expect(pre.salt, alice.account.salt);
    final keys = VaultCrypto.derivePasswordKeys(
      alice.password,
      pre.salt,
      KdfParams.fromJson(pre.kdf),
    );
    final r = await api.login(
      username: 'Alice',
      authKey: keys.authKeyB64,
      device: testDevice,
    );
    expect(r.account.id, alice.account.id);
    await UnlockedKeys.unlock(r.account, keys.kek);

    final wrong = VaultCrypto.derivePasswordKeys('nope', pre.salt, testKdf);
    await expectLater(
      h.api().login(
        username: 'alice',
        authKey: wrong.authKeyB64,
        device: testDevice,
      ),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
    );

    final ghost1 = await h.api().prelogin('ghost');
    final ghost2 = await h.api().prelogin('Ghost');
    expect(ghost1.salt, ghost2.salt);
    expect(ghost1.kdf, pre.kdf);
  });

  test('brute force is throttled', () async {
    await TestUser.register(h, 'alice');
    final wrong = base64.encode(List.filled(32, 1));
    for (var i = 0; i < 10; i++) {
      await expectLater(
        h.api().login(username: 'alice', authKey: wrong, device: testDevice),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );
    }
    await expectLater(
      h.api().login(username: 'alice', authKey: wrong, device: testDevice),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 429)),
    );
  });

  test(
    'behind a proxy, forged X-Forwarded-For does not dodge the limits',
    () async {
      await h.stop();
      h = Harness();
      await h.start(trustProxy: true);
      await TestUser.register(h, 'alice');
      final wrong = base64.encode(List.filled(32, 1));
      final client = HttpClient();
      Future<int> attempt(int i, {bool realIp = false}) async {
        final request = await client.postUrl(
          h.url.resolve('api/v1/auth/login'),
        );
        request.headers.contentType = ContentType.json;
        // What NPM sends: the client's own header plus the real address.
        request.headers.set('X-Forwarded-For', '10.0.0.$i, 203.0.113.7');
        if (realIp) request.headers.set('X-Real-IP', '203.0.113.7');
        request.write(jsonEncode({'username': 'nobody$i', 'authKey': wrong}));
        final response = await request.close();
        await response.drain<void>();
        return response.statusCode;
      }

      // 30 failures per address in 15 minutes, then 429 – despite a new
      // forged first entry on every request.
      for (var i = 0; i < 30; i++) {
        expect(await attempt(i, realIp: i.isEven), 401);
      }
      expect(await attempt(99), 429);
      expect(await attempt(98, realIp: true), 429);
      client.close();
    },
  );

  test('closed and open registration', () async {
    await h.stop();
    h = Harness();
    await h.start(registration: Registration.open);
    await TestUser.register(h, 'alice');
    await TestUser.register(h, 'bob');
    await h.stop();

    h = Harness();
    await h.start(registration: Registration.closed);
    // The very first account is always possible, so a server can be set up.
    await TestUser.register(h, 'alice');
    await expectLater(
      TestUser.register(h, 'bob'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          'registration_closed',
        ),
      ),
    );
  });

  test('sessions per account are bounded', () async {
    final alice = await TestUser.register(h, 'alice');
    final pre = await h.api().prelogin('alice');
    final keys = VaultCrypto.derivePasswordKeys(
      alice.password,
      pre.salt,
      testKdf,
    );
    late SixoraApi newest;
    for (var i = 0; i < SixoraServerApp.maxSessionsPerUser + 3; i++) {
      newest = h.api();
      await newest.login(
        username: 'alice',
        authKey: keys.authKeyB64,
        device: DeviceInfo(name: 'Gerät $i', platform: 'test'),
      );
    }
    expect(
      await newest.sessions(),
      hasLength(SixoraServerApp.maxSessionsPerUser),
    );
    // The oldest session (the registration) gave way.
    await expectLater(
      alice.api.sessions(),
      throwsA(isA<ApiException>().having((e) => e.unauthorized, '401', true)),
    );
  });

  test('failed logins with unknown user names are logged', () async {
    final alice = await TestUser.register(h, 'alice');
    await expectLater(
      h.api().login(
        username: 'mallory',
        authKey: base64.encode(List.filled(32, 2)),
        device: testDevice,
      ),
      throwsA(isA<ApiException>()),
    );
    final events = await alice.api.adminAudit();
    expect(
      events.any(
        (e) => e.event == 'login_failed' && e.detail.contains('mallory'),
      ),
      isTrue,
    );
  });
}
