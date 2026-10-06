import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_controller.dart';

/// Gives the [AppController] to the widget tree.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

/// One tick per second, aligned to the full second, for all countdowns.
class Ticker extends ValueNotifier<DateTime> {
  Ticker() : super(DateTime.now()) {
    _schedule();
  }
  Timer? _timer;

  void _schedule() {
    final now = DateTime.now();
    _timer = Timer(Duration(milliseconds: 1000 - now.millisecond + 5), () {
      value = DateTime.now();
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
}

void showError(BuildContext context, Object error) {
  if (error is UserError && error.message == 'Abgemeldet') return;
  showMessage(context, errorText(error));
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String action = 'OK',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                )
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Asks for a text, e.g. a name or the master password.
Future<String?> askText(
  BuildContext context, {
  required String title,
  String label = '',
  String initial = '',
  String action = 'OK',
  bool password = false,
  String? message,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message != null) ...[Text(message), const SizedBox(height: 12)],
          TextField(
            controller: controller,
            autofocus: true,
            obscureText: password,
            contextMenuBuilder: password ? secretContextMenu : null,
            decoration: InputDecoration(labelText: label),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(action),
        ),
      ],
    ),
  );
}

/// Runs [action] with a modal progress indicator and reports errors.
Future<T?> runBusy<T>(
  BuildContext context,
  Future<T> Function() action, {
  String? message,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  var open = true;
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  if (message != null) ...[
                    const SizedBox(height: 16),
                    Text(message),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(() => open = false),
  );
  try {
    return await action();
  } catch (e) {
    if (open) navigator.pop();
    open = false;
    if (context.mounted) showError(context, e);
    return null;
  } finally {
    if (open) navigator.pop();
  }
}

/// Context menu for hidden fields (passwords, secrets). Flutter offers no
/// "Einfügen" there on its own, so pasting from a password manager would
/// only work with the keyboard. Copy and cut stay unavailable.
///
///     TextField(obscureText: true, contextMenuBuilder: secretContextMenu)
Widget secretContextMenu(BuildContext context, EditableTextState field) {
  final value = field.textEditingValue;
  return AdaptiveTextSelectionToolbar.buttonItems(
    anchors: field.contextMenuAnchors,
    buttonItems: [
      ContextMenuButtonItem(
        type: ContextMenuButtonType.paste,
        label: 'Einfügen',
        onPressed: () => field.pasteText(SelectionChangedCause.toolbar),
      ),
      if (value.text.isNotEmpty &&
          value.selection.end - value.selection.start < value.text.length)
        ContextMenuButtonItem(
          type: ContextMenuButtonType.selectAll,
          label: 'Alles auswählen',
          onPressed: () => field.selectAll(SelectionChangedCause.toolbar),
        ),
    ],
  );
}

/// Button that replaces the field's text with the clipboard (trimmed).
class PasteButton extends StatelessWidget {
  const PasteButton({super.key, required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Einfügen',
    icon: const Icon(Icons.content_paste),
    onPressed: () async {
      final text = (await Clipboard.getData(
        Clipboard.kTextPlain,
      ))?.text?.trim();
      if (text == null || text.isEmpty) {
        if (context.mounted) {
          showMessage(context, 'Die Zwischenablage ist leer');
        }
        return;
      }
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    },
  );
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Master-Passwort',
    this.autofocus = false,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
    this.helper,
  });
  final TextEditingController controller;
  final String label;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String> autofillHints;
  final String? helper;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) => TextField(
    controller: widget.controller,
    autofocus: widget.autofocus,
    obscureText: !_visible,
    autocorrect: false,
    enableSuggestions: false,
    autofillHints: widget.autofillHints,
    onSubmitted: widget.onSubmitted,
    contextMenuBuilder: secretContextMenu,
    decoration: InputDecoration(
      labelText: widget.label,
      helperText: widget.helper,
      helperMaxLines: 3,
      prefixIcon: const Icon(Icons.key_outlined),
      suffixIcon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PasteButton(controller: widget.controller),
          IconButton(
            tooltip: _visible ? 'Verbergen' : 'Anzeigen',
            icon: Icon(
              _visible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            onPressed: () => setState(() => _visible = !_visible),
          ),
        ],
      ),
    ),
  );
}

/// Rough strength estimate for the master password hint.
({double score, String label}) passwordStrength(String pw) {
  if (pw.isEmpty) return (score: 0, label: '');
  var pool = 0;
  if (RegExp('[a-z]').hasMatch(pw)) pool += 26;
  if (RegExp('[A-Z]').hasMatch(pw)) pool += 26;
  if (RegExp('[0-9]').hasMatch(pw)) pool += 10;
  if (RegExp('[^a-zA-Z0-9]').hasMatch(pw)) pool += 33;
  final unique = pw.split('').toSet().length;
  final bits =
      unique * (pool == 0 ? 1 : (pool.bitLength - 1)) + (pw.length - unique);
  if (bits < 40) return (score: 0.25, label: 'Schwach');
  if (bits < 60) return (score: 0.5, label: 'Mittel');
  if (bits < 80) return (score: 0.75, label: 'Gut');
  return (score: 1, label: 'Sehr gut');
}

/// Copies [text] and, if wanted, clears the clipboard after 30 s – but only
/// if it still holds the same text.
Future<void> copySecret(
  BuildContext context,
  String text, {
  String? what,
}) async {
  final c = AppScope.read(context);
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    showMessage(
      context,
      '${what ?? 'Code'} kopiert${c.settings.clearClipboard ? ' – wird nach 30 s aus der Zwischenablage entfernt' : ''}',
    );
  }
  if (c.settings.clearClipboard) {
    Timer(const Duration(seconds: 30), () async {
      final current = await Clipboard.getData(Clipboard.kTextPlain);
      if (current?.text == text) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }
}

/// Centered column with a maximum width, for forms on large screens.
class FormPage extends StatelessWidget {
  const FormPage({super.key, required this.children, this.maxWidth = 460});
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

String formatDate(DateTime? d) {
  if (d == null) return '–';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
}
