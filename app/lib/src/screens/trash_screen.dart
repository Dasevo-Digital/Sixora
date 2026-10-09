import 'package:flutter/material.dart';

import '../data/app_controller.dart';
import '../l10n.dart';
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
      appBar: AppBar(title: Text(t.trash)),
      body: Loader<List<TrashItem>>(
        key: _loader,
        load: c.trash,
        builder: (context, items, _) => items.isEmpty
            ? ListView(
                children: [
                  SizedBox(height: 80),
                  Center(child: Text(t.trashEmpty)),
                ],
              )
            : ListView(
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(t.trashExplanation),
                  ),
                  for (final trashed in items)
                    ListTile(
                      leading: EntryAvatar(trashed.item.entry, size: 36),
                      title: Text(trashed.item.entry.displayName),
                      subtitle: Text(
                        [
                          if (trashed.item.entry.account.isNotEmpty)
                            trashed.item.entry.account,
                          ?c.vault(trashed.item.vaultId)?.name,
                          t.deletedOn(formatDate(trashed.deletedAt)),
                        ].join(' · '),
                      ),
                      trailing: Wrap(
                        children: [
                          IconButton(
                            tooltip: t.restore,
                            icon: const Icon(Icons.restore),
                            onPressed: () async {
                              final ok = await runBusy(context, () async {
                                await c.restore(trashed);
                                return true;
                              });
                              if (ok == true && context.mounted) {
                                showMessage(
                                  context,
                                  t.restored(trashed.item.entry.displayName),
                                );
                                _reload();
                              }
                            },
                          ),
                          IconButton(
                            tooltip: t.deleteForGood,
                            icon: const Icon(Icons.delete_forever_outlined),
                            onPressed: () async {
                              final ok = await confirm(
                                context,
                                title: t.deleteForGoodQuestion,
                                message: t.deleteForGoodMessage(
                                  trashed.item.entry.displayName,
                                ),
                                action: t.delete,
                                destructive: true,
                              );
                              if (!ok || !context.mounted) return;
                              await runBusy(context, () => c.purge(trashed));
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
