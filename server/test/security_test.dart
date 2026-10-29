import 'package:sixora_server/sixora_server.dart';
import 'package:test/test.dart';

void main() {
  test('failure limiter stays bounded and evicts the least recent key', () {
    final limiter = FailureLimiter(
      max: 1,
      window: const Duration(minutes: 15),
      maxKeys: 2,
    );
    final now = DateTime.utc(2026, 1, 1);

    limiter.fail('old', now);
    limiter.fail('kept', now);
    expect(limiter.blocked('kept', now), isTrue); // makes it most recent
    limiter.fail('new', now);

    expect(limiter.blocked('old', now), isFalse);
    expect(limiter.blocked('kept', now), isTrue);
    expect(limiter.blocked('new', now), isTrue);
  });

  test('lookups do not allocate buckets and expired keys are swept', () {
    final limiter = FailureLimiter(
      max: 1,
      window: const Duration(minutes: 1),
      maxKeys: 2,
    );
    final now = DateTime.utc(2026, 1, 1);

    limiter.fail('first', now);
    limiter.fail('second', now);
    for (var i = 0; i < 100; i++) {
      expect(limiter.blocked('unknown-$i', now), isFalse);
    }
    expect(limiter.blocked('first', now), isTrue);
    expect(limiter.blocked('second', now), isTrue);

    final later = now.add(const Duration(minutes: 2));
    limiter.fail('third', later);
    expect(limiter.blocked('first', later), isFalse);
    expect(limiter.blocked('second', later), isFalse);
    expect(limiter.blocked('third', later), isTrue);
  });
}
