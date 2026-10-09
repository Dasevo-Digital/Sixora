import 'dart:ui';

import '../l10n/app_localizations.dart';

export '../l10n/app_localizations.dart';

/// The app's texts in the current language. A global, so that code outside
/// the widget tree (controller, menu bar, error messages) can use them too;
/// [SixoraApp] sets it whenever the language changes.
AppLocalizations t = lookupAppLocalizations(const Locale('de'));

/// Languages the app speaks, in the order of the settings menu.
const appLanguages = ['de', 'en', 'es'];

/// [setting] is `system` or one of [appLanguages]. The system's preferred
/// languages decide otherwise; English when none of them is supported.
Locale resolveLocale(String setting) {
  if (appLanguages.contains(setting)) return Locale(setting);
  for (final l in PlatformDispatcher.instance.locales) {
    if (appLanguages.contains(l.languageCode)) return Locale(l.languageCode);
  }
  return const Locale('en');
}

void useLocale(Locale locale) => t = lookupAppLocalizations(locale);
