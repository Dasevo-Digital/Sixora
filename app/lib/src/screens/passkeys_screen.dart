import 'package:flutter/material.dart';

import '../data/app_controller.dart';
import '../l10n.dart';
import '../passkey/passkey_platform.dart';
import '../widgets/common.dart';

/// The passkeys in this account. They are made and used in the browser
/// extension; here they can be looked at and deleted.
class PasskeysScreen extends StatefulWidget {
  const PasskeysScreen({super.key});

  @override
  State<PasskeysScreen> createState() => _PasskeysScreenState();
}

class _PasskeysScreenState extends State<PasskeysScreen>
    with WidgetsBindingObserver {
  ({bool supported, bool enabled}) _android = (
    supported: false,
    enabled: false,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _readStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from Android's settings: the choice may have changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _readStatus();
  }

  Future<void> _readStatus() async {
    final status = await PasskeyPlatform.status();
    if (mounted) setState(() => _android = status);
  }

  Future<void> _delete(
    BuildContext context,
    AppController c,
    PasskeyItem item,
  ) async {
    final ok = await confirm(
      context,
      title: t.passkeyDeleteQuestion,
      message: t.passkeyDeleteMessage(item.passkey.rpId),
      action: t.delete,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await runBusy(context, () => c.deletePasskey(item));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.passkeys)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(t.passkeysExplanation),
          ),
          if (_android.supported)
            ListTile(
              leading: Icon(
                _android.enabled ? Icons.check_circle_outline : Icons.tune,
              ),
              title: Text(
                _android.enabled
                    ? t.passkeysAndroidEnabled
                    : t.passkeysAndroidEnable,
              ),
              subtitle: Text(t.passkeysAndroidHint),
              onTap: PasskeyPlatform.openSettings,
            ),
          if (c.passkeys.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Center(child: Text(t.passkeysEmpty)),
            ),
          for (final item in c.passkeys)
            ListTile(
              leading: const Icon(Icons.key_outlined),
              title: Text(item.passkey.label),
              subtitle: Text(
                [
                  if (item.passkey.account.isNotEmpty) item.passkey.account,
                  if (item.passkey.label != item.passkey.rpId)
                    item.passkey.rpId,
                  ?c.vault(item.vaultId)?.name,
                  t.passkeyCreatedOn(formatDate(item.passkey.createdAt)),
                ].join(' · '),
              ),
              trailing: c.vault(item.vaultId)?.canWrite ?? false
                  ? IconButton(
                      tooltip: t.delete,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(context, c, item),
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}
