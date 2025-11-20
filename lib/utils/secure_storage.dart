import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class SecureStorage {
  static final SecureStorage _instance = SecureStorage._internal();
  factory SecureStorage() => _instance;
  SecureStorage._internal();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // Keys
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';
  static const String _expiresAtKey = 'token_expires_at';
  static const String _rememberMeKey = 'remember_me';
  static const String _lastValidationKey = 'last_validation';

  // Token operations
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  // User data operations
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    await _storage.write(key: _userKey, value: jsonEncode(userData));
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final data = await _storage.read(key: _userKey);
    if (data != null) {
      return jsonDecode(data) as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> deleteUserData() async {
    await _storage.delete(key: _userKey);
  }

  // Token expiry operations
  Future<void> saveTokenExpiry(String expiresAt) async {
    await _storage.write(key: _expiresAtKey, value: expiresAt);
  }

  Future<String?> getTokenExpiry() async {
    return await _storage.read(key: _expiresAtKey);
  }

  Future<void> deleteTokenExpiry() async {
    await _storage.delete(key: _expiresAtKey);
  }

  // Remember me operations
  Future<void> saveRememberMe(bool rememberMe) async {
    await _storage.write(key: _rememberMeKey, value: rememberMe.toString());
  }

  Future<bool> getRememberMe() async {
    final value = await _storage.read(key: _rememberMeKey);
    return value == 'true';
  }

  // Last validation timestamp operations
  Future<void> updateLastValidation() async {
    await _storage.write(
      key: _lastValidationKey,
      value: DateTime.now().toIso8601String(),
    );
  }

  Future<String?> getLastValidation() async {
    return await _storage.read(key: _lastValidationKey);
  }

  // Check if we should validate with API (only validate every 6 hours)
  Future<bool> shouldValidateWithAPI() async {
    final lastValidation = await _storage.read(key: _lastValidationKey);
    if (lastValidation == null) return true;

    try {
      final lastValidationDate = DateTime.parse(lastValidation);
      final hoursSinceValidation = DateTime.now().difference(lastValidationDate).inHours;
      return hoursSinceValidation >= 6; // Only validate every 6 hours
    } catch (e) {
      return true;
    }
  }

  // Check if token is expired with generous buffer
  Future<bool> isTokenExpired() async {
    final expiresAt = await getTokenExpiry();
    if (expiresAt == null) {
      // No expiry date means no token, so consider it expired
      final token = await getToken();
      return token == null;
    }

    try {
      final expiryDate = DateTime.parse(expiresAt);
      // Only consider expired if we're past the actual expiry date
      // No buffer - be generous to keep users logged in
      return DateTime.now().isAfter(expiryDate);
    } catch (e) {
      // If we can't parse the date but have a token, assume valid
      final token = await getToken();
      return token == null;
    }
  }

  // Clear all auth data
  Future<void> clearAll() async {
    await deleteToken();
    await deleteUserData();
    await deleteTokenExpiry();
    await _storage.delete(key: _rememberMeKey);
    await _storage.delete(key: _lastValidationKey);
  }

  // Check if user is logged in - IMPROVED VERSION
  Future<bool> isLoggedIn() async {
    try {
      // Check if token exists
      final token = await getToken();
      if (token == null || token.isEmpty) return false;

      // Check if user data exists
      final userData = await getUserData();
      if (userData == null) return false;

      // Check token expiry - be generous
      final isExpired = await isTokenExpired();
      if (isExpired) return false;

      // All checks passed - user is logged in
      return true;
    } catch (e) {
      // If there's any error, try to determine if we have basic auth data
      final token = await getToken();
      return token != null && token.isNotEmpty;
    }
  }
}