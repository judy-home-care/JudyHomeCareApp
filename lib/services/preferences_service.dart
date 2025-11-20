import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  SharedPreferences? _prefs;

  // Keys
  static const String _hasSeenOnboardingKey = 'has_seen_onboarding';
  static const String _isFirstLaunchKey = 'is_first_launch';

  // Initialize SharedPreferences
  Future<void> init() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      if (kDebugMode) {
        print('✅ PreferencesService initialized successfully');
        // Debug: Print current state
        print('📱 Current onboarding status: ${_prefs!.getBool(_hasSeenOnboardingKey)}');
        print('📱 Is first launch: ${_prefs!.getBool(_isFirstLaunchKey)}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ PreferencesService initialization error: $e');
      }
      rethrow;
    }
  }

  // Ensure preferences are initialized
  Future<SharedPreferences> get _preferences async {
    if (_prefs == null) {
      await init();
    }
    return _prefs!;
  }

  // Check if user has seen onboarding
  Future<bool> hasSeenOnboarding() async {
    try {
      final prefs = await _preferences;
      final result = prefs.getBool(_hasSeenOnboardingKey) ?? false;
      
      if (kDebugMode) {
        print('🔍 Checking onboarding status: $result');
      }
      
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking onboarding status: $e');
      }
      return false;
    }
  }

  // Mark onboarding as completed
  Future<void> setOnboardingCompleted() async {
    try {
      final prefs = await _preferences;
      
      // Save the value
      final success = await prefs.setBool(_hasSeenOnboardingKey, true);
      
      if (kDebugMode) {
        print('💾 Saving onboarding completed: $success');
      }
      
      // CRITICAL FOR iOS: Force reload to ensure data is persisted
      await prefs.reload();
      
      // Verify it was saved correctly
      final verification = prefs.getBool(_hasSeenOnboardingKey);
      
      if (kDebugMode) {
        print('✅ Onboarding completed flag saved');
        print('🔍 Verification - Onboarding status is now: $verification');
      }
      
      if (verification != true) {
        if (kDebugMode) {
          print('⚠️ WARNING: Onboarding flag was not saved correctly!');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving onboarding status: $e');
      }
      rethrow;
    }
  }

  // Check if this is first app launch
  Future<bool> isFirstLaunch() async {
    try {
      final prefs = await _preferences;
      final isFirst = prefs.getBool(_isFirstLaunchKey) ?? true;
      
      if (kDebugMode) {
        print('🔍 Is first launch: $isFirst');
      }
      
      if (isFirst) {
        // Mark as no longer first launch
        await prefs.setBool(_isFirstLaunchKey, false);
        await prefs.reload(); // Force persist
        
        if (kDebugMode) {
          print('💾 Marked first launch as complete');
        }
      }
      
      return isFirst;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking first launch: $e');
      }
      return true; // Safe default
    }
  }

  // Reset onboarding (useful for testing or settings)
  Future<void> resetOnboarding() async {
    try {
      final prefs = await _preferences;
      await prefs.setBool(_hasSeenOnboardingKey, false);
      await prefs.reload(); // Force persist
      
      if (kDebugMode) {
        print('🔄 Onboarding reset to false');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error resetting onboarding: $e');
      }
    }
  }

  // Clear all preferences (useful for logout or reset)
  Future<void> clearAll() async {
    try {
      final prefs = await _preferences;
      await prefs.clear();
      await prefs.reload(); // Force persist
      
      if (kDebugMode) {
        print('🗑️ All preferences cleared');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error clearing preferences: $e');
      }
    }
  }

  // Clear all except onboarding status (useful for logout but keeping onboarding state)
  Future<void> clearExceptOnboarding() async {
    try {
      final prefs = await _preferences;
      final hasSeenOnboarding = prefs.getBool(_hasSeenOnboardingKey) ?? false;
      
      await prefs.clear();
      await prefs.setBool(_hasSeenOnboardingKey, hasSeenOnboarding);
      await prefs.reload(); // Force persist
      
      if (kDebugMode) {
        print('🗑️ Cleared all preferences except onboarding');
        print('🔍 Preserved onboarding status: $hasSeenOnboarding');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error clearing preferences except onboarding: $e');
      }
    }
  }

  // Debug: Print all stored values
  Future<void> debugPrintAll() async {
    if (kDebugMode) {
      try {
        final prefs = await _preferences;
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📋 ALL STORED PREFERENCES:');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('Has seen onboarding: ${prefs.getBool(_hasSeenOnboardingKey)}');
        print('Is first launch: ${prefs.getBool(_isFirstLaunchKey)}');
        print('All keys: ${prefs.getKeys()}');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      } catch (e) {
        print('❌ Error printing preferences: $e');
      }
    }
  }
}