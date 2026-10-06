import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:sixora_core/sixora_core.dart';

import '../platform/qr_image.dart';
import '../widgets/common.dart';
import '../widgets/otp_tile.dart';

/// Import from files or transfer codes of other authenticator apps.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, this.initialText});
  final String? initialText;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  ImportResult? _result;
  final _selected = <int>{};
  String? _vaultId;
  final _group = TextEditingController();
  int _done = 0;
  bool _running = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _read(widget.initialText!),
      );
    }
  }

  @override
  void dispose() {
    _group.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Export-Datei auswählen',
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    final ext = file.extension?.toLowerCase();
    if (const {'png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'}.contains(ext)) {
      final text = await runBusy(
        context,
        () => decodeQrImage(bytes),
        message: 'QR-Code wird gesucht …',
      );
      if (!mounted) return;
      if (text == null) {
        showMessage(context, 'Kein QR-Code im Bild gefunden');
        return;
      }
      await _read(text);
    } else {
      await _read(utf8.decode(bytes, allowMalformed: true));
    }
  }

  Future<void> _read(String text) async {
    String? password;
    while (true) {
      setState(() => _loading = true);
      try {
        final result = await Importers.read(text, password: password);
        if (!mounted) return;
        final c = AppScope.read(context);
        setState(() {
          _result = result;
          _selected
            ..clear()
            ..addAll([
              for (var i = 0; i < result.entries.length; i++)
                if (!c.isDuplicate(result.entries[i])) i,
            ]);
          _vaultId ??= c.writableVaults.firstOrNull?.id;
        });
        return;
      } on NeedsPasswordException {
        // ask below
      } on CryptoException catch (e) {
        if (mounted) showError(context, e);
      } catch (e) {
        if (mounted) showError(context, e);
        return;
      } finally {
        if (mounted) setState(() => _loading = false);
      }
      if (!mounted) return;
      password = await askText(
        context,
        title: 'Passwort der Sicherung',
        label: 'Passwort',
        password: true,
        action: 'Entschlüsseln',
      );
      if (password == null) return;
    }
  }

  Future<void> _import() async {
    final c = AppScope.read(context);
    final result = _result!;
    final group = _group.text.trim();
    final entries = [
      for (final i in _selected.toList()..sort())
        group.isEmpty || result.entries[i].group.isNotEmpty
            ? result.entries[i]
            : result.entries[i].copyWith(group: group),
    ];
    setState(() {
      _running = true;
      _done = 0;
    });
    try {
      await c.importEntries(
        entries,
        vaultId: _vaultId!,
        progress: (n) => setState(() => _done = n),
      );
      if (!mounted) return;
      showMessage(context, '${entries.length} Konten importiert');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final theme = Theme.of(context);
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Importieren')),
      body: result == null
          ? FormPage(
              children: [
                Icon(
                  Icons.file_download_outlined,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text('Unterstützt werden:', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text(
                  '• Google Authenticator: „Konten übertragen“ → QR-Code scannen oder Screenshot wählen\n'
                  '• Aegis: Export als unverschlüsseltes JSON\n'
                  '• 2FAuth: Export als JSON\n'
                  '• Sixora: verschlüsselte Sicherung\n'
                  '• Alles mit otpauth://-Links, z. B. Exporte von Bitwarden, Ente Auth, andOTP oder Textdateien',
                ),
                const SizedBox(height: 12),
                Text(
                  'Microsoft Authenticator bietet keinen Export. Dort jedes Konto beim '
                  'Dienst neu einrichten oder den QR-Code erneut anzeigen lassen.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                if (_loading) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 16),
                ],
                FilledButton.icon(
                  onPressed: _loading ? null : _pickFile,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Datei oder Bild auswählen'),
                ),
              ],
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${result.entries.length} Konten aus ${result.source} gefunden'
                    '${result.skipped > 0 ? ', ${result.skipped} nicht lesbar' : ''}. '
                    'Bereits vorhandene sind abgewählt.',
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (var i = 0; i < result.entries.length; i++)
                        CheckboxListTile(
                          value: _selected.contains(i),
                          onChanged: _running
                              ? null
                              : (v) => setState(
                                  () => v == true
                                      ? _selected.add(i)
                                      : _selected.remove(i),
                                ),
                          secondary: EntryAvatar(result.entries[i], size: 36),
                          title: Text(result.entries[i].displayName),
                          subtitle: Text(
                            [
                              result.entries[i].account,
                              if (result.entries[i].group.isNotEmpty)
                                result.entries[i].group,
                              if (c.isDuplicate(result.entries[i]))
                                'schon vorhanden',
                            ].where((s) => s.isNotEmpty).join(' · '),
                          ),
                        ),
                    ],
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            if (c.writableVaults.length > 1) ...[
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _vaultId,
                                  decoration: const InputDecoration(
                                    labelText: 'Tresor',
                                  ),
                                  items: [
                                    for (final v in c.writableVaults)
                                      DropdownMenuItem(
                                        value: v.id,
                                        child: Text(v.name),
                                      ),
                                  ],
                                  onChanged: _running
                                      ? null
                                      : (v) => setState(() => _vaultId = v),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: TextField(
                                controller: _group,
                                enabled: !_running,
                                decoration: const InputDecoration(
                                  labelText: 'Gruppe für Konten ohne Gruppe',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_running) ...[
                          LinearProgressIndicator(
                            value: _selected.isEmpty
                                ? null
                                : _done / _selected.length,
                          ),
                          const SizedBox(height: 8),
                          Text('$_done von ${_selected.length}'),
                        ] else
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _selected.isEmpty || _vaultId == null
                                  ? null
                                  : _import,
                              child: Text(
                                '${_selected.length} Konten importieren',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
