import 'package:flutter/material.dart';
import 'package:sixora_core/sixora_core.dart';

import '../data/app_controller.dart';
import '../l10n.dart';
import '../widgets/common.dart';

/// Loads data from the server and shows it, with retry on errors.
class Loader<T> extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, VoidCallback reload)
  builder;

  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  late Future<T> _future = widget.load();

  void _reload() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _future,
    builder: (context, snap) {
      if (snap.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(errorText(snap.error!), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _reload, child: Text(t.tryAgain)),
              ],
            ),
          ),
        );
      }
      if (!snap.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      return RefreshIndicator(
        onRefresh: () async => _reload(),
        child: widget.builder(context, snap.data as T, _reload),
      );
    },
  );
}

IconData platformIcon(String platform) => switch (platform) {
  'android' || 'ios' => Icons.smartphone,
  'macos' || 'windows' || 'linux' => Icons.computer,
  _ => Icons.devices_other,
};

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.read(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.signedInDevices)),
      body: Loader<List<SessionDto>>(
        load: () => c.online((api) => api.sessions()),
        builder: (context, sessions, reload) => ListView(
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(t.signedInDevicesHint),
            ),
            for (final s in sessions)
              ListTile(
                leading: Icon(platformIcon(s.platform)),
                title: Text(
                  s.current ? t.thisDevice(s.deviceName) : s.deviceName,
                ),
                subtitle: Text(
                  t.sessionDates(
                    formatDate(s.createdAt),
                    formatDate(s.lastSeenAt),
                  ),
                ),
                trailing: s.current
                    ? null
                    : IconButton(
                        tooltip: t.signOut,
                        icon: const Icon(Icons.logout),
                        onPressed: () async {
                          final ok = await confirm(
                            context,
                            title: t.signOutDeviceNamed(s.deviceName),
                            message: t.signOutDeviceHint,
                            action: t.signOut,
                            destructive: true,
                          );
                          if (!ok || !context.mounted) return;
                          await runBusy(
                            context,
                            () => c.online((api) => api.revokeSession(s.id)),
                          );
                          reload();
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

String auditLabel(String event) => switch (event) {
  'register' => t.eventRegister,
  'login' => t.eventLogin,
  'login_failed' => t.eventLoginFailed,
  'reauth_failed' => t.eventReauthFailed,
  'logout' => t.eventLogout,
  'password_changed' => t.eventPasswordChanged,
  'recovery_used' => t.eventRecoveryUsed,
  'recovery_failed' => t.eventRecoveryFailed,
  'recovery_key_changed' => t.eventRecoveryKeyChanged,
  'session_revoked' => t.eventSessionRevoked,
  'account_deleted' => t.eventAccountDeleted,
  'vault_shared' => t.eventVaultShared,
  'vault_unshared' => t.eventVaultUnshared,
  'vault_left' => t.eventVaultLeft,
  'vault_deleted' => t.eventVaultDeleted,
  'invite_created' => t.eventInviteCreated,
  'invite_deleted' => t.eventInviteDeleted,
  'admin_user_updated' => t.eventUserUpdated,
  'admin_user_deleted' => t.eventUserDeleted,
  'vault_key_rotated' => t.eventVaultKeyRotated,
  _ => event,
};

IconData auditIcon(String event) => switch (event) {
  'login_failed' || 'recovery_failed' || 'reauth_failed' => Icons.warning_amber,
  'login' || 'register' => Icons.login,
  'logout' || 'session_revoked' => Icons.logout,
  'password_changed' ||
  'recovery_used' ||
  'recovery_key_changed' => Icons.key_outlined,
  _ => Icons.history,
};

class AuditList extends StatelessWidget {
  const AuditList({super.key, required this.events, this.showUser = false});
  final List<AuditDto> events;
  final bool showUser;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: 80),
          Center(child: Text(t.noEntries)),
        ],
      );
    }
    final error = Theme.of(context).colorScheme.error;
    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, i) {
        final e = events[i];
        final warn = e.event.endsWith('_failed');
        return ListTile(
          leading: Icon(auditIcon(e.event), color: warn ? error : null),
          title: Text(auditLabel(e.event)),
          subtitle: Text(
            [
              formatDate(e.at),
              if (showUser && e.username.isNotEmpty) e.username,
              if (e.detail.isNotEmpty) e.detail,
              if (e.ip.isNotEmpty) e.ip,
            ].join(' · '),
          ),
        );
      },
    );
  }
}

class AuditScreen extends StatelessWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.read(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.activity)),
      body: Loader<List<AuditDto>>(
        load: () => c.online((api) => api.accountAudit()),
        builder: (context, events, _) => AuditList(events: events),
      ),
    );
  }
}
