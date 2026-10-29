import 'dart:io';
import 'dart:isolate';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sixora_core/sixora_core.dart';
import 'package:zxing2/qrcode.dart' hide BarcodeFormat;

import '../l10n.dart';
import 'import_limits.dart';

/// Reads the QR codes in image files (screenshots, photos, saved codes).
///
/// On iOS, Android and macOS the system's barcode detection (Vision, ML Kit)
/// does the work: it reads every image format the system knows (also HEIC
/// photos) and copes with photos of screens. Elsewhere, or if it finds
/// nothing, a pure Dart decoder takes over. Returns the codes in file order,
/// without duplicates; throws [FormatException] if no image could be opened.
Future<List<String>> readQrCodes(
  List<PlatformFile> files, {
  ImportBudget? budget,
}) async {
  final selected = budget ?? ImportBudget(files.length);
  final images = <({String? path, Future<Uint8List> Function() bytes})>[];
  for (final file in files) {
    final bytes = await selected.read(file, maxBytes: maxImportImageBytes);
    images.add((path: file.path, bytes: () async => bytes));
  }
  return readQrImages(images);
}

/// [readQrCodes] for any image source: a file path (for the system
/// detection) and a way to load the bytes (for the Dart decoder).
Future<List<String>> readQrImages(
  List<({String? path, Future<Uint8List> Function() bytes})> images,
) async {
  if (images.length > maxImportFiles) {
    throw FormatException(t.importTooManyFiles(maxImportFiles));
  }
  final codes = <String>{};
  var unreadable = 0;
  var totalBytes = 0;
  for (final image in images) {
    final bytes = await image.bytes();
    totalBytes += bytes.length;
    if (bytes.length > maxImportImageBytes) {
      throw FormatException(
        t.importFileTooLarge(
          t.importImageLabel,
          maxImportImageBytes ~/ (1024 * 1024),
        ),
      );
    }
    if (totalBytes > maxImportTotalBytes) {
      throw FormatException(
        t.importSelectionTooLarge(maxImportTotalBytes ~/ (1024 * 1024)),
      );
    }
    validateEncodedQrImage(bytes);
    final native = await _readNative(image.path);
    if (native.isNotEmpty) {
      codes.addAll(native);
      continue;
    }
    final result = await Isolate.run(() => _decodeAll(bytes));
    if (result == null) {
      unreadable++;
    } else if (result.isNotEmpty) {
      codes.add(result);
    }
  }
  if (codes.isEmpty && unreadable == images.length && images.isNotEmpty) {
    throw FormatException(t.imageNotOpenable);
  }
  return codes.toList();
}

@visibleForTesting
void validateEncodedQrImage(Uint8List bytes) {
  if (bytes.length > maxImportImageBytes) {
    throw FormatException(
      t.importFileTooLarge(
        t.importImageLabel,
        maxImportImageBytes ~/ (1024 * 1024),
      ),
    );
  }
  try {
    final decoder = img.findDecoderForData(bytes);
    final info = decoder?.startDecode(bytes);
    if (info != null &&
        info.width * info.height * info.numFrames > maxImportImagePixels) {
      throw FormatException(
        t.importImageTooLarge(maxImportImagePixels ~/ 1000000),
      );
    }
  } on FormatException {
    rethrow;
  } on Object {
    // Invalid images are handled by the normal decoder below.
  }
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

/// A screen picture as BGRA pixels (Windows). Tried at full size first: on
/// a large screen the code is small.
Future<String?> readQrPixels(int width, int height, Uint8List bgra) =>
    width <= 0 ||
        height <= 0 ||
        width * height > maxImportImagePixels ||
        bgra.length != width * height * 4
    ? throw FormatException(
        t.importImageTooLarge(maxImportImagePixels ~/ 1000000),
      )
    : Isolate.run(
        () => _decodeImage(
          img.Image.fromBytes(
            width: width,
            height: height,
            bytes: bgra.buffer,
            numChannels: 4,
            order: img.ChannelOrder.bgra,
          ),
          fullSize: true,
        ),
      );

/// Pure Dart decoding of an encoded image (PNG, JPEG, …); null if no code
/// was found.
@visibleForTesting
String? decodeQrImageSync(Uint8List bytes) {
  validateEncodedQrImage(bytes);
  final image = img.decodeImage(bytes);
  return image == null ? null : _decodeImage(image);
}

String? _decodeImage(img.Image original, {bool fullSize = false}) {
  // Dense codes (Google Authenticator puts ten accounts into one) need the
  // full resolution; huge photos are faster and often better when smaller.
  final longest = original.width > original.height
      ? original.width
      : original.height;
  final sizes = <int>{
    if (longest <= 3000 || fullSize) longest,
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
        : t.listAnd(
            missing.sublist(0, missing.length - 1).join(', '),
            missing.last,
          );
    parts.add(t.codeListOfSize(list, size));
  }
  return parts.isEmpty ? null : parts.join('; ');
}
