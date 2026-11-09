import 'package:flutter/material.dart';

import '../data/app_controller.dart';
import '../l10n.dart';
import '../widgets/common.dart';

/// The passkeys in this account. They are made and used in the browser
/// extension; here they can be looked at and deleted.
class PasskeysScreen extends StatelessWidget {
  const PasskeysScreen({super.key});

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
