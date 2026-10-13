import 'package:flutter/material.dart';

/// App UI languages actually shipped for offline / in-app use.
/// Keep dropdowns and MaterialApp aligned to this list only.
class AppLocales {
  AppLocales._();

  static const Locale en = Locale('en');
  static const Locale hi = Locale('hi');
  static const Locale ta = Locale('ta');
  static const Locale te = Locale('te');

  static const List<Locale> supported = [en, hi, ta, te];

  static const Locale fallback = en;

  /// For human-readable language pickers.
  static const List<Map<String, dynamic>> dropdownItems = [
    {'name': 'English', 'locale': en},
    {'name': 'हिन्दी', 'locale': hi},
    {'name': 'தமிழ்', 'locale': ta},
    {'name': 'తెలుగు', 'locale': te},
  ];

  static bool isSupported(Locale locale) =>
      supported.any((l) => l.languageCode == locale.languageCode);

  static Locale resolve(Locale? locale) {
    if (locale == null) return fallback;
    for (final l in supported) {
      if (l.languageCode == locale.languageCode) return l;
    }
    return fallback;
  }

  static Locale fromCode(String? code) {
    if (code == null || code.isEmpty) return fallback;
    return resolve(Locale(code));
  }

  static String labelFor(Locale locale) {
    switch (locale.languageCode) {
      case 'hi':
        return 'हिन्दी';
      case 'ta':
        return 'தமிழ்';
      case 'te':
        return 'తెలుగు';
      case 'en':
      default:
        return 'English';
    }
  }
}
