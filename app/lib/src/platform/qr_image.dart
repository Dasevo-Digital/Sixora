import 'dart:io';
import 'dart:isolate';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sixora_core/sixora_core.dart';
import 'package:zxing2/qrcode.dart' hide BarcodeFormat;

/// Reads the QR codes in image files (screenshots, photos, saved codes).
///
/// On iOS, Android and macOS the system's barcode detection (Vision, ML Kit)
/// does the work: it reads every image format the system knows (also HEIC
/// photos) and copes with photos of screens. Elsewhere, or if it finds
/// nothing, a pure Dart decoder takes over. Returns the codes in file order,
/// without duplicates; throws [FormatException] if no image could be opened.
Future<List<String>> readQrCodes(List<PlatformFile> files) =>
    readQrImages([for (final f in files) (path: f.path, bytes: f.readAsBytes)]);

/// [readQrCodes] for any image source: a file path (for the system
/// detection) and a way to load the bytes (for the Dart decoder).
Future<List<String>> readQrImages(
  List<({String? path, Future<Uint8List> Function() bytes})> images,
) async {
  final codes = <String>{};
  var unreadable = 0;
  for (final image in images) {
    final native = await _readNative(image.path);
    if (native.isNotEmpty) {
      codes.addAll(native);
      continue;
    }
    final bytes = await image.bytes();
    final result = await Isolate.run(() => _decodeAll(bytes));
    if (result == null) {
      unreadable++;
    } else if (result.isNotEmpty) {
      codes.add(result);
    }
  }
  if (codes.isEmpty && unreadable == images.length && images.isNotEmpty) {
    throw const FormatException(
      'Das Bild lässt sich nicht öffnen. Bitte als PNG oder JPEG speichern '
      '(z. B. einen Screenshot statt eines HEIC-Fotos).',
    );
  }
  return codes.toList();
}

@visibleForTesting
Future<List<String>> readQrNative(String? path) => _readNative(path);

Future<List<String>> _readNative(String? path) async {
  if (path == null ||
      !(Platform.isIOS || Platform.isAndroid || Platform.isMacOS)) {
    return const [];
  }
  final controller = MobileScannerController(autoStart: false);
  try {
    final capture = await controller.analyzeImage(
      path,
      formats: const [BarcodeFormat.qrCode],
    );
    return [
      for (final b in capture?.barcodes ?? const <Barcode>[])
        if (b.rawValue case final v? when v.isNotEmpty) v,
    ];
  } on Object catch (e) {
    debugPrint('Systemerkennung nicht verfügbar: $e');
    return const [];
  } finally {
    await controller.dispose();
  }
}

/// Text of the QR code, '' if none was found, null if the image could not
/// be decoded at all.
String? _decodeAll(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) return null;
  return _decodeImage(image) ?? '';
}

/// Pure Dart decoding of an encoded image (PNG, JPEG, …); null if no code
/// was found.
@visibleForTesting
String? decodeQrImageSync(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  return image == null ? null : _decodeImage(image);
}

String? _decodeImage(img.Image original) {
  // Dense codes (Google Authenticator puts ten accounts into one) need the
  // full resolution; huge photos are faster and often better when smaller.
  final longest = original.width > original.height
      ? original.width
      : original.height;
  final sizes = <int>{
    if (longest <= 3000) longest,
    for (final s in const [2000, 1400, 900])
      if (s < longest) s,
  };
  for (final size in sizes) {
    final image = size == longest
        ? original
        : img.copyResize(
            original,
            width: original.width >= original.height ? size : null,
            height: original.height > original.width ? size : null,
            interpolation: img.Interpolation.average,
          );
    // ARGB as zxing expects it: bytes b, g, r, a are 0xAARRGGBB on
    // little-endian machines.
    final pixels = image
        .convert(numChannels: 4)
        .getBytes(order: img.ChannelOrder.bgra)
        .buffer
        .asInt32List();
    final source = RGBLuminanceSource(image.width, image.height, pixels);
    for (final bitmap in [
      BinaryBitmap(HybridBinarizer(source)),
      BinaryBitmap(GlobalHistogramBinarizer(source)),
      BinaryBitmap(HybridBinarizer(source.invert())),
    ]) {
      try {
        return QRCodeReader()
            .decode(bitmap, hints: DecodeHints()..put(DecodeHintType.tryHarder))
            .text;
      } on ReaderException {
        continue;
      }
    }
  }
  return null;
}

/// Which codes of Google Authenticator transfer series are still missing,
/// e.g. "2, 5 und 7 von 8"; null if every series is complete.
String? missingTransferCodes(Iterable<String> codes) {
  final seen = <int, Set<int>>{};
  final sizes = <int, int>{};
  for (final code in codes) {
    final b = GoogleMigration.batch(code);
    if (b == null) continue;
    seen.putIfAbsent(b.id, () => {}).add(b.index);
    sizes[b.id] = b.size;
  }
  final parts = <String>[];
  for (final id in seen.keys) {
    final size = sizes[id]!;
    final missing = [
      for (var i = 0; i < size; i++)
        if (!seen[id]!.contains(i)) '${i + 1}',
    ];
    if (missing.isEmpty) continue;
    final list = missing.length == 1
        ? missing.single
        : '${missing.sublist(0, missing.length - 1).join(', ')} und ${missing.last}';
    parts.add('$list von $size');
  }
  return parts.isEmpty ? null : parts.join('; ');
}
