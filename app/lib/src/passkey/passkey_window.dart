import 'package:flutter/material.dart';
import 'package:sixora_core/sixora_core.dart';

import '../autofill/autofill_app.dart';
import '../data/app_controller.dart';
import '../l10n.dart';
import '../widgets/common.dart';
import 'passkey_platform.dart';

/// The small window of a passkey request on Android.
class PasskeyApp extends StatelessWidget {
  const PasskeyApp({super.key, required this.controller, required this.call});

  final AppController controller;
  final PasskeyCall? call;

  @override
  Widget build(BuildContext context) => SideWindowApp(
    controller: controller,
    onClose: () => PasskeyPlatform.fail('cancelled'),
    unlocked: PasskeyWindow(call: call),
  );
}

/// Checks who asks, then signs in or saves. It only ever shows after the
/// lock screen of this window: every use was verified with the master
/// password or biometrics.
class PasskeyWindow extends StatefulWidget {
  const PasskeyWindow({super.key, required this.call});
  final PasskeyCall? call;

  @override
  State<PasskeyWindow> createState() => _PasskeyWindowState();
}

class _PasskeyWindowState extends State<PasskeyWindow> {
  PasskeyRequest? _request;
  String? _refused;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  List<PasskeyItem> _found(AppController c, PasskeyRequest r) => [
    for (final p in c.passkeys)
      if (p.passkey.rpId == r.rpId &&
          (r.allow.isEmpty || r.allow.contains(p.passkey.credentialId)))
        p,
  ];

  Future<void> _prepare() async {
    final c = AppScope.read(context);
    final call = widget.call;
    if (call == null) {
      await PasskeyPlatform.fail('unknown');
      return;
    }
    if (call.refused) {
      setState(() => _refused = t.passkeyUnknownBrowser(call.package));
      return;
    }
    await c.refreshWindow();
    if (!mounted) return;
    final PasskeyRequest request;
    try {
      request = call.parse();
    } on Object {
      await PasskeyPlatform.fail('unknown');
      return;
    }
    if (request.problem != null) {
      await PasskeyPlatform.fail('security');
      return;
    }
    if (request.fromApp && !await appMayUsePasskeysOf(request.rpId, call)) {
      if (mounted) {
        setState(
          () => _refused = t.passkeyAppNotLinked(request.rpId, call.package),
        );
      }
      return;
    }
    if (request.create &&
        c.passkeys.any(
          (p) => request.exclude.contains(p.passkey.credentialId),
        )) {
      await PasskeyPlatform.fail('exists');
      return;
    }
    if (!request.create && _found(c, request).isEmpty) {
      await PasskeyPlatform.fail('none');
      return;
    }
    if (mounted) setState(() => _request = request);
  }

  Future<void> _signIn(PasskeyRequest request, PasskeyEntry passkey) async {
    if (_busy) return;
    setState(() => _busy = true);
    await PasskeyPlatform.finishSignIn(
      passkeyAuthenticationJson(request.signedIn(passkey, userVerified: true)),
    );
  }

  Future<void> _save(PasskeyRequest request) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final created = await AppScope.read(
        context,
      ).createPasskeyFromWindow(request, userVerified: true);
      await PasskeyPlatform.finishCreate(passkeyRegistrationJson(created));
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorText(e);
        });
      }
    }
  }

  void _cancel() => PasskeyPlatform.fail('cancelled');

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final request = _request;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: t.close,
          onPressed: _cancel,
        ),
        title: Text(
          request?.create ?? widget.call?.create ?? false
              ? t.passkeySaveTitle
              : t.passkeySignIn,
        ),
      ),
      body: switch ((_refused, request)) {
        (final String refused, _) => _message(refused),
        (_, null) => const Center(child: CircularProgressIndicator()),
        (_, final PasskeyRequest r) when r.create => _saveBody(r),
        (_, final PasskeyRequest r) => _signInBody(c, r),
      },
    );
  }

  Widget _message(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.gpp_bad_outlined, size: 48),
          const SizedBox(height: 16),
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => PasskeyPlatform.fail('security'),
            child: Text(t.close),
          ),
        ],
      ),
    ),
  );

  /// What the system vouches for; the site's own name proves nothing.
  List<Widget> _who(PasskeyRequest request) => [
    Text(
      request.host,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.titleMedium,
    ),
    if (request.androidPackage case final app?)
      Text(t.passkeyInApp(app), textAlign: TextAlign.center),
  ];

  Widget _signInBody(AppController c, PasskeyRequest request) => ListView(
    padding: const EdgeInsets.symmetric(vertical: 16),
    children: [
      ..._who(request),
      const SizedBox(height: 16),
      for (final item in _found(c, request))
        ListTile(
          leading: const Icon(Icons.key_outlined),
          title: Text(item.passkey.account),
          subtitle: Text(item.passkey.rpId),
          enabled: !_busy,
          onTap: () => _signIn(request, item.passkey),
        ),
    ],
  );

  Widget _saveBody(PasskeyRequest request) {
    final name = request.userName.isNotEmpty
        ? request.userName
        : request.displayName;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.key_outlined, size: 48),
            const SizedBox(height: 16),
            ..._who(request),
            if (name.isNotEmpty) Text(name, textAlign: TextAlign.center),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : () => _save(request),
              child: Text(t.passkeySave),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _cancel,
              child: Text(t.cancel),
            ),
          ],
        ),
      ),
    );
  }
}
