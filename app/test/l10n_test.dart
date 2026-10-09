import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:sixora/src/l10n.dart';

/// Every language has every text, with the same placeholders.
void main() {
  Map<String, Object?> arb(String lang) =>
      (jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map)
          .cast();
  Set<String> keys(Map<String, Object?> a) =>
      a.keys.where((k) => !k.startsWith('@')).toSet();
  Set<String> placeholders(Object? text) => {
    // {name} and {name, plural, …}, without the inner plural branches.
    for (final m in RegExp(r'\{(\w+)(?:,|\})').allMatches('$text')) m[1]!,
  }..removeAll(['one', 'other', 'zero', 'few', 'many', 'two']);

  final de = arb('de');
  for (final lang in ['en', 'es']) {
    test('$lang has the same texts and placeholders as de', () {
      final other = arb(lang);
      expect(keys(other), keys(de));
      for (final k in keys(de)) {
        expect(placeholders(other[k]), placeholders(de[k]), reason: k);
      }
    });
  }

  test('the system language decides, English when none fits', () {
    expect(resolveLocale('es'), const Locale('es'));
    expect(appLanguages, ['de', 'en', 'es']);
    useLocale(const Locale('es'));
    expect(t.cancel, 'Cancelar');
    expect(t.secondsLeft(1), 'queda 1 segundo');
    useLocale(const Locale('en'));
    expect(t.vaultCount(2), '2 vaults');
    useLocale(const Locale('de'));
    expect(t.accountsImported(1), '1 Konto importiert');
  });
}
