import 'package:flutter/material.dart';
import 'package:sixora_core/sixora_core.dart';

import '../data/app_controller.dart';
import '../data/service_icons.dart';
import '../l10n.dart';
import '../widgets/common.dart';
import '../widgets/otp_tile.dart';
import 'entry_editor.dart';

/// Looks through all accounts for duplicates, weak or broken secrets,
/// nameless entries and entries without a logo.
class AccountCheckScreen extends StatelessWidget {
  const AccountCheckScreen({super.key});

  static (String, String) _texts(CheckIssue issue) => switch (issue) {
    CheckIssue.duplicate => (t.checkDuplicate, t.checkDuplicateHint),
    CheckIssue.weakSecret => (t.checkWeak, t.checkWeakHint),
    CheckIssue.invalidSecret => (t.checkInvalid, t.checkInvalidHint),
    CheckIssue.unnamed => (t.checkUnnamed, t.checkUnnamedHint),
  };

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final byId = {for (final i in c.items) i.id: i};
    final findings = AccountCheck.analyze({
      for (final i in c.items) i.id: i.entry,
    });
    final icons = ServiceIcons.loaded.value;
    final noLogo = [
      for (final i in c.items)
        if (icons != null &&
            i.entry.icon != OtpEntry.noIcon &&
            icons.forEntry(i.entry) == null)
          i,
    ];

    Widget tile(Item item) => ListTile(
      leading: EntryAvatar(item.entry, size: 36),
      title: Text(item.entry.displayName),
      subtitle: Text(
        [
          if (item.entry.issuer.isNotEmpty) item.entry.account,
          if (c.vaults.length > 1) c.vault(item.vaultId)?.name ?? '',
        ].where((part) => part.isNotEmpty).join(' · '),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => EntryEditor(item: item)),
      ),
    );

    final sections = <Widget>[];
    for (final issue in CheckIssue.values) {
      final groups = [
        for (final f in findings)
          if (f.issue == issue)
            [
              for (final id in f.ids)
                if (byId[id] != null) byId[id]!,
            ],
      ];
      if (groups.isEmpty) continue;
      final (title, help) = _texts(issue);
      sections
        ..add(SectionTitle(title))
        ..add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(help),
          ),
        );
      for (final (n, group) in groups.indexed) {
        if (n > 0) sections.add(const Divider(indent: 16, endIndent: 16));
        sections.addAll(group.map(tile));
      }
    }
    if (noLogo.isNotEmpty) {
      sections
        ..add(SectionTitle(t.withoutLogo))
        ..add(
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(t.withoutLogoHint),
          ),
        )
        ..addAll(noLogo.map(tile));
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.accountCheck)),
      body: sections.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 80),
                Icon(
                  Icons.verified_outlined,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    c.items.isEmpty
                        ? t.noAccountsYet
                        : t.allGood(c.items.length),
                  ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: sections,
            ),
    );
  }
}
