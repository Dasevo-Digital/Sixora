import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sixora_core/sixora_core.dart';

/// Camera scanner; returns the text of the first QR code found. Google
/// Authenticator transfers with several codes ("1 von 8") are collected
/// until all are there; then all of them are returned, one per line.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _done = false;

  /// Transfer series being collected: index → code.
  final _series = <int, String>{};
  int? _seriesId;
  int _seriesSize = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish(String text) {
    if (_done) return;
    _done = true;
    Navigator.pop(context, text);
  }

  String get _collected =>
      [for (final i in _series.keys.toList()..sort()) _series[i]!].join('\n');

  void _detected(BarcodeCapture capture) {
    if (_done) return;
    for (final code in capture.barcodes) {
      final text = code.rawValue;
      if (text == null || text.isEmpty) continue;
      final batch = GoogleMigration.batch(text);
      if (batch == null || batch.size <= 1) {
        // A single code; inside a series, other codes are ignored.
        if (_series.isEmpty) _finish(text);
        continue;
      }
      if (_seriesId != null && batch.id != _seriesId) continue;
      if (_series.containsKey(batch.index)) continue;
      HapticFeedback.mediumImpact();
      setState(() {
        _seriesId = batch.id;
        _seriesSize = batch.size;
        _series[batch.index] = text;
      });
      if (_series.length == _seriesSize) _finish(_collected);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      title: const Text('QR-Code scannen'),
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          tooltip: 'Kamera wechseln',
          icon: const Icon(Icons.cameraswitch_outlined),
          onPressed: _controller.switchCamera,
        ),
      ],
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _detected,
          errorBuilder: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                error.errorCode == MobileScannerErrorCode.permissionDenied
                    ? 'Kein Zugriff auf die Kamera. Bitte in den Systemeinstellungen erlauben.'
                    : 'Kamera nicht verfügbar: ${error.errorDetails?.message ?? error.errorCode.name}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        if (_series.isNotEmpty)
          Positioned(
            left: 24,
            right: 24,
            top: 24,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_series.length} von $_seriesSize Codes erfasst',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _series.length / _seriesSize,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'In Google Authenticator zum nächsten Code blättern.',
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: () => _finish(_collected),
                      child: const Text('Mit den erfassten weiter'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const Positioned(
          left: 24,
          right: 24,
          bottom: 48,
          child: Text(
            'Halte die Kamera auf den QR-Code, den der Dienst bei der Einrichtung '
            'der Zwei-Faktor-Anmeldung anzeigt.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );
}
