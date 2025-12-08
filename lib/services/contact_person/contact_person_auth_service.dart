import 'package:flutter/foundation.dart';
import '../../models/contact_person/contact_person_models.dart';
import '../../utils/api_client.dart';
import '../../utils/api_config.dart';
import '../../utils/secure_storage.dart';

class ContactPersonAuthService {
  final ApiClient _apiClient = ApiClient();
  final SecureStorage _secureStorage = SecureStorage();

  /// Login with phone number - direct login without OTP
  Future<ContactPersonVerifyOtpResponse> login(String phone) async {
    try {
      debugPrint('[ContactPersonAuth] Initiating login for phone: $phone');

      final response = await _apiClient.post(
        ApiConfig.contactPersonLoginEndpoint,
        body: {'phone': phone},
      );

      debugPrint('[ContactPersonAuth] Raw login response: $response');
      debugPrint('[ContactPersonAuth] Response type: ${response.runtimeType}');

      final result = ContactPersonVerifyOtpResponse.fromJson(response);

      debugPrint('[ContactPersonAuth] Parsed result - success: ${result.success}, hasToken: ${result.token != null}, hasUser: ${result.user != null}');
      if (result.user != null) {
        debugPrint('[ContactPersonAuth] User: id=${result.user!.id}, name=${result.user!.name}, linkedPatients=${result.user!.linkedPatients.length}');
        for (var patient in result.user!.linkedPatients) {
          debugPrint('[ContactPersonAuth] - Patient: id=${patient.id}, name=${patient.name}, relationship=${patient.relationship}');
        }
      }

      // Store token and user data if successful
      if (result.success && result.token != null) {
        debugPrint('[ContactPersonAuth] Storing token and user type...');
        await _secureStorage.saveToken(result.token!);
        await _secureStorage.saveUserType('contact_person');

        if (result.user != null) {
          debugPrint('[ContactPersonAuth] Storing contact person data...');
          await _secureStorage.saveContactPersonData(result.user!);
        }
      } else if (result.success) {
        debugPrint('[ContactPersonAuth] Success but no token - storing user type only');
        await _secureStorage.saveUserType('contact_person');
        if (result.user != null) {
          await _secureStorage.saveContactPersonData(result.user!);
        }
      }

      return result;
    } catch (e, stackTrace) {
      debugPrint('[ContactPersonAuth] Login error: $e');
      debugPrint('[ContactPersonAuth] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Verify OTP and complete login
  Future<ContactPersonVerifyOtpResponse> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    try {
      debugPrint('[ContactPersonAuth] Verifying OTP for phone: $phone');

      final response = await _apiClient.post(
        ApiConfig.contactPersonVerifyOtpEndpoint,
        body: {
          'phone': phone,
          'otp': otp,
        },
      );

      debugPrint('[ContactPersonAuth] Verify OTP response: $response');

      final result = ContactPersonVerifyOtpResponse.fromJson(response);

      // Store token and user data if successful
      if (result.success && result.token != null) {
        await _secureStorage.saveToken(result.token!);
        await _secureStorage.saveUserType('contact_person');

        if (result.user != null) {
          await _secureStorage.saveContactPersonData(result.user!);
        }
      }

      return result;
    } catch (e) {
      debugPrint('[ContactPersonAuth] Verify OTP error: $e');
      rethrow;
    }
  }

  /// Resend OTP
  Future<ContactPersonLoginResponse> resendOtp(String phone) async {
    try {
      debugPrint('[ContactPersonAuth] Resending OTP for phone: $phone');

      final response = await _apiClient.post(
        ApiConfig.contactPersonResendOtpEndpoint,
        body: {'phone': phone},
      );

      debugPrint('[ContactPersonAuth] Resend OTP response: $response');

      return ContactPersonLoginResponse.fromJson(response);
    } catch (e) {
      debugPrint('[ContactPersonAuth] Resend OTP error: $e');
      rethrow;
    }
  }

  /// Logout
  Future<bool> logout() async {
    try {
      debugPrint('[ContactPersonAuth] Logging out...');

      await _apiClient.post(ApiConfig.contactPersonLogoutEndpoint);

      // Clear stored data
      await _secureStorage.deleteToken();
      await _secureStorage.deleteUserType();
      await _secureStorage.deleteContactPersonData();
      await _secureStorage.deleteSelectedPatientId();

      debugPrint('[ContactPersonAuth] Logout successful');
      return true;
    } catch (e) {
      debugPrint('[ContactPersonAuth] Logout error: $e');
      // Still clear local data even if API call fails
      await _secureStorage.deleteToken();
      await _secureStorage.deleteUserType();
      await _secureStorage.deleteContactPersonData();
      await _secureStorage.deleteSelectedPatientId();
      return false;
    }
  }

  /// Check if contact person is logged in
  Future<bool> isLoggedIn() async {
    final token = await _secureStorage.getToken();
    final userType = await _secureStorage.getUserType();
    return token != null && userType == 'contact_person';
  }

  /// Get stored contact person data
  Future<ContactPersonUser?> getStoredContactPerson() async {
    return await _secureStorage.getContactPersonData();
  }

  /// Get selected patient ID
  Future<int?> getSelectedPatientId() async {
    return await _secureStorage.getSelectedPatientId();
  }

  /// Set selected patient ID
  Future<void> setSelectedPatientId(int patientId) async {
    await _secureStorage.saveSelectedPatientId(patientId);
  }
}
