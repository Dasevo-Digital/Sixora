import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';
import 'package:sixora/src/platform/qr_image.dart';
import 'package:sixora_core/sixora_core.dart';

/// A screenshot-like image: [data] as QR code on a white area in the
/// middle of a phone-sized canvas.
Uint8List screenshot(
  String data, {
  int width = 1179,
  int height = 2556,
  double qrShare = 0.7,
  bool jpeg = false,
  bool dark = false,
}) {
  final code = QrImage(
    QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M),
  );
  final modules = code.moduleCount;
  final module = (width * qrShare / (modules + 8)).floor();
  final size = module * (modules + 8);
  final canvas = img.Image(width: width, height: height, numChannels: 4)
    ..clear(dark ? img.ColorRgb8(18, 18, 18) : img.ColorRgb8(245, 245, 245));
  final left = (width - size) ~/ 2;
  final top = (height - size) ~/ 2;
  img.fillRect(
    canvas,
    x1: left,
    y1: top,
    x2: left + size,
    y2: top + size,
    color: img.ColorRgb8(255, 255, 255),
  );
  for (var y = 0; y < modules; y++) {
    for (var x = 0; x < modules; x++) {
      if (!code.isDark(y, x)) continue;
      final px = left + (x + 4) * module;
      final py = top + (y + 4) * module;
      img.fillRect(
        canvas,
        x1: px,
        y1: py,
        x2: px + module - 1,
        y2: py + module - 1,
        color: img.ColorRgb8(0, 0, 0),
      );
    }
  }
  return jpeg ? img.encodeJpg(canvas, quality: 75) : img.encodePng(canvas);
}

List<OtpEntry> accounts(int n) => [
  for (var i = 0; i < n; i++)
    OtpEntry(
      issuer: 'Dienst Nummer $i',
      account: 'vorname.nachname$i@example.org',
      secret: Base32.encode(List.generate(20, (j) => (i * 31 + j * 7) & 255)),
    ),
];

void main() {
  test('Google Authenticator transfer codes from a phone screenshot', () {
    // Google Authenticator puts up to 10 accounts into one code.
    final uri = GoogleMigration.build(accounts(10), batchSize: 10).single;
    for (final (name, bytes) in [
      ('png', screenshot(uri)),
      ('jpeg', screenshot(uri, jpeg: true)),
      ('dark mode', screenshot(uri, dark: true)),
      ('small', screenshot(uri, qrShare: 0.45)),
    ]) {
      expect(decodeQrImageSync(bytes), uri, reason: name);
    }
  });

  test(
    'a transfer series of eight codes, read from eight screenshots',
    () async {
      final entries = accounts(75);
      final uris = GoogleMigration.build(entries, batchSize: 10);
      expect(uris, hasLength(8));
      final read = [
        for (final uri in uris) decodeQrImageSync(screenshot(uri))!,
      ];
      expect(read, uris);

      expect(missingTransferCodes(read), isNull);
      expect(
        missingTransferCodes([read[0], read[3], read[7]]),
        '2, 3, 5, 6 und 7 von 8',
      );
      expect(missingTransferCodes(read.sublist(1)), '1 von 8');

      // All codes together, one per line, as the app hands them to the import.
      final result = await Importers.read(read.join('\n'));
      expect(result.entries, hasLength(75));
      expect(result.entries.first.issuer, 'Dienst Nummer 0');
    },
  );

  test('a single otpauth code', () {
    const uri =
        'otpauth://totp/GitHub:me?secret=JBSWY3DPEHPK3PXP&issuer=GitHub';
    expect(decodeQrImageSync(screenshot(uri)), uri);
  });
}
