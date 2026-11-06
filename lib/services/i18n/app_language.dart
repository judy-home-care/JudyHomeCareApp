import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'translations/fr.dart';
import 'translations/de.dart';
import 'translations/nl.dart';
import 'translations/es.dart';

/// App-wide language selection and translation lookup.
///
/// Translations are keyed by the exact English source string, so English is
/// always the fallback: a string with no entry in the active dictionary is
/// shown as-is. The selected language is persisted and applied on startup.
class AppLanguage {
  AppLanguage._();

  static const String _prefKey = 'app_language_code';

  static const List<Map<String, String>> supported = [
    {'code': 'en', 'name': 'English', 'native': 'English', 'flag': '🇬🇧'},
    {'code': 'fr', 'name': 'French', 'native': 'Français', 'flag': '🇫🇷'},
    {'code': 'de', 'name': 'German', 'native': 'Deutsch', 'flag': '🇩🇪'},
    {'code': 'nl', 'name': 'Dutch', 'native': 'Nederlands', 'flag': '🇳🇱'},
    {'code': 'es', 'name': 'Spanish', 'native': 'Español', 'flag': '🇪🇸'},
  ];

  /// Current language code. Listen to this to react to language changes.
  static final ValueNotifier<String> current = ValueNotifier<String>('en');

  static Map<String, String> _active = const {};

  static bool isSupported(String code) =>
      supported.any((l) => l['code'] == code);

  static Map<String, String> languageInfo(String code) => supported.firstWhere(
        (l) => l['code'] == code,
        orElse: () => supported.first,
      );

  /// Load the persisted language. Called once from main() before runApp.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefKey) ?? 'en';
      _active = _dictionaryFor(code);
      current.value = isSupported(code) ? code : 'en';
    } catch (_) {
      // Fall back to English; never block startup over a language preference.
    }
  }

  /// Switch language, apply immediately and persist.
  static Future<void> set(String code) async {
    if (!isSupported(code)) return;
    _active = _dictionaryFor(code);
    current.value = code;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, code);
    } catch (_) {}
  }

  static Map<String, String> _dictionaryFor(String code) {
    switch (code) {
      case 'fr':
        return translationsFr;
      case 'de':
        return translationsDe;
      case 'nl':
        return translationsNl;
      case 'es':
        return translationsEs;
      default:
        return const {};
    }
  }

  /// Translate an English source string into the active language.
  static String tr(String text) => _active[text] ?? text;
}

/// Shorthand: 'Save Note'.tr
extension AppLanguageTr on String {
  String get tr => AppLanguage.tr(this);
}
