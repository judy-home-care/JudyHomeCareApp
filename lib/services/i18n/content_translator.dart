import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../utils/api_client.dart';
import 'app_language.dart';

/// Machine translation of user-written content (care plans, nurse/therapist
/// notes, incident reports, messages...) into the app language, so clients
/// who don't read English can follow what staff wrote in English.
///
/// Translation is display-only: the original text is never modified, so
/// editing a note always edits what the author wrote.
///
/// Texts requested while a frame builds are batched into one call to
/// `POST /api/mobile/translate` (the server caches every translation).
/// Results are kept in memory only, since they contain patient information.
class ContentTranslator extends ChangeNotifier {
  ContentTranslator._();
  static final ContentTranslator instance = ContentTranslator._();

  static const int _maxLength = 5000;
  static const int _batchSize = 40;
  static const Duration _pendingRetryDelay = Duration(milliseconds: 1500);
  static const Duration _batchDelay = Duration(milliseconds: 60);
  static const Duration _retryAfter = Duration(minutes: 2);

  final Map<String, Map<String, String>> _cache = {};
  final Map<String, Set<String>> _pending = {};
  final Set<String> _inFlight = {};
  final Map<String, DateTime> _failedAt = {};
  DateTime? _disabledAt;
  Timer? _timer;

  static final RegExp _letterRun = RegExp(r'[A-Za-zÀ-ÿ]{3,}');
  static final RegExp _email = RegExp(r'^\S+@\S+\.\S+$');
  static final RegExp _url = RegExp(r'^(https?://|www\.)\S+$', caseSensitive: false);
  static final RegExp _digit = RegExp(r'\d');

  /// Whether [text] is worth sending for translation (skips numbers, emails,
  /// links, amounts, codes and other values that read the same in any language).
  static bool shouldTranslate(String text) {
    final t = text.trim();
    if (t.length < 2 || t.length > _maxLength) return false;
    if (!_letterRun.hasMatch(t)) return false;
    if (_email.hasMatch(t) || _url.hasMatch(t)) return false;
    final digits = _digit.allMatches(t).length;
    if (digits * 100 / t.length >= 30) return false;
    return true;
  }

  /// The translation of [text] into [lang], or null if it is not available
  /// yet (a fetch is scheduled; listeners are notified when it arrives).
  String? get(String text, String lang) {
    final hit = _cache[lang]?[text];
    if (hit != null) return hit;
    _schedule(text, lang);
    return null;
  }

  void _schedule(String text, String lang) {
    if (_disabledAt != null &&
        DateTime.now().difference(_disabledAt!) < const Duration(minutes: 10)) {
      return;
    }
    final key = '$lang\u0000$text';
    if (_inFlight.contains(key)) return;
    final failed = _failedAt[key];
    if (failed != null && DateTime.now().difference(failed) < _retryAfter) return;

    _pending.putIfAbsent(lang, () => <String>{}).add(text);
    _timer ??= Timer(_batchDelay, _flush);
  }

  Future<void> _flush() async {
    _timer = null;
    final work = Map<String, Set<String>>.from(_pending);
    _pending.clear();

    for (final entry in work.entries) {
      final lang = entry.key;
      final texts = entry.value.toList();
      for (var i = 0; i < texts.length; i += _batchSize) {
        final chunk = texts.sublist(
            i, i + _batchSize > texts.length ? texts.length : i + _batchSize);
        unawaited(_fetch(lang, chunk));
      }
    }
  }

  Future<void> _fetch(String lang, List<String> texts) async {
    final keys = texts.map((t) => '$lang\u0000$t').toList();
    _inFlight.addAll(keys);
    try {
      final response = await ApiClient().post(
        '/api/mobile/translate',
        body: {'target': lang, 'texts': texts},
        requiresAuth: true,
      );

      if (response['enabled'] == false) {
        _disabledAt = DateTime.now();
      }

      final translations = response['translations'];
      final bucket = _cache.putIfAbsent(lang, () => <String, String>{});
      var changed = false;
      if (translations is Map) {
        translations.forEach((source, translated) {
          if (source is String && translated is String && translated.isNotEmpty) {
            bucket[source] = translated;
            changed = true;
          }
        });
      }
      // The server stops early on slow providers and reports the rest as
      // pending; ask for those again shortly instead of treating them as failed.
      final pending = response['pending'] is List
          ? (response['pending'] as List).whereType<String>().toSet()
          : const <String>{};
      final now = DateTime.now();
      for (final t in texts) {
        if (!bucket.containsKey(t) && !pending.contains(t)) {
          _failedAt['$lang\u0000$t'] = now;
        }
      }
      if (changed) notifyListeners();
      if (pending.isNotEmpty) {
        Future.delayed(_pendingRetryDelay, () {
          for (final t in pending) {
            _schedule(t, lang);
          }
        });
      }
    } catch (e) {
      debugPrint('⚠️ [ContentTranslator] translate failed: $e');
      final now = DateTime.now();
      for (final k in keys) {
        _failedAt[k] = now;
      }
    } finally {
      _inFlight.removeAll(keys);
    }
  }

  /// Forget everything (e.g. on logout).
  void clear() {
    _cache.clear();
    _pending.clear();
    _failedAt.clear();
    _disabledAt = null;
  }
}

/// Resolve [text] for display in the active language: built-in dictionary
/// first, then machine translation when available, otherwise the original.
String translateContent(String text) {
  final lang = AppLanguage.current.value;
  if (lang == 'en' || text.isEmpty) return text;
  final dict = AppLanguage.lookup(text);
  if (dict != null) return dict;
  if (!ContentTranslator.shouldTranslate(text)) return text;
  return ContentTranslator.instance.get(text, lang) ?? text;
}
