import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sixora_core/sixora_core.dart';

/// Shows QR codes to move accounts into another authenticator app:
/// a single account as otpauth link, several as Google Authenticator
/// transfer codes.
class EntryQrScreen extends StatefulWidget {
  const EntryQrScreen({super.key, required this.entries});
  final List<OtpEntry> entries;

  @override
  State<EntryQrScreen> createState() => _EntryQrScreenState();
}

class _EntryQrScreenState extends State<EntryQrScreen> {
  late final List<String> _codes;
  late final int _skipped;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    if (widget.entries.length == 1) {
      _codes = [OtpAuthUri.build(widget.entries.single)];
      _skipped = 0;
    } else {
      _codes = GoogleMigration.build(widget.entries);
      _skipped = widget.entries
          .where((e) => !GoogleMigration.canExport(e))
          .length;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final single = widget.entries.length == 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          single ? widget.entries.single.displayName : 'Konten übertragen',
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                if (_codes.isEmpty)
                  const Text('Keines der Konten lässt sich so übertragen.')
                else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: _codes[_page],
                      size: 300,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_codes.length > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _page > 0
                              ? () => setState(() => _page--)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('Code ${_page + 1} von ${_codes.length}'),
                        IconButton(
                          onPressed: _page < _codes.length - 1
                              ? () => setState(() => _page++)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  Text(
                    single
                        ? 'In der anderen App „QR-Code scannen“ wählen.'
                        : 'In Google Authenticator „Konten importieren“ wählen und die '
                              'Codes nacheinander scannen. Andere Apps wie Aegis lesen '
                              'dieses Format ebenfalls.',
                    textAlign: TextAlign.center,
                  ),
                  if (_skipped > 0) ...[
                    const SizedBox(height: 12),
                    Text(
                      '$_skipped Konten (Steam oder ungewöhnliche Intervalle) sind nicht '
                      'enthalten – bitte einzeln übertragen.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
