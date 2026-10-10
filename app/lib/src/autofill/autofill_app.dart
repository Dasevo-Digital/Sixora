import 'package:flutter/material.dart';

import '../app.dart';
import '../data/app_controller.dart';
import '../l10n.dart';
import '../screens/lock_screen.dart';
import '../widgets/common.dart';
import '../widgets/otp_tile.dart';
import 'autofill.dart';

/// The small window that autofill opens: unlock, pick the account, done.
/// It runs in its own Flutter engine and reads the data like the app, but
/// never syncs or writes (the controller is passive).
class AutofillApp extends StatelessWidget {
  const AutofillApp({
    super.key,
    required this.controller,
    required this.request,
  });

  final AppController controller;
  final AutofillRequest request;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final locale = resolveLocale(controller.settings.language);
      useLocale(locale);
      return AppScope(
        controller: controller,
        child: MaterialApp(
          title: 'Sixora',
          debugShowCheckedModeBanner: false,
          theme: sixoraTheme(Brightness.light),
          darkTheme: sixoraTheme(Brightness.dark),
          themeMode: switch (controller.settings.themeMode) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          },
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: KeyedSubtree(
            key: ValueKey(controller.phase),
            child: switch (controller.phase) {
              Phase.loading => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
              Phase.setup => const _NotSetUp(),
              Phase.locked => const LockScreen(allowSignOut: false),
              Phase.unlocked => AutofillScreen(request: request),
            },
          ),
        ),
      );
    },
  );
}

class _NotSetUp extends StatelessWidget {
  const _NotSetUp();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.autofillNotSetUp, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: Autofill.cancel, child: Text(t.close)),
          ],
        ),
      ),
    ),
  );
}

/// Picks the account whose code goes into the field.
class AutofillScreen extends StatefulWidget {
  const AutofillScreen({super.key, required this.request});
  final AutofillRequest request;

  @override
  State<AutofillScreen> createState() => _AutofillScreenState();
}

class _AutofillScreenState extends State<AutofillScreen> {
  final _search = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _fill(Item item) async {
    if (_busy) return;
    setState(() => _busy = true);
    await Autofill.fill(item.entry.code());
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final query = _search.text.trim().toLowerCase();
    bool shown(Item i) =>
        query.isEmpty ||
        i.entry.issuer.toLowerCase().contains(query) ||
        i.entry.account.toLowerCase().contains(query);
    final choices = autofillChoices(c.items, widget.request);
    final matching = choices.matching.where(shown).toList();
    final others = choices.others.where(shown).toList();
    final label = widget.request.label;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: t.close,
          onPressed: Autofill.cancel,
        ),
        title: Text(t.autofillTitle),
        bottom: label.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(t.autofillFor(label)),
                ),
              ),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: t.search,
              ),
            ),
          ),
          if (matching.isNotEmpty) ...[
            SectionTitle(t.autofillSuggested),
            for (final i in matching) _tile(i),
          ],
          if (others.isNotEmpty) ...[
            SectionTitle(t.autofillAll),
            for (final i in others) _tile(i),
          ],
          if (matching.isEmpty && others.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(t.noMatches, textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }

  Widget _tile(Item i) => ListTile(
    leading: EntryAvatar(i.entry, size: 40),
    title: Text(i.entry.displayName),
    subtitle: i.entry.account.isEmpty ? null : Text(i.entry.account),
    trailing: const Icon(Icons.input),
    enabled: !_busy,
    onTap: () => _fill(i),
  );
}
