import 'package:flutter/foundation.dart';

// Progress Note Request Model
class CreateProgressNoteRequest {
  final String visitDate;
  final String visitTime;
  final ProgressNoteVitals? vitals;
  final ProgressNoteInterventions? interventions;
  final String generalCondition;
  final int painLevel;
  final String? woundStatus;
  final String? otherObservations;
  final String? educationProvided;
  final String? familyConcerns;
  final String? nextSteps;

  CreateProgressNoteRequest({
    required this.visitDate,
    required this.visitTime,
    this.vitals,
    this.interventions,
    required this.generalCondition,
    required this.painLevel,
    this.woundStatus,
    this.otherObservations,
    this.educationProvided,
    this.familyConcerns,
    this.nextSteps,
  });

  Map<String, dynamic> toJson() {
    return {
      'visit_date': visitDate,
      'visit_time': visitTime,
      if (vitals != null) 'vitals': vitals!.toJson(),
      if (interventions != null) 'interventions': interventions!.toJson(),
      'general_condition': generalCondition,
      'pain_level': painLevel,
      if (woundStatus != null && woundStatus!.isNotEmpty) 
        'wound_status': woundStatus,
      if (otherObservations != null && otherObservations!.isNotEmpty) 
        'other_observations': otherObservations,
      if (educationProvided != null && educationProvided!.isNotEmpty) 
        'education_provided': educationProvided,
      if (familyConcerns != null && familyConcerns!.isNotEmpty) 
        'family_concerns': familyConcerns,
      if (nextSteps != null && nextSteps!.isNotEmpty) 
        'next_steps': nextSteps,
    };
  }
}

// Vitals Model
class ProgressNoteVitals {
  final double? temperature;
  final int? pulse;
  final int? respiration;
  final String? bloodPressure;
  final int? spo2;

  ProgressNoteVitals({
    this.temperature,
    this.pulse,
    this.respiration,
    this.bloodPressure,
    this.spo2,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (temperature != null) map['temperature'] = temperature;
    if (pulse != null) map['pulse'] = pulse;
    if (respiration != null) map['respiration'] = respiration;
    if (bloodPressure != null && bloodPressure!.isNotEmpty) {
      map['blood_pressure'] = bloodPressure;
    }
    if (spo2 != null) map['spo2'] = spo2;
    return map;
  }
}

// Interventions Model
class ProgressNoteInterventions {
  final bool medicationAdministered;
  final String? medicationDetails;
  final bool woundCare;
  final String? woundCareDetails;
  final bool physiotherapy;
  final String? physiotherapyDetails;
  final bool nutritionSupport;
  final String? nutritionDetails;
  final bool hygieneCare;
  final String? hygieneDetails;
  final bool counseling;
  final String? counselingDetails;
  final bool otherInterventions;
  final String? otherDetails;

  ProgressNoteInterventions({
    this.medicationAdministered = false,
    this.medicationDetails,
    this.woundCare = false,
    this.woundCareDetails,
    this.physiotherapy = false,
    this.physiotherapyDetails,
    this.nutritionSupport = false,
    this.nutritionDetails,
    this.hygieneCare = false,
    this.hygieneDetails,
    this.counseling = false,
    this.counselingDetails,
    this.otherInterventions = false,
    this.otherDetails,
  });

  Map<String, dynamic> toJson() {
    return {
      'medication_administered': medicationAdministered,
      if (medicationDetails != null && medicationDetails!.isNotEmpty)
        'medication_details': medicationDetails,
      'wound_care': woundCare,
      if (woundCareDetails != null && woundCareDetails!.isNotEmpty)
        'wound_care_details': woundCareDetails,
      'physiotherapy': physiotherapy,
      if (physiotherapyDetails != null && physiotherapyDetails!.isNotEmpty)
        'physiotherapy_details': physiotherapyDetails,
      'nutrition_support': nutritionSupport,
      if (nutritionDetails != null && nutritionDetails!.isNotEmpty)
        'nutrition_details': nutritionDetails,
      'hygiene_care': hygieneCare,
      if (hygieneDetails != null && hygieneDetails!.isNotEmpty)
        'hygiene_details': hygieneDetails,
      'counseling': counseling,
      if (counselingDetails != null && counselingDetails!.isNotEmpty)
        'counseling_details': counselingDetails,
      'other_interventions': otherInterventions,
      if (otherDetails != null && otherDetails!.isNotEmpty)
        'other_details': otherDetails,
    };
  }
}

// Progress Note Response Model
class CreateProgressNoteResponse {
  final bool success;
  final String message;
  final ProgressNoteData? data;
  final Map<String, dynamic>? errors;

  CreateProgressNoteResponse({
    required this.success,
    required this.message,
    this.data,
    this.errors,
  });

  factory CreateProgressNoteResponse.fromJson(Map<String, dynamic> json) {
    try {
      debugPrint('🔍 Parsing CreateProgressNoteResponse');
      debugPrint('🔍 JSON keys: ${json.keys.toList()}');
      
      return CreateProgressNoteResponse(
        success: json['success'] as bool? ?? false,
        message: json['message'] as String? ?? '',
        data: json['data'] != null 
            ? ProgressNoteData.fromJson(json['data'] as Map<String, dynamic>)
            : null,
        errors: json['errors'] as Map<String, dynamic>?,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error parsing CreateProgressNoteResponse: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }
}

// Progress Note Data Model
class ProgressNoteData {
  final int id;
  final ProgressNotePatient patient;
  final ProgressNoteNurse? nurse; // FIXED: Made nullable
  final String visitDate;
  final String visitTime;
  final String generalCondition;
  final int painLevel;
  final String createdAt;
  final Map<String, dynamic>? vitals;
  final Map<String, dynamic>? interventions;
  final String? woundStatus;
  final String? otherObservations;
  final String? educationProvided;
  final String? familyConcerns;
  final String? nextSteps;

  ProgressNoteData({
    required this.id,
    required this.patient,
    this.nurse, // FIXED: Made nullable
    required this.visitDate,
    required this.visitTime,
    required this.generalCondition,
    required this.painLevel,
    required this.createdAt,
    this.vitals,
    this.interventions,
    this.woundStatus,
    this.otherObservations,
    this.educationProvided,
    this.familyConcerns,
    this.nextSteps,
  });

  factory ProgressNoteData.fromJson(Map<String, dynamic> json) {
    try {
      debugPrint('🔍 Parsing ProgressNoteData');
      debugPrint('🔍 Data keys: ${json.keys.toList()}');
      debugPrint('🔍 Has nurse field: ${json.containsKey('nurse')}');
      debugPrint('🔍 Nurse value: ${json['nurse']}');
      
      return ProgressNoteData(
        id: json['id'] as int,
        patient: ProgressNotePatient.fromJson(json['patient'] as Map<String, dynamic>),
        // FIXED: Handle null nurse field
        nurse: json['nurse'] != null && json['nurse'] is Map
            ? ProgressNoteNurse.fromJson(json['nurse'] as Map<String, dynamic>)
            : null,
        visitDate: json['visit_date'] as String,
        visitTime: json['visit_time'] as String,
        generalCondition: json['general_condition'] as String,
        painLevel: json['pain_level'] as int,
        createdAt: json['created_at'] as String,
        vitals: json['vitals'] as Map<String, dynamic>?,
        interventions: json['interventions'] as Map<String, dynamic>?,
        woundStatus: json['wound_status'] as String?,
        otherObservations: json['other_observations'] as String?,
        educationProvided: json['education_provided'] as String?,
        familyConcerns: json['family_concerns'] as String?,
        nextSteps: json['next_steps'] as String?,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error parsing ProgressNoteData: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      debugPrint('❌ JSON: $json');
      rethrow;
    }
  }
}

// Helper Models
class ProgressNotePatient {
  final int id;
  final String name;

  ProgressNotePatient({
    required this.id,
    required this.name,
  });

  factory ProgressNotePatient.fromJson(Map<String, dynamic> json) {
    return ProgressNotePatient(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

class ProgressNoteNurse {
  final int id;
  final String name;

  ProgressNoteNurse({
    required this.id,
    required this.name,
  });

  factory ProgressNoteNurse.fromJson(Map<String, dynamic> json) {
    return ProgressNoteNurse(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}