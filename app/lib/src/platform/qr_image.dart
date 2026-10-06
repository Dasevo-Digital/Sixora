import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

/// Reads a QR code from an image file (screenshot, photo, saved QR code).
/// Works on every platform, also without a camera. Returns null if none
/// was found.
Future<String?> decodeQrImage(Uint8List bytes) =>
    Isolate.run(() => _decode(bytes));

String? _decode(Uint8List bytes) {
  var image = img.decodeImage(bytes);
  if (image == null) return null;
  // Large photos: scale down, QR codes stay readable and it is much faster.
  if (image.width > 1600 || image.height > 1600) {
    image = img.copyResize(
      image,
      width: image.width >= image.height ? 1600 : null,
      height: image.height > image.width ? 1600 : null,
    );
  }
  final pixels = image
      .convert(numChannels: 4)
      .getBytes(order: img.ChannelOrder.abgr)
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
  return null;
}
