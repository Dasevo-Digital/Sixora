import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sixora_core/sixora_core.dart';

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
        title: const Text('Verwaltung'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Benutzer'),
            Tab(text: 'Einladungen'),
            Tab(text: 'Protokoll'),
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
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Als Administrator siehst du keine Codes anderer Benutzer und kannst '
              'keine Passwörter zurücksetzen – das verhindert die Verschlüsselung.',
            ),
          ),
          for (final u in users)
            ListTile(
              leading: CircleAvatar(
                child: Text(u.username.characters.first.toUpperCase()),
              ),
              title: Text(
                u.id == c.account!.id ? '${u.username} (du)' : u.username,
              ),
              subtitle: Text(
                [
                  if (u.isAdmin) 'Administrator',
                  if (u.disabled) 'gesperrt',
                  'seit ${formatDate(u.createdAt)}',
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
                              title: '${u.username} löschen?',
                              message:
                                  'Das Konto, alle seine Codes und die Tresore, die ihm gehören, '
                                  'werden endgültig gelöscht.',
                              action: 'Löschen',
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
                          child: Text(
                            u.isAdmin
                                ? 'Administrator entziehen'
                                : 'Zum Administrator machen',
                          ),
                        ),
                        PopupMenuItem(
                          value: 'disable',
                          child: Text(u.disabled ? 'Entsperren' : 'Sperren'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Löschen'),
                        ),
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
            title: const Text('Einladung erstellen'),
            subtitle: const Text('Einmal verwendbar, 7 Tage gültig'),
            onTap: () async {
              final note = await askText(
                context,
                title: 'Einladung erstellen',
                label: 'Für wen? (optional)',
                action: 'Erstellen',
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
                  title: const Text('Einladung'),
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
                            'In der Sixora-App bei „Einladungs-QR-Code scannen“ '
                            'scannen oder den Link schicken: Server-Adresse und '
                            'Code sind dann schon eingetragen. Gültig bis '
                            '${formatDate(invite.expiresAt)}, nur einmal '
                            'verwendbar. Code und Link werden nur jetzt angezeigt.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: link)),
                      child: const Text('Link kopieren'),
                    ),
                    TextButton(
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: invite.code!)),
                      child: const Text('Code kopieren'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fertig'),
                    ),
                  ],
                ),
              );
              reload();
            },
          ),
          const Divider(),
          if (invites.isEmpty)
            const ListTile(title: Text('Keine offenen Einladungen')),
          for (final i in invites)
            ListTile(
              leading: const Icon(Icons.confirmation_number_outlined),
              title: Text(i.note.isEmpty ? 'Einladung' : i.note),
              subtitle: Text(
                'Erstellt ${formatDate(i.createdAt)} · gültig bis ${formatDate(i.expiresAt)}',
              ),
              trailing: IconButton(
                tooltip: 'Zurückziehen',
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
