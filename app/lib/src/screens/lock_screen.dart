import 'dart:io';

import 'package:flutter/material.dart';

import '../data/app_controller.dart';
import '../data/biometric_vault.dart';
import '../l10n.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _busy = false;
  String? _error;

  /// Face ID & co. start by themselves once, as soon as the app is active
  /// (phones only).
  bool _autoPending = false;
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    final c = AppScope.read(context);
    // Phones ask right away. On the desktop the lock often comes while
    // nobody is looking (idle timer, closed window): Touch ID or Windows
    // Hello only start with the button.
    if (c.quickUnlockReady && (Platform.isIOS || Platform.isAndroid)) {
      _autoPending = true;
      _lifecycle = AppLifecycleListener(onResume: _autoBiometric);
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoBiometric());
    }
  }

  /// iOS cancels a prompt that starts while the app is still coming to the
  /// front (cold start, or locked in the background) and shows it again:
  /// two scans. So the prompt waits until the app is really active.
  void _autoBiometric() {
    if (!_autoPending || !mounted) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    _autoPending = false;
    _biometric();
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _password.dispose();
    _passwordFocus.dispose();
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

  Future<void> _biometric() async {
    // One prompt at a time, whatever asks for it.
    if (_busy) return;
    await _runBiometric();
  }

  Future<void> _runBiometric() => _run(() async {
    final notUnlocked = await AppScope.read(context).unlockWithBiometrics();
    if (notUnlocked == null || !mounted) return;
    // Cancelled or "Master-Passwort" chosen: on to the password field.
    _passwordFocus.requestFocus();
    if (notUnlocked == BiometricResult.password) {
      setState(() => _error = t.enterSixoraMasterPassword);
    }
  });

  Future<void> _logout() async {
    final c = AppScope.read(context);
    final ok = await confirm(
      context,
      title: t.signOutQuestion,
      message: t.signOutLocalCopyMessage,
      action: t.signOut,
      destructive: true,
    );
    if (ok) await c.logout();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final theme = Theme.of(context);
    final account = c.account!;
    final quick = c.quickUnlockReady;
    return Scaffold(
      body: SafeArea(
        child: FormPage(
          maxWidth: 400,
          children: [
            const Center(child: BrandMark(size: 72)),
            const SizedBox(height: 20),
            Text(
              t.locked,
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
              focusNode: _passwordFocus,
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
                  : Text(t.unlock),
            ),
            if (quick) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: Icon(biometricIcon(c.biometricLabel)),
                label: Text(t.unlockWith(c.biometricLabel)),
                onPressed: _busy ? null : _biometric,
              ),
            ],
            const SizedBox(height: 24),
            TextButton(
              onPressed: _busy ? null : _logout,
              child: Text(t.signOut),
            ),
          ],
        ),
      ),
    );
  }
}
