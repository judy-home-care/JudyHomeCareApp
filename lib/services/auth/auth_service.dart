import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../models/auth/auth_models.dart';
import '../../utils/api_client.dart';
import '../../utils/api_config.dart';
import '../../utils/secure_storage.dart';
import '../notification_service.dart'; // ✅ ADD THIS IMPORT

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _apiClient = ApiClient();
  final _storage = SecureStorage();
  final _notificationService = NotificationService(); // ✅ ADD THIS

  // Login
  Future<LoginResponse> login(LoginRequest request) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.loginEndpoint}');
      
      if (kDebugMode) {
        print('🔵 Login Request URL: $url');
        print('🔵 Login Request Body: ${jsonEncode(request.toJson())}');
      }
      
      final response = await http.post(
        url,
        headers: ApiConfig.headers,
        body: jsonEncode(request.toJson()),
      ).timeout(ApiConfig.connectionTimeout);

      if (kDebugMode) {
        print('🟢 Login Response Status: ${response.statusCode}');
        print('🟢 Login Response Body: ${response.body}');
      }

      final responseData = jsonDecode(response.body);

      // CRITICAL: Check if 2FA is required
      if (responseData['requires_2fa'] == true) {
        if (kDebugMode) {
          print('✅ 2FA IS REQUIRED');
          print('📝 2FA Method: ${responseData['two_factor_method']}');
          print('📝 Response Data: $responseData');
        }
        
        // Return 2FA response
        return LoginResponse(
          success: true,
          message: responseData['message'] ?? 'Two-factor authentication required',
          requires2FA: true,
          twoFactorData: {
            'two_factor_method': responseData['two_factor_method'],
            'session_token': responseData['session_token'],
            'message': responseData['message'],
            'data': responseData['data'],
          },
        );
      }

      // Normal login response (no 2FA)
      if (kDebugMode) {
        print('✅ Normal login (no 2FA)');
      }

      final loginResponse = LoginResponse.fromJson(responseData);

      if (loginResponse.success && loginResponse.data != null) {
        await _storage.saveToken(loginResponse.data!.token);
        await _storage.saveUserData(loginResponse.data!.user.toJson());
        await _storage.saveTokenExpiry(loginResponse.data!.expiresAt);
        await _storage.saveRememberMe(request.rememberMe);
        await _storage.updateLastValidation();
        
        // ✅ CRITICAL: Register FCM token for newly logged-in user
        await _registerFcmTokenAfterLogin();
      }

      return loginResponse;
      
    } on SocketException catch (e) {
      if (kDebugMode) {
        print('❌ Socket Exception: $e');
      }
      return LoginResponse(
        success: false,
        message: 'No internet connection. Please check your network.',
      );
    } on http.ClientException catch (e) {
      if (kDebugMode) {
        print('❌ Client Exception: $e');
      }
      return LoginResponse(
        success: false,
        message: 'Unable to connect to server.',
      );
    } on FormatException catch (e) {
      if (kDebugMode) {
        print('❌ Format Exception: $e');
      }
      return LoginResponse(
        success: false,
        message: 'Invalid response from server.',
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Unexpected Error: $e');
        print('❌ Stack Trace: $stackTrace');
      }
      return LoginResponse(
        success: false,
        message: 'An unexpected error occurred: ${e.toString()}',
      );
    }
  }

  // ✅ NEW: Register FCM token after login
  Future<void> _registerFcmTokenAfterLogin() async {
    try {
      if (kDebugMode) {
        print('🔔 [AuthService] Registering FCM token after login...');
      }
      
      await _notificationService.registerTokenForCurrentUser();
      
      if (kDebugMode) {
        print('✅ [AuthService] FCM token registered successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ [AuthService] FCM token registration failed (non-critical): $e');
      }
      // Don't throw - allow login to succeed even if FCM registration fails
    }
  }

  // Verify 2FA during login
  Future<Map<String, dynamic>> verifyLoginTwoFactor({
    required int userId,
    String? code,
    String? sessionToken,
    required bool rememberMe,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.verifyLoginTwoFactorEndpoint}');
      
      final body = {
        'user_id': userId,
        'remember_me': rememberMe,
        if (code != null) 'code': code,
        if (sessionToken != null) 'session_token': sessionToken,
      };

      if (kDebugMode) {
        print('🔵 Verify 2FA Request: $body');
      }

      final response = await http.post(
        url,
        headers: ApiConfig.headers,
        body: jsonEncode(body),
      ).timeout(ApiConfig.connectionTimeout);

      if (kDebugMode) {
        print('🟢 Verify 2FA Response: ${response.body}');
      }

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        // Save auth data
        if (responseData['data'] != null) {
          final data = responseData['data'];
          if (data['token'] != null) {
            await _storage.saveToken(data['token']);
            await _storage.saveUserData(data['user']);
            await _storage.saveTokenExpiry(data['expires_at']);
            await _storage.saveRememberMe(rememberMe);
            await _storage.updateLastValidation();
            
            // ✅ CRITICAL: Register FCM token after 2FA login
            await _registerFcmTokenAfterLogin();
          }
        }
      }

      return responseData;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Verify 2FA Error: $e');
      }
      return {
        'success': false,
        'message': 'Verification failed. Please try again.',
      };
    }
  }

  // Resend 2FA code during login
  Future<Map<String, dynamic>> resendLoginTwoFactor({
    required int userId,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.resendLoginTwoFactorEndpoint}');
      
      final body = {
        'user_id': userId,
      };

      final response = await http.post(
        url,
        headers: ApiConfig.headers,
        body: jsonEncode(body),
      ).timeout(ApiConfig.connectionTimeout);

      return jsonDecode(response.body);
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to resend code. Please try again.',
      };
    }
  }

  // ✅ UPDATED: Logout with FCM token cleanup
  Future<Map<String, dynamic>> logout() async {
    try {
      if (kDebugMode) {
        print('🔓 [AuthService] Starting logout process...');
      }
      
      // ✅ STEP 1: Unregister FCM token FIRST (before API logout)
      try {
        await _notificationService.unregisterToken();
        if (kDebugMode) {
          print('✅ [AuthService] FCM token unregistered');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ [AuthService] FCM unregister failed (continuing): $e');
        }
        // Continue with logout even if FCM unregister fails
      }

      // ✅ STEP 2: Clear notification state
      try {
        await _notificationService.clearNotificationState();
        if (kDebugMode) {
          print('✅ [AuthService] Notification state cleared');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ [AuthService] Clear notification state failed (continuing): $e');
        }
      }

      // ✅ STEP 3: Call logout API endpoint
      try {
        await _apiClient.post(
          ApiConfig.logoutEndpoint,
          requiresAuth: true,
        );
        if (kDebugMode) {
          print('✅ [AuthService] API logout successful');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ [AuthService] API logout failed (continuing): $e');
        }
        // Continue to clear storage even if API call fails
      }

      // ✅ STEP 4: Clear local storage
      await _storage.clearAll();
      if (kDebugMode) {
        print('✅ [AuthService] Local storage cleared');
      }
      
      if (kDebugMode) {
        print('✅ [AuthService] Logout completed successfully');
      }
      
      return {
        'success': true,
        'message': 'Logged out successfully',
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ [AuthService] Logout error: $e');
      }
      
      // Even if everything fails, clear local storage
      try {
        await _storage.clearAll();
      } catch (storageError) {
        if (kDebugMode) {
          print('❌ [AuthService] Critical: Failed to clear storage: $storageError');
        }
      }
      
      return {
        'success': true,
        'message': 'Logged out successfully',
      };
    }
  }

  // Get current user
  Future<User?> getCurrentUser() async {
    try {
      final userData = await _storage.getUserData();
      if (userData != null) {
        return User.fromJson(userData);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Refresh user data from API - NON-CRITICAL, doesn't force logout on failure
  Future<User?> refreshUserData() async {
    try {
      final response = await _apiClient.get(
        ApiConfig.meEndpoint,
        requiresAuth: true,
      ).timeout(const Duration(seconds: 10));

      if (response['success'] == true && response['data'] != null) {
        final user = User.fromJson(response['data'] as Map<String, dynamic>);
        await _storage.saveUserData(user.toJson());
        await _storage.updateLastValidation();
        return user;
      }

      // Return cached user if API fails
      return await getCurrentUser();
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Failed to refresh user data (using cached): $e');
      }
      // Don't throw error, just return cached user
      return await getCurrentUser();
    }
  }

  // Check if user is logged in - LOCAL CHECK ONLY, NEVER FORCES LOGOUT
  Future<bool> isLoggedIn() async {
    return await _storage.isLoggedIn();
  }

  // Validate token - IMPROVED: Never forces logout on network failures
  Future<bool> validateToken() async {
    try {
      // First check local validity - this is the most important check
      final isLoggedIn = await _storage.isLoggedIn();
      if (!isLoggedIn) {
        if (kDebugMode) {
          print('❌ Not logged in locally');
        }
        return false;
      }

      // Check if we need to validate with API
      final shouldValidate = await _storage.shouldValidateWithAPI();
      if (!shouldValidate) {
        // Token is valid locally and we validated recently
        if (kDebugMode) {
          print('✅ Token valid locally, skipping API validation (validated recently)');
        }
        return true;
      }

      // Try to validate with API but don't force logout on failure
      try {
        if (kDebugMode) {
          print('🔄 Attempting API validation...');
        }

        final response = await _apiClient.get(
          ApiConfig.meEndpoint,
          requiresAuth: true,
        ).timeout(const Duration(seconds: 10));

        if (response['success'] == true) {
          await _storage.updateLastValidation();
          
          // Update user data if available
          if (response['data'] != null) {
            final user = User.fromJson(response['data'] as Map<String, dynamic>);
            await _storage.saveUserData(user.toJson());
          }
          
          if (kDebugMode) {
            print('✅ API validation successful');
          }
          return true;
        }
        
        // API returned unsuccessful but don't log out
        // Keep user logged in based on local token validity
        if (kDebugMode) {
          print('⚠️ API validation unsuccessful, keeping user logged in based on local token');
        }
        return await _storage.isLoggedIn();
        
      } catch (e) {
        // Network error or timeout - CRITICAL: Don't log out user
        if (kDebugMode) {
          print('⚠️ API validation failed (network/timeout), keeping user logged in: $e');
        }
        // If token is valid locally, keep them logged in
        return await _storage.isLoggedIn();
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Token validation error, defaulting to local check: $e');
      }
      // On any error, fall back to local validation
      return await _storage.isLoggedIn();
    }
  }

  // Forgot password
  Future<Map<String, dynamic>> forgotPassword(ForgotPasswordRequest request) async {
    try {
      final response = await _apiClient.post(
        ApiConfig.forgotPasswordEndpoint,
        body: request.toJson(),
        requiresAuth: false,
      );

      return response;
    } on ApiError catch (e) {
      return {
        'success': false,
        'message': e.displayMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred. Please try again.',
      };
    }
  }

  // Reset password
  Future<Map<String, dynamic>> resetPassword(ResetPasswordRequest request) async {
    try {
      final response = await _apiClient.post(
        ApiConfig.resetPasswordEndpoint,
        body: request.toJson(),
        requiresAuth: false,
      );

      return response;
    } on ApiError catch (e) {
      return {
        'success': false,
        'message': e.displayMessage,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred. Please try again.',
      };
    }
  }

  // Register new user
  Future<RegisterResponse> register(RegisterRequest request) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.registerEndpoint}');
      
      if (kDebugMode) {
        print('🔵 Register Request URL: $url');
        print('🔵 Register Request Body: ${jsonEncode(request.toJson())}');
      }
      
      final response = await http.post(
        url,
        headers: ApiConfig.headers,
        body: jsonEncode(request.toJson()),
      ).timeout(ApiConfig.connectionTimeout);

      if (kDebugMode) {
        print('🟢 Register Response Status: ${response.statusCode}');
        print('🟢 Register Response Body: ${response.body}');
      }

      final responseData = jsonDecode(response.body);
      final registerResponse = RegisterResponse.fromJson(responseData);

      return registerResponse;
      
    } on SocketException catch (e) {
      if (kDebugMode) {
        print('❌ Socket Exception: $e');
      }
      return RegisterResponse(
        success: false,
        message: 'No internet connection. Please check your network.',
      );
    } on http.ClientException catch (e) {
      if (kDebugMode) {
        print('❌ Client Exception: $e');
      }
      return RegisterResponse(
        success: false,
        message: 'Unable to connect to server.',
      );
    } on FormatException catch (e) {
      if (kDebugMode) {
        print('❌ Format Exception: $e');
      }
      return RegisterResponse(
        success: false,
        message: 'Invalid response from server.',
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ Unexpected Error: $e');
        print('❌ Stack Trace: $stackTrace');
      }
      return RegisterResponse(
        success: false,
        message: 'An unexpected error occurred: ${e.toString()}',
      );
    }
  }

  // Silent background validation - never blocks UI or forces logout
  Future<void> validateInBackground() async {
    try {
      final shouldValidate = await _storage.shouldValidateWithAPI();
      if (!shouldValidate) return;

      final response = await _apiClient.get(
        ApiConfig.meEndpoint,
        requiresAuth: true,
      ).timeout(const Duration(seconds: 10));

      if (response['success'] == true) {
        await _storage.updateLastValidation();
        
        if (response['data'] != null) {
          final user = User.fromJson(response['data'] as Map<String, dynamic>);
          await _storage.saveUserData(user.toJson());
        }
      }
    } catch (e) {
      // Silently fail - don't affect user experience
      if (kDebugMode) {
        print('⚠️ Background validation failed (ignored): $e');
      }
    }
  }
}