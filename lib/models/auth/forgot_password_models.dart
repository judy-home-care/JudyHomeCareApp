// Forgot Password Request (Mobile - SMS based)
class ForgotPasswordRequest {
  final String phone;

  ForgotPasswordRequest({required this.phone});

  Map<String, dynamic> toJson() => {'phone': phone};
}

// Verify OTP Request
class VerifyOtpRequest {
  final String phone;
  final String otp;

  VerifyOtpRequest({
    required this.phone,
    required this.otp,
  });

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'otp': otp,
      };
}

// Resend OTP Request
class ResendOtpRequest {
  final String phone;

  ResendOtpRequest({required this.phone});

  Map<String, dynamic> toJson() => {'phone': phone};
}

// Reset Password Request
class ResetPasswordRequest {
  final String phone;
  final String token;
  final String password;
  final String passwordConfirmation;

  ResetPasswordRequest({
    required this.phone,
    required this.token,
    required this.password,
    required this.passwordConfirmation,
  });

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'token': token,
        'password': password,
        'password_confirmation': passwordConfirmation,
      };
}

// Forgot Password Response
class ForgotPasswordResponse {
  final bool success;
  final String message;
  final ForgotPasswordData? data;

  ForgotPasswordResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory ForgotPasswordResponse.fromJson(Map<String, dynamic> json) {
    return ForgotPasswordResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null
          ? ForgotPasswordData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

// Forgot Password Data
class ForgotPasswordData {
  final String? phone; // masked phone number
  final bool requiresVerification;
  final int expiresIn; // minutes

  ForgotPasswordData({
    this.phone,
    required this.requiresVerification,
    required this.expiresIn,
  });

  factory ForgotPasswordData.fromJson(Map<String, dynamic> json) {
    return ForgotPasswordData(
      phone: json['phone'] as String?,
      requiresVerification: json['requires_verification'] as bool? ?? true,
      expiresIn: json['expires_in'] as int? ?? 10,
    );
  }
}

// Verify OTP Response
class VerifyOtpResponse {
  final bool success;
  final String message;
  final VerifyOtpData? data;

  VerifyOtpResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory VerifyOtpResponse.fromJson(Map<String, dynamic> json) {
    return VerifyOtpResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null
          ? VerifyOtpData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

// Verify OTP Data
class VerifyOtpData {
  final String resetToken;
  final String phone;
  final int expiresIn;

  VerifyOtpData({
    required this.resetToken,
    required this.phone,
    required this.expiresIn,
  });

  factory VerifyOtpData.fromJson(Map<String, dynamic> json) {
    return VerifyOtpData(
      resetToken: json['reset_token'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      expiresIn: json['expires_in'] as int? ?? 10,
    );
  }
}

// Generic API Response
class ApiResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] as Map<String, dynamic>?,
    );
  }
}
