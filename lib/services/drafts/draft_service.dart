import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Local drafts for clinical text the nurse/therapist is typing (daily notes,
/// nurse entries/evaluations, therapy notes).
///
/// Drafts are saved on-device (encrypted secure storage, since they contain
/// patient information) while the user types, restored when the form reopens
/// after a crash / kill / lost connection, and cleared the moment the server
/// accepts the submission. Drafts expire after [maxAge] so stale text never
/// resurfaces weeks later.
class DraftService {
  static final DraftService _instance = DraftService._internal();
  factory DraftService() => _instance;
  DraftService._internal();

  static const Duration maxAge = Duration(days: 7);

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // ---- Keys ----
  static String dailyNoteKey(int patientId) => 'draft_daily_note_$patientId';
  static String careEntryKey(int carePlanId) => 'draft_care_entry_$carePlanId';
  static String therapyNoteKey(int patientId) => 'draft_therapy_note_$patientId';

  /// Persist a draft. Call with the full form snapshot (idempotent).
  Future<void> save(String key, Map<String, dynamic> data) async {
    try {
      await _storage.write(
        key: key,
        value: jsonEncode({
          'saved_at': DateTime.now().toIso8601String(),
          'data': data,
        }),
      );
    } catch (e) {
      // Never let drafting break the form
      debugPrint('⚠️ [DraftService] save failed for $key: $e');
    }
  }

  /// Load a draft, or null if none / expired / unreadable.
  Future<Map<String, dynamic>?> load(String key) async {
    try {
      final raw = await _storage.read(key: key);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      final savedAt = DateTime.tryParse(decoded['saved_at']?.toString() ?? '');
      if (savedAt == null || DateTime.now().difference(savedAt) > maxAge) {
        await clear(key);
        return null;
      }

      final data = decoded['data'];
      return data is Map ? Map<String, dynamic>.from(data) : null;
    } catch (e) {
      debugPrint('⚠️ [DraftService] load failed for $key: $e');
      return null;
    }
  }

  /// Remove a draft (call after a successful submit, or when the form is
  /// emptied by the user).
  Future<void> clear(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('⚠️ [DraftService] clear failed for $key: $e');
    }
  }
}
