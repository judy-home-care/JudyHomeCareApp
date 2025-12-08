import '../../utils/api_client.dart';
import '../../utils/api_config.dart';
import '../../models/auth/forgot_password_models.dart';

class ForgotPasswordService {
  static final ForgotPasswordService _instance = ForgotPasswordService._internal();
  factory ForgotPasswordService() => _instance;
  ForgotPasswordService._internal();

  final _apiClient = ApiClient();

  /// Send forgot password OTP via SMS
  Future<ForgotPasswordResponse> sendResetCode(ForgotPasswordRequest request) async {
    try {
      final response = await _apiClient.post(
        ApiConfig.forgotPasswordEndpoint,
        body: request.toJson(),
        requiresAuth: false,
      );

      return ForgotPasswordResponse.fromJson(response);
    } catch (e) {
      if (e is ApiError) {
        return ForgotPasswordResponse(
          success: false,
          message: e.displayMessage,
        );
      }
      return ForgotPasswordResponse(
        success: false,
        message: 'Failed to send reset code. Please try again.',
      );
    }
  }

  /// Verify OTP code (for phone-based reset)
  Future<VerifyOtpResponse> verifyOtp(VerifyOtpRequest request) async {
    try {
      final response = await _apiClient.post(
        ApiConfig.verifyResetOtpEndpoint,
        body: request.toJson(),
        requiresAuth: false,
      );

      return VerifyOtpResponse.fromJson(response);
    } catch (e) {
      if (e is ApiError) {
        return VerifyOtpResponse(
          success: false,
          message: e.displayMessage,
        );
      }
      return VerifyOtpResponse(
        success: false,
        message: 'Failed to verify code. Please try again.',
      );
    }
  }

  /// Resend OTP code
  Future<ApiResponse> resendOtp(ResendOtpRequest request) async {
    try {
      final response = await _apiClient.post(
        ApiConfig.resendResetOtpEndpoint,
        body: request.toJson(),
        requiresAuth: false,
      );

      return ApiResponse.fromJson(response);
    } catch (e) {
      if (e is ApiError) {
        return ApiResponse(
          success: false,
          message: e.displayMessage,
        );
      }
      return ApiResponse(
        success: false,
        message: 'Failed to resend code. Please try again.',
      );
    }
  }

  /// Reset password
  Future<ApiResponse> resetPassword(ResetPasswordRequest request) async {
    try {
      final response = await _apiClient.post(
        ApiConfig.resetPasswordEndpoint,
        body: request.toJson(),
        requiresAuth: false,
      );

      return ApiResponse.fromJson(response);
    } catch (e) {
      if (e is ApiError) {
        return ApiResponse(
          success: false,
          message: e.displayMessage,
        );
      }
      return ApiResponse(
        success: false,
        message: 'Failed to reset password. Please try again.',
      );
    }
  }

  /// Format phone number for API (returns with country code like +233557447800)
  String formatPhoneNumber(String phone, String countryCode) {
    // Remove all non-numeric characters from phone
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');

    // If number starts with 0, remove it
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }

    // Combine country code with phone number
    return '$countryCode$cleaned';
  }

  /// Validate phone format (basic)
  bool isValidPhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return cleaned.length >= 9 && cleaned.length <= 15;
  }
}