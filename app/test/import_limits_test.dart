import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sixora/src/platform/import_limits.dart';

void main() {
  test('too many files are rejected before reading', () {
    expect(() => ImportBudget(maxImportFiles + 1), throwsFormatException);
  });

  test('a single file cannot exceed its limit', () async {
    final budget = ImportBudget(1, maxTotalBytes: 100);
    await expectLater(
      budget.readChunks('large.txt', Stream.value(Uint8List(11)), maxBytes: 10),
      throwsFormatException,
    );
  });

  test('several files cannot exceed the aggregate limit', () async {
    final budget = ImportBudget(2, maxTotalBytes: 10);
    await budget.readChunks(
      'first.txt',
      Stream.value(Uint8List(6)),
      maxBytes: 10,
    );
    await expectLater(
      budget.readChunks('second.txt', Stream.value(Uint8List(5)), maxBytes: 10),
      throwsFormatException,
    );
  });
}
