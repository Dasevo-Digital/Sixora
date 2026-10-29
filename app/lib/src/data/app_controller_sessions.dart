part of 'app_controller.dart';

extension AppControllerSessions on AppController {
  /// Sign-ins of other devices this device has not seen before: somebody
  /// with the master password – or the user on a new device.
  List<SessionDto> get unknownSessions {
    final c = cached;
    final known = c?.knownSessions;
    if (c == null || known == null) return const [];
    return [
      for (final s in c.sessions)
        if (!s.current && !known.contains(s.id)) s,
    ];
  }

  Future<void> acknowledgeSession(String id) async {
    final c = cached!;
    (c.knownSessions ??= {}).add(id);
    await store.saveAccount(c);
    _notify();
  }

  /// Signs the unknown device out.
  Future<void> revokeSession(String id) async {
    await _online((api) => api.revokeSession(id));
    await acknowledgeSession(id);
    await sync();
  }
}
