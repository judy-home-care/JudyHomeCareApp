/// Contact Person Models
/// Models for contact person authentication and patient access

class ContactPersonUser {
  final int id;
  final String name;
  final String phone;
  final String? email;
  final String? avatar;
  final List<LinkedPatient> linkedPatients;

  ContactPersonUser({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.avatar,
    required this.linkedPatients,
  });

  factory ContactPersonUser.fromJson(Map<String, dynamic> json) {
    // Handle both camelCase and snake_case API responses
    final patientsData = json['linkedPatients'] ?? json['linked_patients'] ?? json['patients'] ?? [];

    // Build name from various possible fields
    String name = json['name'] ?? json['full_name'] ?? '';
    if (name.isEmpty) {
      final firstName = json['first_name'] ?? '';
      final lastName = json['last_name'] ?? '';
      name = '$firstName $lastName'.trim();
    }

    return ContactPersonUser(
      id: json['id'] ?? 0,
      name: name,
      phone: json['phone'] ?? json['phone_number'] ?? '',
      email: json['email'],
      avatar: json['avatar'] ?? json['avatar_url'] ?? json['profile_image'] ?? json['photo'],
      linkedPatients: (patientsData as List?)
              ?.map((p) => LinkedPatient.fromJson(p))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'avatar': avatar,
      'linkedPatients': linkedPatients.map((p) => p.toJson()).toList(),
    };
  }
}

class LinkedPatient {
  final int id;
  final String name;
  final int age;
  final String? phone;
  final String? avatar;
  final String relationship;
  final bool isPrimary;

  LinkedPatient({
    required this.id,
    required this.name,
    required this.age,
    this.phone,
    this.avatar,
    required this.relationship,
    required this.isPrimary,
  });

  factory LinkedPatient.fromJson(Map<String, dynamic> json) {
    // Handle both camelCase and snake_case API responses
    // Handle is_primary as bool or int (0/1)
    final isPrimaryValue = json['isPrimary'] ?? json['is_primary'];
    final isPrimary = isPrimaryValue == true || isPrimaryValue == 1;

    return LinkedPatient(
      id: json['id'] ?? json['patient_id'] ?? 0,
      name: json['name'] ?? json['full_name'] ?? json['patient_name'] ?? '',
      age: json['age'] ?? 0,
      phone: json['phone'] ?? json['phone_number'],
      avatar: json['avatar'] ?? json['avatar_url'] ?? json['profile_image'] ?? json['photo'],
      relationship: json['relationship'] ?? json['relation'] ?? 'Contact',
      isPrimary: isPrimary,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'phone': phone,
      'avatar': avatar,
      'relationship': relationship,
      'isPrimary': isPrimary,
    };
  }
}

class ContactPersonLoginResponse {
  final bool success;
  final String message;
  final String? otpReference;

  ContactPersonLoginResponse({
    required this.success,
    required this.message,
    this.otpReference,
  });

  factory ContactPersonLoginResponse.fromJson(Map<String, dynamic> json) {
    return ContactPersonLoginResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      otpReference: json['otpReference'],
    );
  }
}

class ContactPersonVerifyOtpResponse {
  final bool success;
  final String message;
  final String? token;
  final ContactPersonUser? user;

  ContactPersonVerifyOtpResponse({
    required this.success,
    required this.message,
    this.token,
    this.user,
  });

  factory ContactPersonVerifyOtpResponse.fromJson(Map<String, dynamic> json) {
    // Handle various API response structures
    final data = json['data'] as Map<String, dynamic>?;

    // Try to find token in various locations
    String? token = json['token'] ?? data?['token'];

    // Try to find user in various locations
    Map<String, dynamic>? userData;
    if (json['user'] != null) {
      userData = json['user'] as Map<String, dynamic>;
    } else if (json['contact_person'] != null) {
      userData = json['contact_person'] as Map<String, dynamic>;
    } else if (json['contactPerson'] != null) {
      userData = json['contactPerson'] as Map<String, dynamic>;
    } else if (data?['user'] != null) {
      userData = data!['user'] as Map<String, dynamic>;
    } else if (data?['contact_person'] != null) {
      userData = data!['contact_person'] as Map<String, dynamic>;
    } else if (data?['contactPerson'] != null) {
      userData = data!['contactPerson'] as Map<String, dynamic>;
    } else if (data != null && data['id'] != null) {
      // The data object itself might be the user
      userData = data;
    }

    // Extract patients - they might be at data level, not inside user
    List<dynamic>? patientsData;
    if (data?['patients'] != null) {
      patientsData = data!['patients'] as List;
    } else if (json['patients'] != null) {
      patientsData = json['patients'] as List;
    }

    // If we found user data and patients data separately, merge them
    ContactPersonUser? user;
    if (userData != null) {
      // Create a copy of userData with patients included
      final mergedUserData = Map<String, dynamic>.from(userData);
      if (patientsData != null && mergedUserData['linkedPatients'] == null &&
          mergedUserData['linked_patients'] == null && mergedUserData['patients'] == null) {
        mergedUserData['patients'] = patientsData;
      }
      user = ContactPersonUser.fromJson(mergedUserData);
    }

    return ContactPersonVerifyOtpResponse(
      success: json['success'] ?? json['status'] == 'success' ?? false,
      message: json['message'] ?? data?['message'] ?? '',
      token: token,
      user: user,
    );
  }
}

class PatientDetail {
  final int id;
  final String name;
  final int age;
  final String? phone;
  final String? email;
  final String? avatar;
  final String? address;
  final String? bloodType;
  final String? allergies;
  final String? medicalConditions;
  final EmergencyContactInfo? emergencyContact;

  PatientDetail({
    required this.id,
    required this.name,
    required this.age,
    this.phone,
    this.email,
    this.avatar,
    this.address,
    this.bloodType,
    this.allergies,
    this.medicalConditions,
    this.emergencyContact,
  });

  factory PatientDetail.fromJson(Map<String, dynamic> json) {
    return PatientDetail(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      age: json['age'] ?? 0,
      phone: json['phone'],
      email: json['email'],
      avatar: json['avatar'],
      address: json['address'],
      bloodType: json['bloodType'],
      allergies: json['allergies'],
      medicalConditions: json['medicalConditions'],
      emergencyContact: json['emergencyContact'] != null
          ? EmergencyContactInfo.fromJson(json['emergencyContact'])
          : null,
    );
  }
}

class EmergencyContactInfo {
  final String? name;
  final String? phone;
  final String? relationship;

  EmergencyContactInfo({
    this.name,
    this.phone,
    this.relationship,
  });

  factory EmergencyContactInfo.fromJson(Map<String, dynamic> json) {
    return EmergencyContactInfo(
      name: json['name'],
      phone: json['phone'],
      relationship: json['relationship'],
    );
  }
}
