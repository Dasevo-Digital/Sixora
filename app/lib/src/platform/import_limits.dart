import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../l10n.dart';

const maxImportFiles = 50;
const maxImportTextBytes = 10 * 1024 * 1024;
const maxImportImageBytes = 25 * 1024 * 1024;
const maxImportTotalBytes = 100 * 1024 * 1024;
const maxImportImagePixels = 40 * 1000 * 1000;

/// Enforces per-file and aggregate limits while data is streamed in. A size
/// reported by the picker is only an early check; the stream remains bounded
/// in case the file changes between selection and reading.
class ImportBudget {
  ImportBudget(int files, {this.maxTotalBytes = maxImportTotalBytes}) {
    if (files > maxImportFiles) {
      throw FormatException(t.importTooManyFiles(maxImportFiles));
    }
  }

  final int maxTotalBytes;
  int _used = 0;

  Future<Uint8List> read(PlatformFile file, {required int maxBytes}) async {
    final known = await file.length();
    if (known != null) _check(file.name, known, maxBytes);
    return readChunks(file.name, file.readAsByteStream(), maxBytes: maxBytes);
  }

  @visibleForTesting
  Future<Uint8List> readChunks(
    String name,
    Stream<List<int>> chunks, {
    required int maxBytes,
  }) async {
    final out = BytesBuilder(copy: false);
    var fileBytes = 0;
    await for (final chunk in chunks) {
      fileBytes += chunk.length;
      _check(name, fileBytes, maxBytes);
      if (_used + fileBytes > maxTotalBytes) {
        throw FormatException(t.importSelectionTooLarge(_mib(maxTotalBytes)));
      }
      out.add(chunk);
    }
    _used += fileBytes;
    return out.takeBytes();
  }

  void _check(String name, int bytes, int maxBytes) {
    if (bytes > maxBytes) {
      throw FormatException(t.importFileTooLarge(name, _mib(maxBytes)));
    }
  }

  static int _mib(int bytes) => bytes ~/ (1024 * 1024);
}
