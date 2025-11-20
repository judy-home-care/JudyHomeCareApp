// Forgot Password Request
class ForgotPasswordRequest {
  final String contact; // email or phone
  final String contactType; // 'email' or 'phone'

  ForgotPasswordRequest({
    required this.contact,
    required this.contactType,
  });

  Map<String, dynamic> toJson() => {
        'contact': contact,
        'contact_type': contactType,
      };
}

// Verify OTP Request - UPDATED to support both email and phone
class VerifyOtpRequest {
  final String contact; // email or phone
  final String contactType; // 'email' or 'phone'
  final String otp;

  VerifyOtpRequest({
    required this.contact,
    required this.contactType,
    required this.otp,
  });

  Map<String, dynamic> toJson() => {
        'contact': contact,
        'contact_type': contactType,
        'otp': otp,
      };
}

// Resend OTP Request - UPDATED to support both email and phone
class ResendOtpRequest {
  final String contact; // email or phone
  final String contactType; // 'email' or 'phone'

  ResendOtpRequest({
    required this.contact,
    required this.contactType,
  });

  Map<String, dynamic> toJson() => {
        'contact': contact,
        'contact_type': contactType,
      };
}

// Reset Password Request
class ResetPasswordRequest {
  final String token;
  final String contact; // email or phone
  final String contactType; // 'email' or 'phone'
  final String password;
  final String passwordConfirmation;

  ResetPasswordRequest({
    required this.token,
    required this.contact,
    required this.contactType,
    required this.password,
    required this.passwordConfirmation,
  });

  Map<String, dynamic> toJson() => {
        'token': token,
        'contact': contact,
        'contact_type': contactType,
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
  final String contactType;
  final String? email; // masked email
  final String? phone; // masked phone number
  final bool requiresVerification;
  final int expiresIn; // minutes

  ForgotPasswordData({
    required this.contactType,
    this.email,
    this.phone,
    required this.requiresVerification,
    required this.expiresIn,
  });

  factory ForgotPasswordData.fromJson(Map<String, dynamic> json) {
    return ForgotPasswordData(
      contactType: json['contact_type'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      requiresVerification: json['requires_verification'] as bool? ?? true,
      expiresIn: json['expires_in'] as int,
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
  final String contact;
  final String contactType;
  final int expiresIn;

  VerifyOtpData({
    required this.resetToken,
    required this.contact,
    required this.contactType,
    required this.expiresIn,
  });

  factory VerifyOtpData.fromJson(Map<String, dynamic> json) {
    return VerifyOtpData(
      resetToken: json['reset_token'] as String,
      contact: json['contact'] as String,
      contactType: json['contact_type'] as String,
      expiresIn: json['expires_in'] as int,
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