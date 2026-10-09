import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n.dart';
import '../widgets/common.dart';

/// Shows a new recovery key once. The user has to confirm that it is
/// stored safely before continuing.
class RecoveryKeyScreen extends StatefulWidget {
  const RecoveryKeyScreen({
    super.key,
    required this.recoveryKey,
    required this.username,
    this.renewed = false,
  });
  final String recoveryKey;
  final String username;
  final bool renewed;

  @override
  State<RecoveryKeyScreen> createState() => _RecoveryKeyScreenState();
}

class _RecoveryKeyScreenState extends State<RecoveryKeyScreen> {
  bool _stored = false;

  Future<void> _save() async {
    final text = t.recoveryKeyFile(
      widget.username,
      formatDate(DateTime.now()),
      widget.recoveryKey,
    );
    try {
      await FilePicker.saveFile(
        dialogTitle: t.saveRecoveryKey,
        fileName: 'Sixora-Wiederherstellung-${widget.username}.txt',
        bytes: Uint8List.fromList(utf8.encode(text)),
        mimeType: 'text/plain',
      );
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: _stored,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.recoveryKey),
          automaticallyImplyLeading: false,
        ),
        body: FormPage(
          maxWidth: 520,
          children: [
            Icon(
              Icons.health_and_safety_outlined,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              widget.renewed ? t.newRecoveryKeyShown : t.writeDownKey,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(t.recoveryKeyExplanation, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SelectableText(
                  widget.recoveryKey,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontFamilyFallback: const ['Menlo', 'Consolas', 'Courier'],
                    height: 1.6,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: Text(t.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.recoveryKey));
                    showMessage(context, t.copiedRemoveAfterPaste);
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.save_alt),
                  label: Text(t.saveAsFile),
                  onPressed: _save,
                ),
              ],
            ),
            const SizedBox(height: 20),
            CheckboxListTile(
              value: _stored,
              onChanged: (v) => setState(() => _stored = v ?? false),
              title: Text(t.keyStoredSafely),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _stored ? () => Navigator.pop(context) : null,
              child: Text(t.continueAction),
            ),
          ],
        ),
      ),
    );
  }
}
