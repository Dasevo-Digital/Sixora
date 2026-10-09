import 'package:flutter/material.dart';

import '../data/app_controller.dart';
import '../widgets/common.dart';
import '../widgets/otp_tile.dart';
import 'account_screens.dart';

/// Deleted accounts of the last 30 days: restore or remove for good.
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  Key _loader = UniqueKey();

  void _reload() => setState(() => _loader = UniqueKey());

  @override
  Widget build(BuildContext context) {
    final c = AppScope.read(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Papierkorb')),
      body: Loader<List<TrashItem>>(
        key: _loader,
        load: c.trash,
        builder: (context, items, _) => items.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 80),
                  Center(child: Text('Der Papierkorb ist leer')),
                ],
              )
            : ListView(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Gelöschte Konten bleiben 30 Tage verschlüsselt auf dem '
                      'Server und lassen sich bis dahin wiederherstellen.',
                    ),
                  ),
                  for (final t in items)
                    ListTile(
                      leading: EntryAvatar(t.item.entry, size: 36),
                      title: Text(t.item.entry.displayName),
                      subtitle: Text(
                        [
                          if (t.item.entry.account.isNotEmpty)
                            t.item.entry.account,
                          ?c.vault(t.item.vaultId)?.name,
                          'gelöscht ${formatDate(t.deletedAt)}',
                        ].join(' · '),
                      ),
                      trailing: Wrap(
                        children: [
                          IconButton(
                            tooltip: 'Wiederherstellen',
                            icon: const Icon(Icons.restore),
                            onPressed: () async {
                              final ok = await runBusy(context, () async {
                                await c.restore(t);
                                return true;
                              });
                              if (ok == true && context.mounted) {
                                showMessage(
                                  context,
                                  '„${t.item.entry.displayName}“ wiederhergestellt',
                                );
                                _reload();
                              }
                            },
                          ),
                          IconButton(
                            tooltip: 'Endgültig löschen',
                            icon: const Icon(Icons.delete_forever_outlined),
                            onPressed: () async {
                              final ok = await confirm(
                                context,
                                title: 'Endgültig löschen?',
                                message:
                                    '„${t.item.entry.displayName}“ lässt sich danach '
                                    'nicht mehr wiederherstellen.',
                                action: 'Löschen',
                                destructive: true,
                              );
                              if (!ok || !context.mounted) return;
                              await runBusy(context, () => c.purge(t));
                              _reload();
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
