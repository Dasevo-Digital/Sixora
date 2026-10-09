import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sixora_core/sixora_core.dart';

import '../l10n.dart';
import '../widgets/common.dart';
import 'account_screens.dart';

/// Server administration: users, invites and the audit log.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: Text(t.administration),
        bottom: TabBar(
          tabs: [
            Tab(text: t.users),
            Tab(text: t.invites),
            Tab(text: t.log),
          ],
        ),
      ),
      body: const TabBarView(children: [_Users(), _Invites(), _Audit()]),
    ),
  );
}

class _Users extends StatelessWidget {
  const _Users();

  @override
  Widget build(BuildContext context) {
    final c = AppScope.read(context);
    return Loader<List<UserDto>>(
      load: () => c.online((api) => api.adminUsers()),
      builder: (context, users, reload) => ListView(
        children: [
          Padding(padding: EdgeInsets.all(16), child: Text(t.adminCannotSee)),
          for (final u in users)
            ListTile(
              leading: CircleAvatar(
                child: Text(u.username.characters.first.toUpperCase()),
              ),
              title: Text(
                u.id == c.account!.id ? t.memberYou(u.username) : u.username,
              ),
              subtitle: Text(
                [
                  if (u.isAdmin) t.administrator,
                  if (u.disabled) t.blocked,
                  t.since(formatDate(u.createdAt)),
                ].join(' · '),
              ),
              trailing: u.id == c.account!.id
                  ? null
                  : PopupMenuButton<String>(
                      onSelected: (action) async {
                        Future<void> Function()? run;
                        switch (action) {
                          case 'admin':
                            run = () => c.online(
                              (api) => api.adminUpdateUser(
                                u.id,
                                isAdmin: !u.isAdmin,
                              ),
                            );
                          case 'disable':
                            run = () => c.online(
                              (api) => api.adminUpdateUser(
                                u.id,
                                disabled: !u.disabled,
                              ),
                            );
                          case 'delete':
                            final ok = await confirm(
                              context,
                              title: t.deleteUserQuestion(u.username),
                              message: t.deleteUserMessage,
                              action: t.delete,
                              destructive: true,
                            );
                            if (ok) {
                              run = () =>
                                  c.online((api) => api.adminDeleteUser(u.id));
                            }
                        }
                        if (run == null || !context.mounted) return;
                        await runBusy(context, run);
                        reload();
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'admin',
                          child: Text(u.isAdmin ? t.revokeAdmin : t.makeAdmin),
                        ),
                        PopupMenuItem(
                          value: 'disable',
                          child: Text(u.disabled ? t.unblock : t.block),
                        ),
                        PopupMenuItem(value: 'delete', child: Text(t.delete)),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

class _Invites extends StatelessWidget {
  const _Invites();

  @override
  Widget build(BuildContext context) {
    final c = AppScope.read(context);
    return Loader<List<InviteDto>>(
      load: () => c.online((api) => api.adminInvites()),
      builder: (context, invites, reload) => ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.add),
            title: Text(t.createInvite),
            subtitle: Text(t.createInviteHint),
            onTap: () async {
              final note = await askText(
                context,
                title: t.createInvite,
                label: t.inviteFor,
                action: t.create,
              );
              if (note == null || !context.mounted) return;
              final invite = await runBusy(
                context,
                () =>
                    c.online((api) => api.adminCreateInvite(note: note.trim())),
              );
              if (invite == null || !context.mounted) return;
              final link = InviteLink(
                server: c.cached!.server,
                code: invite.code!,
              ).build();
              await showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(t.invite),
                  content: SizedBox(
                    width: 360,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: QrImageView(
                              data: link,
                              size: 220,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SelectableText(
                            invite.code!,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontFamily: 'monospace',
                                  fontFamilyFallback: const [
                                    'Menlo',
                                    'Consolas',
                                  ],
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            t.inviteInstructions(formatDate(invite.expiresAt)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: link)),
                      child: Text(t.copyLink),
                    ),
                    TextButton(
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: invite.code!)),
                      child: Text(t.copyCode),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(t.done),
                    ),
                  ],
                ),
              );
              reload();
            },
          ),
          const Divider(),
          if (invites.isEmpty) ListTile(title: Text(t.noOpenInvites)),
          for (final i in invites)
            ListTile(
              leading: const Icon(Icons.confirmation_number_outlined),
              title: Text(i.note.isEmpty ? t.invite : i.note),
              subtitle: Text(
                t.inviteDates(formatDate(i.createdAt), formatDate(i.expiresAt)),
              ),
              trailing: IconButton(
                tooltip: t.withdraw,
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await runBusy(
                    context,
                    () => c.online((api) => api.adminDeleteInvite(i.id)),
                  );
                  reload();
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Audit extends StatelessWidget {
  const _Audit();

  @override
  Widget build(BuildContext context) {
    final c = AppScope.read(context);
    return Loader<List<AuditDto>>(
      load: () => c.online((api) => api.adminAudit()),
      builder: (context, events, _) =>
          AuditList(events: events, showUser: true),
    );
  }
}
