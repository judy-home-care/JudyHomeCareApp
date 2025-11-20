// Medical Assessment Request Model
class MedicalAssessmentRequest {
  // NEW: Care Request ID (optional - for linking to care requests)
  final int? careRequestId;
  
  // Patient selection
  final bool isNewPatient;
  final int? patientId;
  
  // New patient fields (required if isNewPatient = true)
  final String? patientFirstName;
  final String? patientLastName;
  final String? patientPhone;
  final String? patientDateOfBirth;
  final String? patientGender;
  final String? patientGhanaCard;
  
  // Nurse
  final int nurseId;
  
  // Client Information
  final String physicalAddress;
  final String? occupation;
  final String? religion;
  
  // Emergency Contacts
  final String emergencyContact1Name;
  final String emergencyContact1Relationship;
  final String emergencyContact1Phone;
  final String? emergencyContact2Name;
  final String? emergencyContact2Relationship;
  final String? emergencyContact2Phone;
  
  // Medical History
  final String presentingCondition;
  final String? pastMedicalHistory;
  final String? allergies;
  final String? currentMedications;
  final String? specialNeeds;
  
  // Initial Assessment
  final String generalCondition; // stable, unstable
  final String hydrationStatus; // adequate, dehydrated
  final String nutritionStatus; // adequate, malnourished
  final String mobilityStatus; // independent, assisted, bedridden
  final bool hasWounds;
  final String? woundDescription;
  final int painLevel; // 0-10
  
  // Vital Signs
  final Map<String, dynamic> initialVitals;
  
  // Nursing Impression
  final String initialNursingImpression;

  MedicalAssessmentRequest({
    this.careRequestId, // NEW FIELD - Add this parameter
    required this.isNewPatient,
    this.patientId,
    this.patientFirstName,
    this.patientLastName,
    this.patientPhone,
    this.patientDateOfBirth,
    this.patientGender,
    this.patientGhanaCard,
    required this.nurseId,
    required this.physicalAddress,
    this.occupation,
    this.religion,
    required this.emergencyContact1Name,
    required this.emergencyContact1Relationship,
    required this.emergencyContact1Phone,
    this.emergencyContact2Name,
    this.emergencyContact2Relationship,
    this.emergencyContact2Phone,
    required this.presentingCondition,
    this.pastMedicalHistory,
    this.allergies,
    this.currentMedications,
    this.specialNeeds,
    required this.generalCondition,
    required this.hydrationStatus,
    required this.nutritionStatus,
    required this.mobilityStatus,
    required this.hasWounds,
    this.woundDescription,
    required this.painLevel,
    required this.initialVitals,
    required this.initialNursingImpression,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'is_new_patient': isNewPatient,
      'nurse_id': nurseId,
      'physical_address': physicalAddress,
      'emergency_contact_1_name': emergencyContact1Name,
      'emergency_contact_1_relationship': emergencyContact1Relationship,
      'emergency_contact_1_phone': emergencyContact1Phone,
      'presenting_condition': presentingCondition,
      'general_condition': generalCondition,
      'hydration_status': hydrationStatus,
      'nutrition_status': nutritionStatus,
      'mobility_status': mobilityStatus,
      'has_wounds': hasWounds,
      'pain_level': painLevel,
      'initial_vitals': initialVitals,
      'initial_nursing_impression': initialNursingImpression,
    };

    // NEW: Add care_request_id if provided
    if (careRequestId != null) {
      data['care_request_id'] = careRequestId;
    }

    // Add patient selection
    if (isNewPatient) {
      data['patient_first_name'] = patientFirstName;
      data['patient_last_name'] = patientLastName;
      data['patient_phone'] = patientPhone;
      data['patient_date_of_birth'] = patientDateOfBirth;
      data['patient_gender'] = patientGender;
      data['patient_ghana_card'] = patientGhanaCard;
    } else {
      data['patient_id'] = patientId;
    }

    // Add optional fields
    if (occupation != null) data['occupation'] = occupation;
    if (religion != null) data['religion'] = religion;
    if (emergencyContact2Name != null) data['emergency_contact_2_name'] = emergencyContact2Name;
    if (emergencyContact2Relationship != null) data['emergency_contact_2_relationship'] = emergencyContact2Relationship;
    if (emergencyContact2Phone != null) data['emergency_contact_2_phone'] = emergencyContact2Phone;
    if (pastMedicalHistory != null) data['past_medical_history'] = pastMedicalHistory;
    if (allergies != null) data['allergies'] = allergies;
    if (currentMedications != null) data['current_medications'] = currentMedications;
    if (specialNeeds != null) data['special_needs'] = specialNeeds;
    if (woundDescription != null) data['wound_description'] = woundDescription;

    return data;
  }
}

// Medical Assessment Response Model
class MedicalAssessmentResponse {
  final bool success;
  final String message;
  final MedicalAssessment? data;
  final Map<String, dynamic>? errors;

  MedicalAssessmentResponse({
    required this.success,
    required this.message,
    this.data,
    this.errors,
  });

  factory MedicalAssessmentResponse.fromJson(Map<String, dynamic> json) {
    return MedicalAssessmentResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null 
          ? MedicalAssessment.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      errors: json['errors'] as Map<String, dynamic>?,
    );
  }
}

// Medical Assessment Model
class MedicalAssessment {
  final int id;
  final int? careRequestId; // NEW FIELD - Add this
  final int patientId;
  final int nurseId;
  final String patientName;
  final String nurseName;
  final String physicalAddress;
  final String? occupation;
  final String? religion;
  final String emergencyContact1Name;
  final String emergencyContact1Relationship;
  final String emergencyContact1Phone;
  final String? emergencyContact2Name;
  final String? emergencyContact2Relationship;
  final String? emergencyContact2Phone;
  final String presentingCondition;
  final String? pastMedicalHistory;
  final String? allergies;
  final String? currentMedications;
  final String? specialNeeds;
  final String generalCondition;
  final String hydrationStatus;
  final String nutritionStatus;
  final String mobilityStatus;
  final bool hasWounds;
  final String? woundDescription;
  final int painLevel;
  final Map<String, dynamic> initialVitals;
  final String initialNursingImpression;
  final String assessmentStatus;
  final String createdAt;

  MedicalAssessment({
    required this.id,
    this.careRequestId, // NEW FIELD - Add this parameter
    required this.patientId,
    required this.nurseId,
    required this.patientName,
    required this.nurseName,
    required this.physicalAddress,
    this.occupation,
    this.religion,
    required this.emergencyContact1Name,
    required this.emergencyContact1Relationship,
    required this.emergencyContact1Phone,
    this.emergencyContact2Name,
    this.emergencyContact2Relationship,
    this.emergencyContact2Phone,
    required this.presentingCondition,
    this.pastMedicalHistory,
    this.allergies,
    this.currentMedications,
    this.specialNeeds,
    required this.generalCondition,
    required this.hydrationStatus,
    required this.nutritionStatus,
    required this.mobilityStatus,
    required this.hasWounds,
    this.woundDescription,
    required this.painLevel,
    required this.initialVitals,
    required this.initialNursingImpression,
    required this.assessmentStatus,
    required this.createdAt,
  });

  factory MedicalAssessment.fromJson(Map<String, dynamic> json) {
    return MedicalAssessment(
      id: json['id'] as int? ?? 0,
      careRequestId: json['care_request_id'] as int?, // NEW FIELD - Parse from JSON
      patientId: json['patient_id'] as int? ?? 0,
      nurseId: json['nurse_id'] as int? ?? 0,
      patientName: json['patient_name'] as String? ?? '',
      nurseName: json['nurse_name'] as String? ?? '',
      physicalAddress: json['physical_address'] as String? ?? '',
      occupation: json['occupation'] as String?,
      religion: json['religion'] as String?,
      emergencyContact1Name: json['emergency_contact_1_name'] as String? ?? '',
      emergencyContact1Relationship: json['emergency_contact_1_relationship'] as String? ?? '',
      emergencyContact1Phone: json['emergency_contact_1_phone'] as String? ?? '',
      emergencyContact2Name: json['emergency_contact_2_name'] as String?,
      emergencyContact2Relationship: json['emergency_contact_2_relationship'] as String?,
      emergencyContact2Phone: json['emergency_contact_2_phone'] as String?,
      presentingCondition: json['presenting_condition'] as String? ?? '',
      pastMedicalHistory: json['past_medical_history'] as String?,
      allergies: json['allergies'] as String?,
      currentMedications: json['current_medications'] as String?,
      specialNeeds: json['special_needs'] as String?,
      generalCondition: json['general_condition'] as String? ?? 'stable',
      hydrationStatus: json['hydration_status'] as String? ?? 'adequate',
      nutritionStatus: json['nutrition_status'] as String? ?? 'adequate',
      mobilityStatus: json['mobility_status'] as String? ?? 'independent',
      hasWounds: json['has_wounds'] as bool? ?? false,
      woundDescription: json['wound_description'] as String?,
      painLevel: json['pain_level'] as int? ?? 0,
      initialVitals: (json['initial_vitals'] as Map<String, dynamic>?) ?? {},
      initialNursingImpression: json['initial_nursing_impression'] as String? ?? '',
      assessmentStatus: json['assessment_status'] as String? ?? 'completed',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
  
  /// Helper method to check if this assessment is linked to a care request
  bool get isLinkedToCareRequest => careRequestId != null;
}

// Patient for dropdown selection
class PatientOption {
  final int id;
  final String name;
  final String? ghanaCard;
  final String? phone;
  final int? age;

  PatientOption({
    required this.id,
    required this.name,
    this.ghanaCard,
    this.phone,
    this.age,
  });

  factory PatientOption.fromJson(Map<String, dynamic> json) {
    return PatientOption(
      id: json['id'] as int,
      name: json['name'] as String,
      ghanaCard: json['ghanaCard'] as String?,
      phone: json['phone'] as String?,
      age: json['age'] as int?,
    );
  }
}