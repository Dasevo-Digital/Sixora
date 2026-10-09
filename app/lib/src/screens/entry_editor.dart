import 'package:flutter/material.dart';
import 'package:sixora_core/sixora_core.dart';

import '../data/app_controller.dart';
import '../data/service_icons.dart';
import '../widgets/common.dart';
import '../widgets/otp_tile.dart';

/// Add (with [initial] from a QR code or empty) or edit ([item]) an entry.
class EntryEditor extends StatefulWidget {
  const EntryEditor({
    super.key,
    this.initial,
    this.item,
    this.defaultVaultId,
    this.defaultGroup,
  });
  final OtpEntry? initial;
  final Item? item;
  final String? defaultVaultId;
  final String? defaultGroup;

  @override
  State<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<EntryEditor> {
  late final _issuer = TextEditingController(text: _start.issuer);
  late final _account = TextEditingController(text: _start.account);
  late final _secret = TextEditingController(text: _start.secret);
  late final _group = TextEditingController(text: _start.group);
  late final _notes = TextEditingController(text: _start.notes);
  late final _digits = TextEditingController(text: '${_start.digits}');
  late final _period = TextEditingController(text: '${_start.period}');
  late final _counter = TextEditingController(text: '${_start.counter}');
  late OtpType _type = _start.type;
  late OtpAlgorithm _algorithm = _start.algorithm;
  late bool _favorite = _start.favorite;
  late int? _color = _start.color;
  late String? _icon = _start.icon;
  late String _vaultId;
  bool _showSecret = false;
  late bool _advanced =
      _start.type != OtpType.totp ||
      _start.algorithm != OtpAlgorithm.sha1 ||
      _start.digits != 6 ||
      _start.period != 30;
  String? _error;

  OtpEntry get _start =>
      widget.item?.entry ??
      widget.initial ??
      OtpEntry(
        issuer: '',
        account: '',
        secret: '',
        group: widget.defaultGroup ?? '',
      );

  bool get _editing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final c = AppScope.read(context);
    final writable = c.writableVaults;
    _vaultId =
        widget.item?.vaultId ??
        (writable.any((v) => v.id == widget.defaultVaultId)
            ? widget.defaultVaultId!
            : writable.first.id);
    _showSecret = widget.item == null && widget.initial == null;
    for (final t in [_issuer, _account, _secret, _digits, _period, _counter]) {
      t.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final t in [
      _issuer,
      _account,
      _secret,
      _group,
      _notes,
      _digits,
      _period,
      _counter,
    ]) {
      t.dispose();
    }
    super.dispose();
  }

  OtpEntry _build() => OtpEntry(
    issuer: _issuer.text.trim(),
    account: _account.text.trim(),
    secret: Base32.normalize(_secret.text),
    type: _type,
    algorithm: _algorithm,
    digits: int.tryParse(_digits.text) ?? 6,
    period: int.tryParse(_period.text) ?? 30,
    counter: int.tryParse(_counter.text) ?? 0,
    group: _group.text.trim(),
    favorite: _favorite,
    color: _color,
    notes: _notes.text.trim(),
    icon: _icon,
  );

  String? _preview() {
    try {
      final e = _build()..validate();
      return groupCode(e.code());
    } on FormatException {
      return null;
    }
  }

  Future<void> _pickIcon(ServiceIcons icons, OtpEntry entry) async {
    final picked = await showDialog<_IconChoice>(
      context: context,
      builder: (_) => _IconPicker(icons: icons, initial: entry.displayName),
    );
    if (picked != null) setState(() => _icon = picked.value);
  }

  Future<void> _save() async {
    final c = AppScope.read(context);
    final entry = _build();
    try {
      entry.validate();
    } on FormatException catch (e) {
      setState(() => _error = e.message);
      return;
    }
    final navigator = Navigator.of(context);
    final ok = await runBusy(context, () async {
      await c.saveEntry(entry, vaultId: _vaultId, item: widget.item);
      return true;
    });
    if (ok == true) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final theme = Theme.of(context);
    final preview = _preview();
    final entry = _build();
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Konto bearbeiten' : 'Konto hinzufügen'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Speichern')),
          const SizedBox(width: 8),
        ],
      ),
      body: FormPage(
        maxWidth: 560,
        children: [
          Card(
            child: ListTile(
              leading: EntryAvatar(entry),
              title: Text(
                entry.displayName.isEmpty ? 'Neues Konto' : entry.displayName,
              ),
              subtitle: Text(
                preview ?? 'Schlüssel eingeben …',
                style: preview == null
                    ? null
                    : theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _issuer,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Dienst',
              hintText: 'z. B. GitHub',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _account,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Konto',
              hintText: 'z. B. name@example.org',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _secret,
            obscureText: !_showSecret,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            contextMenuBuilder: _showSecret
                ? textContextMenu
                : secretContextMenu,
            decoration: InputDecoration(
              labelText: 'Geheimer Schlüssel',
              helperText: 'Base32, Leerzeichen sind egal',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PasteButton(controller: _secret),
                  IconButton(
                    tooltip: _showSecret ? 'Verbergen' : 'Anzeigen',
                    icon: Icon(
                      _showSecret
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () => setState(() => _showSecret = !_showSecret),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _group,
            decoration: InputDecoration(
              labelText: 'Gruppe (optional)',
              hintText: 'z. B. Arbeit',
              suffixIcon: c.groups.isEmpty
                  ? null
                  : PopupMenuButton<String>(
                      tooltip: 'Vorhandene Gruppe wählen',
                      icon: const Icon(Icons.arrow_drop_down),
                      onSelected: (g) => _group.text = g,
                      itemBuilder: (_) => [
                        for (final g in c.groups)
                          PopupMenuItem(value: g, child: Text(g)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          if (c.writableVaults.length > 1) ...[
            DropdownButtonFormField<String>(
              initialValue: _vaultId,
              decoration: const InputDecoration(labelText: 'Tresor'),
              items: [
                for (final v in c.writableVaults)
                  DropdownMenuItem(
                    value: v.id,
                    child: Row(
                      children: [
                        Icon(
                          v.shared ? Icons.group_outlined : Icons.lock_outline,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(v.name),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _vaultId = v ?? _vaultId),
            ),
            const SizedBox(height: 12),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Favorit'),
            subtitle: const Text('Steht oben in der Liste'),
            value: _favorite,
            onChanged: (v) => setState(() => _favorite = v),
          ),
          const SizedBox(height: 4),
          ValueListenableBuilder<ServiceIcons?>(
            valueListenable: ServiceIcons.loaded,
            builder: (context, icons, _) {
              final icon = icons?.forEntry(entry);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: EntryAvatar(entry, size: 40),
                title: const Text('Symbol'),
                subtitle: Text(switch (_icon) {
                  OtpEntry.noIcon => 'Anfangsbuchstabe',
                  null when icon != null => '${icon.title} (automatisch)',
                  null => 'Anfangsbuchstabe (kein passendes Logo gefunden)',
                  _ => icon?.title ?? 'Unbekannt',
                }),
                trailing: TextButton(
                  onPressed: icons == null
                      ? null
                      : () => _pickIcon(icons, entry),
                  child: const Text('Ändern'),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text('Farbe', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ColorDot(
                // With a logo, "Auto" is the brand colour.
                color:
                    ServiceIcons.loaded.value?.forEntry(entry)?.color ??
                    avatarColor(entry.copyWith(color: () => null)),
                selected: _color == null,
                label: 'Auto',
                onTap: () => setState(() => _color = null),
              ),
              for (final value in avatarPalette)
                _ColorDot(
                  color: Color(value),
                  selected: _color == value,
                  onTap: () => setState(() => _color = value),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Notizen (optional)'),
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            initiallyExpanded: _advanced,
            onExpansionChanged: (v) => _advanced = v,
            title: const Text('Erweitert'),
            subtitle: Text(
              '${switch (_type) {
                OtpType.totp => 'TOTP',
                OtpType.hotp => 'HOTP',
                OtpType.steam => 'Steam',
              }} · ${_algorithm.label} · ${entry.effectiveDigits} Stellen'
              '${_type == OtpType.totp ? ' · ${entry.period} s' : ''}',
            ),
            children: [
              const SizedBox(height: 8),
              SegmentedButton<OtpType>(
                segments: const [
                  ButtonSegment(
                    value: OtpType.totp,
                    label: Text('Zeitbasiert'),
                  ),
                  ButtonSegment(value: OtpType.hotp, label: Text('Zähler')),
                  ButtonSegment(value: OtpType.steam, label: Text('Steam')),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: 12),
              if (_type != OtpType.steam)
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<OtpAlgorithm>(
                        initialValue: _algorithm,
                        decoration: const InputDecoration(
                          labelText: 'Algorithmus',
                        ),
                        items: [
                          for (final a in OtpAlgorithm.values)
                            DropdownMenuItem(value: a, child: Text(a.label)),
                        ],
                        onChanged: (a) =>
                            setState(() => _algorithm = a ?? _algorithm),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _digits,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Stellen'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _type == OtpType.hotp
                          ? TextField(
                              controller: _counter,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Zähler',
                              ),
                            )
                          : TextField(
                              controller: _period,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Intervall (s)',
                              ),
                            ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 20),
          FilledButton(onPressed: _save, child: const Text('Speichern')),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
    this.label,
  });
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label ?? '',
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface
                : Colors.transparent,
            width: 3,
          ),
        ),
        child: label == null
            ? null
            : const Text(
                'A',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    ),
  );
}

/// Result of the icon picker: null = automatic, [OtpEntry.noIcon] = letter,
/// otherwise a slug.
class _IconChoice {
  const _IconChoice(this.value);
  final String? value;
}

class _IconPicker extends StatefulWidget {
  const _IconPicker({required this.icons, required this.initial});
  final ServiceIcons icons;
  final String initial;

  @override
  State<_IconPicker> createState() => _IconPickerState();
}

class _IconPickerState extends State<_IconPicker> {
  late final _query = TextEditingController(text: widget.initial);

  @override
  void initState() {
    super.initState();
    _query.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = widget.icons.search(_query.text).take(120).toList();
    return AlertDialog(
      title: const Text('Symbol wählen'),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      content: SizedBox(
        width: 460,
        height: 460,
        child: Column(
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Dienst suchen, z. B. Google',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Leeren',
                        icon: const Icon(Icons.close),
                        onPressed: _query.clear,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Automatisch'),
                  onPressed: () =>
                      Navigator.pop(context, const _IconChoice(null)),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.text_fields),
                  label: const Text('Buchstabe'),
                  onPressed: () => Navigator.pop(
                    context,
                    const _IconChoice(OtpEntry.noIcon),
                  ),
                ),
              ],
            ),
            Expanded(
              child: results.isEmpty
                  ? const Center(child: Text('Kein Logo gefunden'))
                  : GridView.extent(
                      maxCrossAxisExtent: 96,
                      childAspectRatio: 0.85,
                      children: [
                        for (final icon in results)
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () =>
                                Navigator.pop(context, _IconChoice(icon.slug)),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Column(
                                children: [
                                  ServiceIconTile(icon: icon, size: 44),
                                  const SizedBox(height: 4),
                                  Text(
                                    icon.title,
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Logos: Simple Icons ${widget.icons.version}. Die Marken gehören '
                'ihren Inhabern.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
      ],
    );
  }
}
