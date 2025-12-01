// Add this import at the very top of your auth_models.dart file
import 'dart:io';

// Login Request Model
class LoginRequest {
  final String email;
  final String password;
  final bool rememberMe;

  LoginRequest({
    required this.email,
    required this.password,
    this.rememberMe = false,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'remember_me': rememberMe,
      };
}

// User Model
class User {
  final int id;
  final String firstName;
  final String lastName;
  final String fullName;
  final String email;
  final String role;
  final String avatarUrl;
  final bool isActive;
  final bool isVerified;
  final String? lastLoginAt;
  final List<String> permissions;
  final String dashboardRoute;

  final String? phone;
  final String? gender;
  final String? dateOfBirth;
  final String? ghanaCardNumber;
  final String? licenseNumber;
  final String? specialization;
  final int? yearsOfExperience;
  final bool emergencyContactNotify;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.email,
    required this.role,
    required this.avatarUrl,
    required this.isActive,
    required this.isVerified,
    this.lastLoginAt,
    required this.permissions,
    required this.dashboardRoute,
    this.phone,
    this.gender,
    this.dateOfBirth,
    this.ghanaCardNumber,
    this.licenseNumber,
    this.specialization,
    this.yearsOfExperience,
    this.emergencyContactNotify = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      avatarUrl: json['avatar_url'] as String,
      isActive: json['is_active'] as bool,
      isVerified: json['is_verified'] as bool,
      lastLoginAt: json['last_login_at'] as String?,
      permissions: (json['permissions'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      dashboardRoute: json['dashboard_route'] as String,
      phone: json['phone'] as String?,
      gender: json['gender'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      ghanaCardNumber: json['ghana_card_number'] as String?,
      licenseNumber: json['license_number'] as String?,
      specialization: json['specialization'] as String?,
      yearsOfExperience: json['years_of_experience'] != null
          ? (json['years_of_experience'] as num).toInt()
          : null,
      emergencyContactNotify: json['emergency_contact_notify'] == true || 
          json['emergency_contact_notify'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'first_name': firstName,
        'last_name': lastName,
        'full_name': fullName,
        'email': email,
        'role': role,
        'avatar_url': avatarUrl,
        'is_active': isActive,
        'is_verified': isVerified,
        'last_login_at': lastLoginAt,
        'permissions': permissions,
        'dashboard_route': dashboardRoute,
        'phone': phone,
        'gender': gender,
        'date_of_birth': dateOfBirth,
        'ghana_card_number': ghanaCardNumber,
        'license_number': licenseNumber,
        'specialization': specialization,
        'years_of_experience': yearsOfExperience,
        'emergency_contact_notify': emergencyContactNotify,
      };
}

// Login Data Model
class LoginData {
  final User user;
  final String token;
  final String tokenType;
  final String expiresAt;
  final String redirectTo;

  LoginData({
    required this.user,
    required this.token,
    required this.tokenType,
    required this.expiresAt,
    required this.redirectTo,
  });

  factory LoginData.fromJson(Map<String, dynamic> json) {
    return LoginData(
      user: User.fromJson(json['user'] as Map<String, dynamic>),
      token: json['token'] as String,
      tokenType: json['token_type'] as String? ?? 'Bearer',
      expiresAt: json['expires_at'] as String,
      redirectTo: json['redirect_to'] as String,
    );
  }
}

// Login Response Model
class LoginResponse {
  final bool success;
  final String message;
  final LoginData? data;
  final Map<String, dynamic>? errors;
  final bool? requires2FA;
  final Map<String, dynamic>? twoFactorData;

  LoginResponse({
    required this.success,
    required this.message,
    this.data,
    this.errors,
    this.requires2FA,
    this.twoFactorData,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? LoginData.fromJson(json['data']) : null,
      errors: json['errors'],
      requires2FA: json['requires_2fa'],
      twoFactorData: json['requires_2fa'] == true ? {
        'two_factor_method': json['two_factor_method'],
        'session_token': json['session_token'],
        'message': json['message'],
        'data': json['data'],
      } : null,
    );
  }
}

// Forgot Password Request Model
class ForgotPasswordRequest {
  final String email;

  ForgotPasswordRequest({required this.email});

  Map<String, dynamic> toJson() => {'email': email};
}

// Reset Password Request Model
class ResetPasswordRequest {
  final String token;
  final String email;
  final String password;
  final String passwordConfirmation;

  ResetPasswordRequest({
    required this.token,
    required this.email,
    required this.password,
    required this.passwordConfirmation,
  });

  Map<String, dynamic> toJson() => {
        'token': token,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      };
}

// Registration Request Model
class RegisterRequest {
  final String name;
  final String email;
  final String phone;
  final String? countryCode;
  final String password;
  final String passwordConfirmation;
  final String role;
  final String? licenseNumber;
  final String? specialization;

  RegisterRequest({
    required this.name,
    required this.email,
    required this.phone,
    this.countryCode,
    required this.password,
    required this.passwordConfirmation,
    required this.role,
    this.licenseNumber,
    this.specialization,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'password_confirmation': passwordConfirmation,
      'role': role,
    };

    if (countryCode != null) {
      data['country_code'] = countryCode;
    }
    if (licenseNumber != null && licenseNumber!.isNotEmpty) {
      data['license_number'] = licenseNumber;
    }
    if (specialization != null && specialization!.isNotEmpty) {
      data['specialization'] = specialization;
    }

    return data;
  }
}

// Callback Request Model (for Get Started flow)
class CallbackRequest {
  final String name;
  final String email;
  final String phone;
  final String countryCode;
  final String role;
  final String? nursePin;
  final String? ghanaCardNumber;
  final File? ghanaCardFront;
  final File? ghanaCardBack;
  final File? nursePinFront;
  final File? nursePinBack;

  CallbackRequest({
    required this.name,
    required this.email,
    required this.phone,
    this.countryCode = '+233',
    required this.role,
    this.nursePin,
    this.ghanaCardNumber,
    this.ghanaCardFront,
    this.ghanaCardBack,
    this.nursePinFront,
    this.nursePinBack,
  });

  bool get isValid {
    if (name.trim().isEmpty || email.trim().isEmpty || phone.trim().isEmpty) {
      return false;
    }
    if (role == 'nurse') {
      if (nursePin == null || nursePin!.trim().isEmpty) return false;
      if (ghanaCardNumber == null || ghanaCardNumber!.trim().isEmpty) return false;
      if (ghanaCardFront == null || ghanaCardBack == null) return false;
      if (nursePinFront == null || nursePinBack == null) return false;
    }
    return true;
  }

  String? get validationError {
    if (name.trim().isEmpty) return 'Name is required';
    if (email.trim().isEmpty) return 'Email is required';
    if (phone.trim().isEmpty) return 'Phone number is required';
    if (role == 'nurse') {
      if (nursePin == null || nursePin!.trim().isEmpty) return 'Nurse PIN is required';
      if (ghanaCardNumber == null || ghanaCardNumber!.trim().isEmpty) return 'Ghana Card number is required';
      if (ghanaCardFront == null || ghanaCardBack == null) return 'Both sides of Ghana Card are required';
      if (nursePinFront == null || nursePinBack == null) return 'Both sides of Nurse PIN Card are required';
    }
    return null;
  }
}

// Callback Response Model
class CallbackResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  final Map<String, dynamic>? errors;

  CallbackResponse({
    required this.success,
    required this.message,
    this.data,
    this.errors,
  });

  factory CallbackResponse.fromJson(Map<String, dynamic> json) {
    return CallbackResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] as Map<String, dynamic>?,
      errors: json['errors'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic>? get userData => data?['user'] as Map<String, dynamic>?;

  List<String> get nextSteps {
    if (data?['next_steps'] != null) {
      return List<String>.from(data!['next_steps']);
    }
    return [];
  }

  String? get firstError {
    if (errors == null || errors!.isEmpty) return null;
    final firstKey = errors!.keys.first;
    final firstValue = errors![firstKey];
    if (firstValue is List && firstValue.isNotEmpty) {
      return firstValue.first.toString();
    }
    return firstValue?.toString();
  }

  List<String> get allErrors {
    if (errors == null || errors!.isEmpty) return [];
    final errorList = <String>[];
    errors!.forEach((key, value) {
      if (value is List) {
        errorList.addAll(value.map((e) => e.toString()));
      } else {
        errorList.add(value.toString());
      }
    });
    return errorList;
  }
}

// Registration User Data
class RegisteredUser {
  final int id;
  final String name;
  final String email;
  final String role;
  final String verificationStatus;
  final bool requiresApproval;

  RegisteredUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.verificationStatus,
    required this.requiresApproval,
  });

  factory RegisteredUser.fromJson(Map<String, dynamic> json) {
    return RegisteredUser(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      verificationStatus: json['verification_status'] as String,
      requiresApproval: json['requires_approval'] as bool? ?? false,
    );
  }
}

// Registration Response Model
class RegisterResponse {
  final bool success;
  final String message;
  final RegisteredUser? user;
  final Map<String, dynamic>? errors;

  RegisterResponse({
    required this.success,
    required this.message,
    this.user,
    this.errors,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      user: json['data'] != null && json['data']['user'] != null
          ? RegisteredUser.fromJson(json['data']['user'] as Map<String, dynamic>)
          : null,
      errors: json['errors'] as Map<String, dynamic>?,
    );
  }
}