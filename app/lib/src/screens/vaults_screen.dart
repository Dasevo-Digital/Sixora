import 'package:flutter/material.dart';
import 'package:sixora_core/sixora_core.dart';

import '../data/app_controller.dart';
import '../l10n.dart';
import '../widgets/common.dart';
import 'account_screens.dart';

class VaultsScreen extends StatelessWidget {
  const VaultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.vaultsAndSharing)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(t.newVault),
        onPressed: () async {
          final name = await askText(
            context,
            title: t.newVault,
            message: t.newVaultMessage,
            label: t.name,
            action: t.addAnyway,
          );
          if (name == null || name.trim().isEmpty || !context.mounted) return;
          await runBusy(context, () => c.createVault(name));
        },
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(t.vaultsExplanation),
          ),
          for (final v in c.vaults)
            ListTile(
              leading: Icon(
                v.shared ? Icons.group_outlined : Icons.lock_outline,
              ),
              title: Text(v.name),
              subtitle: Text(
                [
                  if (v.personal) t.personal,
                  if (v.dto.role != VaultRole.owner) t.ownedBy(v.dto.ownerName),
                  switch (v.dto.role) {
                    VaultRole.owner => t.roleOwner,
                    VaultRole.write => t.roleWrite,
                    VaultRole.read => t.roleRead,
                  },
                  t.accountCount(
                    c.items.where((i) => i.vaultId == v.id).length,
                  ),
                  if (v.dto.memberCount > 1) t.memberCount(v.dto.memberCount),
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
      title: t.shareWith,
      label: t.username,
      action: t.search,
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    final user = await runBusy(context, () => c.lookupUser(name));
    if (user == null || !mounted) return;
    if (user.id == c.account!.id) {
      showMessage(context, t.thatIsYou);
      return;
    }
    var role = VaultRole.read;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(t.shareWithUser(user.username)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.compareFingerprint),
                const SizedBox(height: 12),
                Text(
                  t.fingerprintOf(user.username),
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
                  child: Column(
                    children: [
                      RadioListTile<VaultRole>(
                        contentPadding: EdgeInsets.zero,
                        value: VaultRole.read,
                        title: Text(t.roleRead),
                        subtitle: Text(t.roleReadHint),
                      ),
                      RadioListTile<VaultRole>(
                        contentPadding: EdgeInsets.zero,
                        value: VaultRole.write,
                        title: Text(t.roleWrite),
                        subtitle: Text(t.roleWriteHint),
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
              child: Text(t.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(t.share),
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
        body: Center(child: Text(t.vaultGone)),
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
              tooltip: t.rename,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final name = await askText(
                  context,
                  title: t.rename,
                  label: t.name,
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
              label: Text(t.share),
              onPressed: () => _share(vault),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          if (vault.personal)
            ListTile(
              leading: Icon(Icons.info_outline),
              title: Text(t.personalVaultNotShared),
              subtitle: Text(t.personalVaultNotSharedHint),
            ),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: Text(t.yourFingerprint),
            subtitle: SelectableText(
              c.myFingerprint,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontFamilyFallback: ['Menlo', 'Consolas'],
              ),
            ),
          ),
          if (!vault.personal) ...[
            SectionTitle(t.members),
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
                              ? t.memberYou(m.username)
                              : m.username,
                        ),
                        subtitle: Text(switch (m.role) {
                          VaultRole.owner => t.roleOwner,
                          VaultRole.write => t.roleWrite,
                          VaultRole.read => t.roleRead,
                        }),
                        trailing: owner && m.role != VaultRole.owner
                            ? IconButton(
                                tooltip: t.remove,
                                icon: const Icon(Icons.person_remove_outlined),
                                onPressed: () async {
                                  final ok = await confirm(
                                    context,
                                    title: t.removeMemberQuestion(m.username),
                                    message: t.removeMemberMessage(m.username),
                                    action: t.remove,
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
                t.deleteVault,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              subtitle: Text(t.deleteVaultHint),
              onTap: () async {
                final ok = await confirm(
                  context,
                  title: t.deleteVaultQuestion(vault.name),
                  message: t.deleteVaultMessage,
                  action: t.delete,
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
                t.leaveVault,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              onTap: () async {
                final ok = await confirm(
                  context,
                  title: t.leaveVaultQuestion(vault.name),
                  message: t.leaveVaultMessage,
                  action: t.leave,
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
