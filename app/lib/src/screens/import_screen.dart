import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:sixora_core/sixora_core.dart';

import '../l10n.dart';
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
        (_) => _add(widget.initialText!.split('\n')),
      );
    }
  }

  @override
  void dispose() {
    _group.dispose();
    super.dispose();
  }

  static const _imageTypes = {
    'png',
    'jpg',
    'jpeg',
    'heic',
    'heif',
    'webp',
    'gif',
    'bmp',
    'tif',
    'tiff',
  };

  /// Everything read so far (QR codes, file contents). More can be added,
  /// e.g. the remaining codes of a Google Authenticator transfer.
  final _texts = <String>[];

  Future<void> _pickFiles() async {
    final files = await FilePicker.pickFiles(
      dialogTitle: t.chooseExportFilesOrImages,
    );
    if (files.isEmpty || !mounted) return;
    final images = [
      for (final f in files)
        if (_imageTypes.contains(f.extension?.toLowerCase())) f,
    ];
    final texts = <String>[];
    for (final f in files) {
      if (images.contains(f)) continue;
      texts.add(utf8.decode(await f.readAsBytes(), allowMalformed: true));
    }
    if (!mounted) return;
    if (images.isNotEmpty) {
      final codes = await runBusy(
        context,
        () => readQrCodes(images),
        message: images.length == 1
            ? t.searchingQr
            : t.searchingQrInImages(images.length),
      );
      if (codes == null || !mounted) return;
      if (codes.isEmpty && texts.isEmpty) {
        showMessage(
          context,
          images.length == 1 ? t.noQrInImage : t.noQrInImages,
        );
        return;
      }
      texts.addAll(codes);
    }
    await _add(texts);
  }

  Future<void> _add(List<String> texts) async {
    final fresh = [
      for (final text in texts.map((x) => x.trim()))
        if (text.isNotEmpty && !_texts.contains(text)) text,
    ];
    if (fresh.isEmpty) {
      if (_result != null) showMessage(context, t.nothingNew);
      return;
    }
    final before = _texts.length;
    _texts.addAll(fresh);
    if (!await _read(_texts.length == 1 ? _texts.single : _texts.join('\n'))) {
      _texts.removeRange(before, _texts.length);
    }
  }

  String? get _missing => missingTransferCodes(_texts);

  /// Parses [text]; false if nothing usable came out.
  Future<bool> _read(String text) async {
    String? password;
    while (true) {
      setState(() => _loading = true);
      try {
        final result = await Importers.read(text, password: password);
        if (!mounted) return false;
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
        return true;
      } on NeedsPasswordException {
        // ask below
      } on CryptoException catch (e) {
        if (mounted) showError(context, e);
      } catch (e) {
        if (mounted) showError(context, e);
        return false;
      } finally {
        if (mounted) setState(() => _loading = false);
      }
      if (!mounted) return false;
      password = await askText(
        context,
        title: t.backupPassword,
        label: t.password,
        password: true,
        action: t.decrypt,
      );
      if (password == null) return false;
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
      showMessage(context, t.accountsImported(entries.length));
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
      appBar: AppBar(title: Text(t.importAction)),
      body: result == null
          ? FormPage(
              children: [
                Icon(
                  Icons.file_download_outlined,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(t.supported, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(t.supportedFormats),
                const SizedBox(height: 12),
                Text(t.microsoftNoExport, style: theme.textTheme.bodySmall),
                const SizedBox(height: 24),
                if (_loading) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 16),
                ],
                FilledButton.icon(
                  onPressed: _loading ? null : _pickFiles,
                  icon: const Icon(Icons.folder_open),
                  label: Text(t.chooseFilesOrImages),
                ),
              ],
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${t.accountsFound(result.entries.length, result.source)}'
                    '${result.skipped > 0 ? t.notReadable(result.skipped) : ''}. '
                    '${t.existingDeselected}',
                  ),
                ),
                if (_missing case final missing?)
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    color: theme.colorScheme.tertiaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.qr_code_2),
                      title: Text(t.missingTransferCodes(missing)),
                      subtitle: Text(t.missingTransferCodesHint),
                    ),
                  ),
                if (!_running)
                  TextButton.icon(
                    onPressed: _loading ? null : _pickFiles,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(t.addMoreFiles),
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
                                t.alreadyPresent,
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
                                  decoration: InputDecoration(
                                    labelText: t.vault,
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
                                decoration: InputDecoration(
                                  labelText: t.groupForUngrouped,
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
                          Text(t.progressOf(_done, _selected.length)),
                        ] else
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _selected.isEmpty || _vaultId == null
                                  ? null
                                  : _import,
                              child: Text(t.importAccounts(_selected.length)),
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
