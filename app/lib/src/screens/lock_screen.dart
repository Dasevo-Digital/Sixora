import 'package:flutter/material.dart';

import '../data/app_controller.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = AppScope.read(context);
    if (c.settings.quickUnlock && c.hasQuickUnlockKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _biometric());
    }
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlock() async {
    if (_password.text.isEmpty) return;
    final c = AppScope.read(context);
    await _run(() => c.unlockWithPassword(_password.text));
    _password.clear();
  }

  Future<void> _biometric() =>
      _run(AppScope.read(context).unlockWithBiometrics);

  Future<void> _logout() async {
    final c = AppScope.read(context);
    final ok = await confirm(
      context,
      title: 'Abmelden?',
      message:
          'Die lokale Kopie wird von diesem Gerät entfernt. Deine Codes bleiben '
          'auf dem Server und auf deinen anderen Geräten erhalten.',
      action: 'Abmelden',
      destructive: true,
    );
    if (ok) await c.logout();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final theme = Theme.of(context);
    final account = c.account!;
    final quick = c.settings.quickUnlock && c.hasQuickUnlockKey;
    return Scaffold(
      body: SafeArea(
        child: FormPage(
          maxWidth: 400,
          children: [
            const Center(child: BrandMark(size: 72)),
            const SizedBox(height: 20),
            Text(
              'Gesperrt',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${account.username} · ${c.cached!.server.host}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            PasswordField(
              controller: _password,
              autofocus: !quick,
              onSubmitted: (_) => _unlock(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _unlock,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Entsperren'),
            ),
            if (quick) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.fingerprint),
                label: const Text('Mit Gerätesicherheit entsperren'),
                onPressed: _busy ? null : _biometric,
              ),
            ],
            const SizedBox(height: 24),
            TextButton(
              onPressed: _busy ? null : _logout,
              child: const Text('Abmelden'),
            ),
          ],
        ),
      ),
    );
  }
}
