import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/api_config.dart';
import '../utils/secure_storage.dart';
import 'package:flutter/foundation.dart';

class ProfileService {
  final SecureStorage _storage = SecureStorage();

  // Add debug logging
  void _logRequest(String method, String url, Map<String, dynamic>? body) {
    if (kDebugMode) {
      print('🔵 API Request: $method $url');
      if (body != null) {
        // Don't log passwords in production
        final sanitizedBody = Map<String, dynamic>.from(body);
        if (sanitizedBody.containsKey('current_password')) {
          sanitizedBody['current_password'] = '***';
        }
        if (sanitizedBody.containsKey('new_password')) {
          sanitizedBody['new_password'] = '***';
        }
        if (sanitizedBody.containsKey('new_password_confirmation')) {
          sanitizedBody['new_password_confirmation'] = '***';
        }
        print('📦 Body: $sanitizedBody');
      }
    }
  }

  void _logResponse(int statusCode, dynamic body) {
    if (kDebugMode) {
      print('🟢 API Response: $statusCode');
      print('📦 Response Body: $body');
    }
  }

  /// Update nurse profile
  Future<Map<String, dynamic>> updateProfile({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String gender,
    required String dateOfBirth,
    required String ghanaCard,
    required String licenseNumber,
    required String specialization,
    required int yearsOfExperience,
  }) async {
    try {
      final token = await _storage.getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'No authentication token found. Please login again.',
        };
      }

      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.updateProfileEndpoint}');
      
      final body = {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'gender': gender,
        'date_of_birth': dateOfBirth,
        'ghana_card_number': ghanaCard,
        'license_number': licenseNumber,
        'specialization': specialization,
        'years_of_experience': yearsOfExperience,
      };

      _logRequest('PUT', url.toString(), body);

      final response = await http.put(
        url,
        headers: ApiConfig.authHeaders(token),
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout. Please check your internet connection.');
        },
      );

      _logResponse(response.statusCode, response.body);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Profile updated successfully',
          'data': responseData['data'],
        };
      } else if (response.statusCode == 422) {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Validation failed',
          'errors': responseData['errors'],
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Session expired. Please login again.',
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to update profile',
          'errors': responseData['errors'],
        };
      }
    } on SocketException {
      return {
        'success': false,
        'message': 'No internet connection. Please check your network.',
      };
    } on http.ClientException catch (e) {
      return {
        'success': false,
        'message': 'Unable to connect to server: ${e.message}',
      };
    } on FormatException catch (e) {
      return {
        'success': false,
        'message': 'Invalid response from server: ${e.message}',
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating profile: $e');
      }
      return {
        'success': false,
        'message': 'An error occurred: ${e.toString()}',
      };
    }
  }

  /// Get current user profile
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final token = await _storage.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.profilePrefix}');
      
      final response = await http.get(
        url,
        headers: ApiConfig.authHeaders(token),
      ).timeout(ApiConfig.connectionTimeout);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': responseData['data'],
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to fetch profile',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'An error occurred: ${e.toString()}',
      };
    }
  }

  /// Change password
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    try {
      final token = await _storage.getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'No authentication token found. Please login again.',
        };
      }

      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.changePasswordEndpoint}');
      
      final body = {
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': newPasswordConfirmation,
      };

      _logRequest('POST', url.toString(), body);

      final response = await http.post(
        url,
        headers: ApiConfig.authHeaders(token),
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout. Please check your internet connection.');
        },
      );

      _logResponse(response.statusCode, response.body);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Password changed successfully',
        };
      } else if (response.statusCode == 422) {
        // Handle validation errors
        String errorMessage = responseData['message'] ?? 'Validation failed';
        
        // Check for specific error messages
        if (responseData['errors'] != null) {
          final errors = responseData['errors'] as Map<String, dynamic>;
          if (errors.isNotEmpty) {
            // Get the first error message
            errorMessage = errors.values.first is List 
                ? (errors.values.first as List).first.toString()
                : errors.values.first.toString();
          }
        }
        
        return {
          'success': false,
          'message': errorMessage,
          'errors': responseData['errors'],
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Session expired. Please login again.',
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to change password',
        };
      }
    } on SocketException {
      return {
        'success': false,
        'message': 'No internet connection. Please check your network.',
      };
    } on http.ClientException catch (e) {
      return {
        'success': false,
        'message': 'Unable to connect to server: ${e.message}',
      };
    } on FormatException catch (e) {
      return {
        'success': false,
        'message': 'Invalid response from server: ${e.message}',
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error changing password: $e');
      }
      return {
        'success': false,
        'message': 'An error occurred: ${e.toString()}',
      };
    }
  }

  /// Enable two-factor authentication (sends OTP for SMS/Email)
  Future<Map<String, dynamic>> enableTwoFactor({
    required String method, // 'email', 'sms', or 'biometric'
  }) async {
    try {
      final token = await _storage.getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'No authentication token found. Please login again.',
        };
      }

      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.enableTwoFactorEndpoint}');
      
      final body = {
        'method': method,
      };

      _logRequest('POST', url.toString(), body);

      final response = await http.post(
        url,
        headers: ApiConfig.authHeaders(token),
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout. Please check your internet connection.');
        },
      );

      _logResponse(response.statusCode, response.body);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Two-factor authentication enabled',
          'data': responseData['data'], // Contains method, email/phone, requires_verification
        };
      } else if (response.statusCode == 422) {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Validation failed',
          'errors': responseData['errors'],
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Session expired. Please login again.',
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to enable two-factor authentication',
        };
      }
    } on SocketException {
      return {
        'success': false,
        'message': 'No internet connection. Please check your network.',
      };
    } on http.ClientException catch (e) {
      return {
        'success': false,
        'message': 'Unable to connect to server: ${e.message}',
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error enabling 2FA: $e');
      }
      return {
        'success': false,
        'message': 'An error occurred: ${e.toString()}',
      };
    }
  }

  /// Verify 2FA OTP code
  Future<Map<String, dynamic>> verifyTwoFactorOtp({
    required String otp,
  }) async {
    try {
      final token = await _storage.getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'No authentication token found. Please login again.',
        };
      }

      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.verifyTwoFactorEndpoint}');
      
      final body = {
        'otp': otp,
      };

      _logRequest('POST', url.toString(), body);

      final response = await http.post(
        url,
        headers: ApiConfig.authHeaders(token),
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout. Please check your internet connection.');
        },
      );

      _logResponse(response.statusCode, response.body);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Code verified successfully',
          'data': responseData['data'],
        };
      } else if (response.statusCode == 400) {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Invalid or expired code',
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Session expired. Please login again.',
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to verify code',
        };
      }
    } on SocketException {
      return {
        'success': false,
        'message': 'No internet connection. Please check your network.',
      };
    } on http.ClientException catch (e) {
      return {
        'success': false,
        'message': 'Unable to connect to server: ${e.message}',
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error verifying 2FA OTP: $e');
      }
      return {
        'success': false,
        'message': 'An error occurred: ${e.toString()}',
      };
    }
  }

  /// Resend 2FA verification code
  Future<Map<String, dynamic>> resendTwoFactorCode() async {
    try {
      final token = await _storage.getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'No authentication token found. Please login again.',
        };
      }

      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.resendTwoFactorEndpoint}');

      _logRequest('POST', url.toString(), null);

      final response = await http.post(
        url,
        headers: ApiConfig.authHeaders(token),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout. Please check your internet connection.');
        },
      );

      _logResponse(response.statusCode, response.body);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'New verification code sent',
          'data': responseData['data'],
        };
      } else if (response.statusCode == 400) {
        return {
          'success': false,
          'message': responseData['message'] ?? 'No pending verification found',
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Session expired. Please login again.',
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to resend code',
        };
      }
    } on SocketException {
      return {
        'success': false,
        'message': 'No internet connection. Please check your network.',
      };
    } on http.ClientException catch (e) {
      return {
        'success': false,
        'message': 'Unable to connect to server: ${e.message}',
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error resending 2FA code: $e');
      }
      return {
        'success': false,
        'message': 'An error occurred: ${e.toString()}',
      };
    }
  }

  /// Disable two-factor authentication
  Future<Map<String, dynamic>> disableTwoFactor() async {
    try {
      final token = await _storage.getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'No authentication token found. Please login again.',
        };
      }

      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.disableTwoFactorEndpoint}');

      _logRequest('POST', url.toString(), null);

      final response = await http.post(
        url,
        headers: ApiConfig.authHeaders(token),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout. Please check your internet connection.');
        },
      );

      _logResponse(response.statusCode, response.body);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Two-factor authentication disabled',
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Session expired. Please login again.',
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to disable two-factor authentication',
        };
      }
    } on SocketException {
      return {
        'success': false,
        'message': 'No internet connection. Please check your network.',
      };
    } on http.ClientException catch (e) {
      return {
        'success': false,
        'message': 'Unable to connect to server: ${e.message}',
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error disabling 2FA: $e');
      }
      return {
        'success': false,
        'message': 'An error occurred: ${e.toString()}',
      };
    }
  }

  /// Update notification settings (Security - Email & Login Alerts)
  Future<Map<String, dynamic>> updateNotificationSettings({
    required bool emailNotifications,
    required bool loginAlerts,
  }) async {
    try {
      final token = await _storage.getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'No authentication token found. Please login again.',
        };
      }

      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.notificationSettingsEndpoint}');
      
      final body = {
        'email_notifications': emailNotifications,
        'login_alerts': loginAlerts,
      };

      _logRequest('POST', url.toString(), body);

      final response = await http.post(
        url,
        headers: ApiConfig.authHeaders(token),
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout. Please check your internet connection.');
        },
      );

      _logResponse(response.statusCode, response.body);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Notification settings updated',
        };
      } else if (response.statusCode == 422) {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Validation failed',
          'errors': responseData['errors'],
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Session expired. Please login again.',
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to update notification settings',
        };
      }
    } on SocketException {
      return {
        'success': false,
        'message': 'No internet connection. Please check your network.',
      };
    } on http.ClientException catch (e) {
      return {
        'success': false,
        'message': 'Unable to connect to server: ${e.message}',
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating notification settings: $e');
      }
      return {
        'success': false,
        'message': 'An error occurred: ${e.toString()}',
      };
    }
  }

  /// Update comprehensive notification preferences
  Future<Map<String, dynamic>> updateNotificationPreferences(
    Map<String, dynamic> preferences,
  ) async {
    try {
      final token = await _storage.getToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'No authentication token found. Please login again.',
        };
      }

      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.notificationPreferencesEndpoint}');

      _logRequest('POST', url.toString(), preferences);

      final response = await http.post(
        url,
        headers: ApiConfig.authHeaders(token),
        body: jsonEncode(preferences),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout. Please check your internet connection.');
        },
      );

      _logResponse(response.statusCode, response.body);

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Notification preferences updated',
        };
      } else if (response.statusCode == 422) {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Validation failed',
          'errors': responseData['errors'],
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Session expired. Please login again.',
        };
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Failed to update notification preferences',
        };
      }
    } on SocketException {
      return {
        'success': false,
        'message': 'No internet connection. Please check your network.',
      };
    } on http.ClientException catch (e) {
      return {
        'success': false,
        'message': 'Unable to connect to server: ${e.message}',
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating notification preferences: $e');
      }
      return {
        'success': false,
        'message': 'An error occurred: ${e.toString()}',
      };
    }
  }
}