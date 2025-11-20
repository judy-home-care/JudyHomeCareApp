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

      // ✅ New fields
      phone: json['phone'] as String?,
      gender: json['gender'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      ghanaCardNumber: json['ghana_card_number'] as String?,
      licenseNumber: json['license_number'] as String?,
      specialization: json['specialization'] as String?,
      yearsOfExperience: json['years_of_experience'] != null
          ? (json['years_of_experience'] as num).toInt()
          : null,
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

        // ✅ New fields
        'phone': phone,
        'gender': gender,
        'date_of_birth': dateOfBirth,
        'ghana_card_number': ghanaCardNumber,
        'license_number': licenseNumber,
        'specialization': specialization,
        'years_of_experience': yearsOfExperience,
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

  Map<String, dynamic> toJson() => {
        'email': email,
      };
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

    // Only add license_number and specialization if they're not null
    if (licenseNumber != null && licenseNumber!.isNotEmpty) {
      data['license_number'] = licenseNumber;
    }
    if (specialization != null && specialization!.isNotEmpty) {
      data['specialization'] = specialization;
    }

    return data;
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
