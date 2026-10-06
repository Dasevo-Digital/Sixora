import 'package:flutter/material.dart';
import 'package:sixora_core/sixora_core.dart';

import '../data/app_controller.dart';
import '../widgets/common.dart';
import 'account_screens.dart';

class VaultsScreen extends StatelessWidget {
  const VaultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tresore und Teilen')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Neuer Tresor'),
        onPressed: () async {
          final name = await askText(
            context,
            title: 'Neuer Tresor',
            message:
                'Ein eigener Tresor lässt sich mit anderen Benutzern dieses Servers teilen, '
                'z. B. „Team“ oder „Familie“.',
            label: 'Name',
            action: 'Anlegen',
          );
          if (name == null || name.trim().isEmpty || !context.mounted) return;
          await runBusy(context, () => c.createVault(name));
        },
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Jeder Tresor hat einen eigenen Schlüssel. Beim Teilen wird er mit dem '
              'öffentlichen Schlüssel des Empfängers verschlüsselt – der Server '
              'sieht die Codes nie.',
            ),
          ),
          for (final v in c.vaults)
            ListTile(
              leading: Icon(
                v.shared ? Icons.group_outlined : Icons.lock_outline,
              ),
              title: Text(v.name),
              subtitle: Text(
                [
                  if (v.personal) 'Persönlich',
                  if (v.dto.role != VaultRole.owner) 'von ${v.dto.ownerName}',
                  switch (v.dto.role) {
                    VaultRole.owner => 'Eigentümer',
                    VaultRole.write => 'Lesen und Schreiben',
                    VaultRole.read => 'Nur lesen',
                  },
                  '${c.items.where((i) => i.vaultId == v.id).length} Konten',
                  if (v.dto.memberCount > 1) '${v.dto.memberCount} Mitglieder',
                ].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => VaultDetailScreen(vaultId: v.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class VaultDetailScreen extends StatefulWidget {
  const VaultDetailScreen({super.key, required this.vaultId});
  final String vaultId;

  @override
  State<VaultDetailScreen> createState() => _VaultDetailScreenState();
}

class _VaultDetailScreenState extends State<VaultDetailScreen> {
  final _loader = GlobalKey();

  Future<void> _share(VaultView vault) async {
    final c = AppScope.read(context);
    final name = await askText(
      context,
      title: 'Teilen mit',
      label: 'Benutzername',
      action: 'Suchen',
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    final user = await runBusy(context, () => c.lookupUser(name));
    if (user == null || !mounted) return;
    if (user.id == c.account!.id) {
      showMessage(context, 'Das bist du selbst');
      return;
    }
    var role = VaultRole.read;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text('Mit ${user.username} teilen'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Vergleicht zur Sicherheit den Schlüssel-Fingerabdruck, z. B. am '
                  'Telefon. Er steht bei der anderen Person unter „Tresore und Teilen“. '
                  'Stimmt er nicht, nicht teilen.',
                ),
                const SizedBox(height: 12),
                Text(
                  'Fingerabdruck von ${user.username}:',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                SelectableText(
                  VaultCrypto.fingerprint(user.publicKey),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontFamilyFallback: ['Menlo', 'Consolas'],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                RadioGroup<VaultRole>(
                  groupValue: role,
                  onChanged: (v) => setDialog(() => role = v!),
                  child: const Column(
                    children: [
                      RadioListTile<VaultRole>(
                        contentPadding: EdgeInsets.zero,
                        value: VaultRole.read,
                        title: Text('Nur lesen'),
                        subtitle: Text('Codes sehen und kopieren'),
                      ),
                      RadioListTile<VaultRole>(
                        contentPadding: EdgeInsets.zero,
                        value: VaultRole.write,
                        title: Text('Lesen und Schreiben'),
                        subtitle: Text(
                          'Auch Konten hinzufügen, ändern und löschen',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Teilen'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await runBusy(context, () => c.share(vault, user, role));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final vault = c.vault(widget.vaultId);
    if (vault == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Tresor nicht mehr verfügbar')),
      );
    }
    final owner = vault.dto.role == VaultRole.owner;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(vault.name),
        actions: [
          if (owner)
            IconButton(
              tooltip: 'Umbenennen',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final name = await askText(
                  context,
                  title: 'Umbenennen',
                  label: 'Name',
                  initial: vault.name,
                );
                if (name == null || name.trim().isEmpty || !context.mounted) {
                  return;
                }
                await runBusy(context, () => c.renameVault(vault, name));
              },
            ),
        ],
      ),
      floatingActionButton: owner && !vault.personal
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Teilen'),
              onPressed: () => _share(vault),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          if (vault.personal)
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text(
                'Dein persönlicher Tresor kann nicht geteilt werden.',
              ),
              subtitle: Text(
                'Lege für gemeinsame Konten einen eigenen Tresor an und verschiebe sie dorthin.',
              ),
            ),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text('Dein Schlüssel-Fingerabdruck'),
            subtitle: SelectableText(
              c.myFingerprint,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontFamilyFallback: ['Menlo', 'Consolas'],
              ),
            ),
          ),
          if (!vault.personal) ...[
            const SectionTitle('Mitglieder'),
            SizedBox(
              height: 400,
              child: Loader<List<MemberDto>>(
                key: ValueKey('${_loader.hashCode}-${vault.dto.memberCount}'),
                load: () => c.members(vault.id),
                builder: (context, members, reload) => ListView(
                  children: [
                    for (final m in members)
                      ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            m.username.characters.first.toUpperCase(),
                          ),
                        ),
                        title: Text(
                          m.userId == c.account!.id
                              ? '${m.username} (du)'
                              : m.username,
                        ),
                        subtitle: Text(switch (m.role) {
                          VaultRole.owner => 'Eigentümer',
                          VaultRole.write => 'Lesen und Schreiben',
                          VaultRole.read => 'Nur lesen',
                        }),
                        trailing: owner && m.role != VaultRole.owner
                            ? IconButton(
                                tooltip: 'Entfernen',
                                icon: const Icon(Icons.person_remove_outlined),
                                onPressed: () async {
                                  final ok = await confirm(
                                    context,
                                    title: '${m.username} entfernen?',
                                    message:
                                        '${m.username} verliert den Zugriff auf diesen Tresor. '
                                        'Codes, die bereits gesehen oder kopiert wurden, bleiben '
                                        'natürlich bekannt – bei Bedarf beim Dienst neu einrichten.',
                                    action: 'Entfernen',
                                    destructive: true,
                                  );
                                  if (!ok || !context.mounted) return;
                                  await runBusy(
                                    context,
                                    () => c.removeMember(vault, m.userId),
                                  );
                                  reload();
                                },
                              )
                            : null,
                      ),
                  ],
                ),
              ),
            ),
          ],
          const Divider(),
          if (owner && !vault.personal)
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: theme.colorScheme.error,
              ),
              title: Text(
                'Tresor löschen',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              subtitle: const Text(
                'Mit allen Konten darin, für alle Mitglieder',
              ),
              onTap: () async {
                final ok = await confirm(
                  context,
                  title: '„${vault.name}“ löschen?',
                  message:
                      'Alle Konten in diesem Tresor werden für alle Mitglieder gelöscht.',
                  action: 'Löschen',
                  destructive: true,
                );
                if (!ok || !context.mounted) return;
                final navigator = Navigator.of(context);
                await runBusy(context, () => c.deleteVault(vault));
                navigator.pop();
              },
            ),
          if (!owner)
            ListTile(
              leading: Icon(Icons.exit_to_app, color: theme.colorScheme.error),
              title: Text(
                'Tresor verlassen',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: () async {
                final ok = await confirm(
                  context,
                  title: '„${vault.name}“ verlassen?',
                  message:
                      'Du siehst die Konten darin nicht mehr, bis du erneut eingeladen wirst.',
                  action: 'Verlassen',
                  destructive: true,
                );
                if (!ok || !context.mounted) return;
                final navigator = Navigator.of(context);
                await runBusy(
                  context,
                  () => c.removeMember(vault, c.account!.id),
                );
                navigator.pop();
              },
            ),
        ],
      ),
    );
  }
}
