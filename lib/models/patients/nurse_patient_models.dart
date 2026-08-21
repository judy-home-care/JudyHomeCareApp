import 'package:flutter/foundation.dart';
import 'package:Judy_Home_HealthCare/models/care_plans/care_plan_models.dart' show CarePlanEntry;

// Response model for nurse patients list with pagination
class NursePatientsResponse {
  final bool success;
  final List<Patient> data;
  final int total;
  final int perPage;
  final int currentPage;
  final int lastPage;
  final int? from;
  final int? to;
  final Map<String, int>? counts;
  final String? message;

  NursePatientsResponse({
    required this.success,
    required this.data,
    required this.total,
    required this.perPage,
    required this.currentPage,
    required this.lastPage,
    this.from,
    this.to,
    this.counts,
    this.message,
  });

  factory NursePatientsResponse.fromJson(Map<String, dynamic> json) {
    try {
      // Helper to safely parse int values
      int? safeParseInt(dynamic value) {
        if (value == null) return null;
        if (value is int) return value;
        if (value is String) return int.tryParse(value);
        return null;
      }

      return NursePatientsResponse(
        success: json['success'] as bool? ?? false,
        data: (json['data'] as List<dynamic>?)
                ?.map((e) => Patient.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        total: safeParseInt(json['total']) ?? 0,
        perPage: safeParseInt(json['per_page']) ?? 15,
        currentPage: safeParseInt(json['current_page']) ?? 1,
        lastPage: safeParseInt(json['last_page']) ?? 1,
        from: safeParseInt(json['from']),
        to: safeParseInt(json['to']),
        counts: json['counts'] != null 
            ? Map<String, int>.from(json['counts'] as Map)
            : null,
        message: json['message']?.toString(),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error parsing NursePatientsResponse: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('JSON data: $json');
      rethrow;
    }
  }
}

// Patient model
class Patient {
  final int id;
  final String name;
  final int? age;
  final String careType;
  final String condition;
  final int carePlanId;
  final String carePlanTitle;
  final String? lastVisit;
  final String? nextVisit;
  final String status;
  final String priority;
  final PatientVitals vitals;
  final String address;
  final String? phone;
  final String emergencyContact;
  final String emergencyPhone;
  final String avatar;

  Patient({
    required this.id,
    required this.name,
    this.age,
    required this.careType,
    required this.condition,
    required this.carePlanId,
    required this.carePlanTitle,
    this.lastVisit,
    this.nextVisit,
    required this.status,
    required this.priority,
    required this.vitals,
    required this.address,
    this.phone,
    required this.emergencyContact,
    required this.emergencyPhone,
    required this.avatar,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    try {
      // Helper functions for safe parsing
      int? safeParseInt(dynamic value) {
        if (value == null) return null;
        if (value is int) return value;
        if (value is String) return int.tryParse(value);
        return null;
      }

      String? safeParseString(dynamic value) {
        if (value == null) return null;
        return value.toString();
      }

      // Parse vitals with fallback to default values
      PatientVitals vitals;
      if (json['vitals'] != null && json['vitals'] is Map) {
        vitals = PatientVitals.fromJson(json['vitals'] as Map<String, dynamic>);
      } else {
        // Create default vitals if missing or invalid
        vitals = PatientVitals(
          bloodPressure: 'N/A',
          pulse: 'N/A',
          temperature: 'N/A',
          spo2: 'N/A',
          respiration: 'N/A',
          recordedAt: null,
        );
      }

      return Patient(
        id: safeParseInt(json['id']) ?? 0,
        name: safeParseString(json['name']) ?? 'Unknown Patient',
        age: safeParseInt(json['age']),
        careType: safeParseString(json['careType']) ?? 'General Care',
        condition: safeParseString(json['condition']) ?? 'No condition specified',
        carePlanId: safeParseInt(json['carePlanId']) ?? 0,
        carePlanTitle: safeParseString(json['carePlanTitle']) ?? 'Care Plan',
        lastVisit: safeParseString(json['lastVisit']),
        nextVisit: safeParseString(json['nextVisit']),
        status: safeParseString(json['status']) ?? 'Active',
        priority: safeParseString(json['priority']) ?? 'Medium',
        vitals: vitals,
        address: safeParseString(json['address']) ?? 'Address not provided',
        phone: safeParseString(json['phone']),
        emergencyContact: safeParseString(json['emergencyContact']) ?? 'Not provided',
        emergencyPhone: safeParseString(json['emergencyPhone']) ?? 'Not provided',
        avatar: safeParseString(json['avatar']) ?? '',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error parsing Patient JSON: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('JSON data: $json');
      rethrow;
    }
  }

  // Helper to get DateTime from lastVisit
  DateTime? get lastVisitDateTime {
    if (lastVisit == null) return null;
    try {
      return DateTime.parse(lastVisit!);
    } catch (e) {
      debugPrint('Error parsing lastVisit date: $e');
      return null;
    }
  }

  // Helper to get DateTime from nextVisit
  DateTime? get nextVisitDateTime {
    if (nextVisit == null) return null;
    try {
      return DateTime.parse(nextVisit!);
    } catch (e) {
      debugPrint('Error parsing nextVisit date: $e');
      return null;
    }
  }
}

// Patient Vitals model
class PatientVitals {
  final String bloodPressure;
  final String pulse;
  final String temperature;
  final String spo2;
  final String respiration;
  final String? recordedAt;

  PatientVitals({
    required this.bloodPressure,
    required this.pulse,
    required this.temperature,
    required this.spo2,
    required this.respiration,
    this.recordedAt,
  });

  factory PatientVitals.fromJson(Map<String, dynamic> json) {
    try {
      return PatientVitals(
        bloodPressure: _parseVitalValue(json['blood_pressure']),
        pulse: _parseVitalValue(json['pulse'] ?? json['heart_rate']), // Handle both keys
        temperature: _parseVitalValue(json['temperature']),
        spo2: _parseVitalValue(json['spo2']),
        respiration: _parseVitalValue(json['respiration']),
        recordedAt: json['recordedAt']?.toString(),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error parsing PatientVitals JSON: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('JSON data: $json');
      // Return default vitals instead of crashing
      return PatientVitals(
        bloodPressure: 'N/A',
        pulse: 'N/A',
        temperature: 'N/A',
        spo2: 'N/A',
        respiration: 'N/A',
        recordedAt: null,
      );
    }
  }

  /// Helper method to parse vital values that can be String, int, double, or null
  static String _parseVitalValue(dynamic value) {
    if (value == null) return 'N/A';
    
    // If it's already a string, return it
    if (value is String) {
      return value.isEmpty ? 'N/A' : value;
    }
    
    // If it's a number (int or double), convert to string
    if (value is num) {
      // For temperature, keep one decimal place if it's a double
      if (value is double) {
        return value.toStringAsFixed(1);
      }
      return value.toString();
    }
    
    // Fallback for any other type
    return value.toString();
  }
}

// Response model for patient detail
class PatientDetailResponse {
  final bool success;
  final PatientDetail data;

  PatientDetailResponse({
    required this.success,
    required this.data,
  });

  factory PatientDetailResponse.fromJson(Map<String, dynamic> json) {
    try {
      return PatientDetailResponse(
        success: json['success'] as bool? ?? false,
        data: PatientDetail.fromJson(json['data'] as Map<String, dynamic>),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error parsing PatientDetailResponse: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('JSON data: $json');
      rethrow;
    }
  }
}

// Detailed patient information
class PatientDetail {
  final int id;
  final String name;
  final int? age;
  final String? dateOfBirth;
  final String? gender;
  final String? phone;
  final String? email;
  final String address;
  final String avatar;
  final EmergencyContact emergencyContact;
  final MedicalInfo medicalInfo;
  final CarePlan carePlan; // Primary care plan for backward compatibility
  final List<CarePlan> carePlans; // NEW: All care plans
  final int carePlansCount; // NEW: Count of care plans
  final Doctor? doctor;
  final PatientVitals? vitals;
  final List<ProgressNote> recentNotes;
  /// Therapy session notes (physiotherapy / speech therapy) for this patient.
  /// Mutable so a newly-saved note can be shown immediately without a refetch.
  final List<TherapyNote> therapyNotes;
  final List<Schedule> schedules;
  final InitialAssessment? initialAssessment;
  /// Present only when viewed by a therapist — their assignment to this patient.
  final TherapistAssignmentInfo? assignment;

  PatientDetail({
    required this.id,
    required this.name,
    this.age,
    this.dateOfBirth,
    this.gender,
    this.phone,
    this.email,
    required this.address,
    required this.avatar,
    required this.emergencyContact,
    required this.medicalInfo,
    required this.carePlan,
    required this.carePlans,
    required this.carePlansCount,
    this.doctor,
    this.vitals,
    required this.recentNotes,
    List<TherapyNote>? therapyNotes,
    required this.schedules,
    this.initialAssessment,
    this.assignment,
  }) : therapyNotes = therapyNotes ?? [];

  factory PatientDetail.fromJson(Map<String, dynamic> json) {
    try {
      // Helper functions
      int? safeParseInt(dynamic value) {
        if (value == null) return null;
        if (value is int) return value;
        if (value is String) return int.tryParse(value);
        return null;
      }

      String? safeParseString(dynamic value) {
        if (value == null) return null;
        return value.toString();
      }

      // Parse primary care plan with null check
      CarePlan? primaryCarePlan;
      if (json['carePlan'] != null && json['carePlan'] is Map) {
        primaryCarePlan = CarePlan.fromJson(json['carePlan'] as Map<String, dynamic>);
      }

      // Parse all care plans (with fallback to single care plan for backward compatibility)
      List<CarePlan> allCarePlans = [];
      if (json['carePlans'] != null && json['carePlans'] is List) {
        allCarePlans = (json['carePlans'] as List<dynamic>)
            .map((e) => CarePlan.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (primaryCarePlan != null) {
        // Fallback to single care plan
        allCarePlans = [primaryCarePlan];
      }

      // If we still don't have a primary care plan, create a default one or use first from list
      if (primaryCarePlan == null && allCarePlans.isNotEmpty) {
        primaryCarePlan = allCarePlans.first;
      } else if (primaryCarePlan == null) {
        // Create a minimal default care plan
        primaryCarePlan = CarePlan(
          id: 0,
          title: 'Care Plan',
          careType: 'General Care',
          priority: 'medium',
          careTasks: [],
          completedTasks: [],
          medications: [],
          vitalMonitoring: [],
          completionPercentage: 0,
        );
      }

      // Parse emergency contact with null check
      EmergencyContact emergencyContact;
      if (json['emergencyContact'] != null && json['emergencyContact'] is Map) {
        emergencyContact = EmergencyContact.fromJson(
            json['emergencyContact'] as Map<String, dynamic>);
      } else {
        // Create default emergency contact
        emergencyContact = EmergencyContact(
          name: 'Not provided',
          phone: 'Not provided',
        );
      }

      // Parse medical info with null check
      MedicalInfo medicalInfo;
      if (json['medicalInfo'] != null && json['medicalInfo'] is Map) {
        medicalInfo = MedicalInfo.fromJson(
            json['medicalInfo'] as Map<String, dynamic>);
      } else {
        // Create default medical info
        medicalInfo = MedicalInfo(
          conditions: [],
          allergies: [],
          currentMedications: [],
        );
      }

      return PatientDetail(
        id: safeParseInt(json['id']) ?? 0,
        name: safeParseString(json['name']) ?? 'Unknown Patient',
        age: safeParseInt(json['age']),
        dateOfBirth: safeParseString(json['dateOfBirth']),
        gender: safeParseString(json['gender']),
        phone: safeParseString(json['phone']),
        email: safeParseString(json['email']),
        address: safeParseString(json['address']) ?? 'Address not provided',
        avatar: safeParseString(json['avatar']) ?? '',
        emergencyContact: emergencyContact,
        medicalInfo: medicalInfo,
        carePlan: primaryCarePlan,
        carePlans: allCarePlans,
        carePlansCount: safeParseInt(json['carePlansCount']) ?? allCarePlans.length,
        doctor: json['doctor'] != null && json['doctor'] is Map
            ? Doctor.fromJson(json['doctor'] as Map<String, dynamic>)
            : null,
        vitals: json['vitals'] != null && json['vitals'] is Map
            ? PatientVitals.fromJson(json['vitals'] as Map<String, dynamic>)
            : null,
        recentNotes: (json['recentNotes'] as List<dynamic>?)
                ?.map((e) => ProgressNote.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        therapyNotes: (json['therapyNotes'] as List<dynamic>?)
                ?.whereType<Map>()
                .map((e) => TherapyNote.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
        schedules: (json['schedules'] as List<dynamic>?)
                ?.map((e) => Schedule.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        initialAssessment: json['initial_assessment'] != null && json['initial_assessment'] is Map
            ? InitialAssessment.fromJson(json['initial_assessment'] as Map<String, dynamic>)
            : null,
        assignment: json['assignment'] != null && json['assignment'] is Map
            ? TherapistAssignmentInfo.fromJson(Map<String, dynamic>.from(json['assignment']))
            : null,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error parsing PatientDetail: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('JSON data: $json');
      rethrow;
    }
  }
}

// Emergency Contact model
class EmergencyContact {
  final String name;
  final String phone;

  EmergencyContact({
    required this.name,
    required this.phone,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name']?.toString() ?? 'Not provided',
      phone: json['phone']?.toString() ?? 'Not provided',
    );
  }
}

// Medical Info model
class MedicalInfo {
  final List<String> conditions;
  final List<String> allergies;
  final List<String> currentMedications;

  MedicalInfo({
    required this.conditions,
    required this.allergies,
    required this.currentMedications,
  });

  factory MedicalInfo.fromJson(Map<String, dynamic> json) {
    return MedicalInfo(
      conditions: (json['conditions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      allergies: (json['allergies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      currentMedications: (json['currentMedications'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

// Care Plan model
class CarePlan {
  final int id;
  final String title;
  final String? description;
  final String careType;
  final String priority;
  final String? startDate;
  final String? endDate;
  final String? frequency;
  final List<String> careTasks;
  List<int> completedTasks;
  final List<String> medications;
  final List<String> vitalMonitoring;
  final String? dietaryRequirements;
  final String? mobilityAssistance;
  final String? specialInstructions;
  final String? emergencyProcedures;
  int completionPercentage;
  final String? status; // NEW: Care plan status
  final Doctor? doctor; // NEW: Doctor assigned to this care plan
  final List<CarePlanEntry> carePlanEntries; // NEW: Care plan entries

  CarePlan({
    required this.id,
    required this.title,
    this.description,
    required this.careType,
    required this.priority,
    this.startDate,
    this.endDate,
    this.frequency,
    required this.careTasks,
    required this.completedTasks,
    required this.medications,
    required this.vitalMonitoring,
    this.dietaryRequirements,
    this.mobilityAssistance,
    this.specialInstructions,
    this.emergencyProcedures,
    required this.completionPercentage,
    this.status,
    this.doctor,
    List<CarePlanEntry>? carePlanEntries,
  }) : carePlanEntries = carePlanEntries ?? [];

  factory CarePlan.fromJson(Map<String, dynamic> json) {
    try {
      // Helper functions
      int? safeParseInt(dynamic value) {
        if (value == null) return null;
        if (value is int) return value;
        if (value is String) return int.tryParse(value);
        return null;
      }

      String? safeParseString(dynamic value) {
        if (value == null) return null;
        return value.toString();
      }

      return CarePlan(
        id: safeParseInt(json['id']) ?? 0,
        title: safeParseString(json['title']) ?? 'Care Plan',
        description: safeParseString(json['description']),
        careType: safeParseString(json['careType']) ?? 'General Care',
        priority: safeParseString(json['priority']) ?? 'medium',
        startDate: safeParseString(json['startDate']),
        endDate: safeParseString(json['endDate']),
        frequency: safeParseString(json['frequency']),
        careTasks: (json['careTasks'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        completedTasks: (json['completedTasks'] as List<dynamic>?)
                ?.map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
                .toList() ??
            [],
        medications: (json['medications'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        vitalMonitoring: (json['vitalMonitoring'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        dietaryRequirements: safeParseString(json['dietaryRequirements']),
        mobilityAssistance: safeParseString(json['mobilityAssistance']),
        specialInstructions: safeParseString(json['specialInstructions']),
        emergencyProcedures: safeParseString(json['emergencyProcedures']),
        completionPercentage: safeParseInt(json['completionPercentage']) ?? 0,
        status: safeParseString(json['status']),
        doctor: json['doctor'] != null
            ? Doctor.fromJson(json['doctor'] as Map<String, dynamic>)
            : null,
        carePlanEntries: (json['care_plan_entries'] as List<dynamic>?)
                ?.map((e) => CarePlanEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error parsing CarePlan: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('JSON data: $json');
      rethrow;
    }
  }
}

// Doctor model
class Doctor {
  final int id;
  final String name;
  final String specialization;

  Doctor({
    required this.id,
    required this.name,
    required this.specialization,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    int? safeParseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    return Doctor(
      id: safeParseInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? 'Unknown Doctor',
      specialization: json['specialization']?.toString() ?? 'General Practice',
    );
  }
}

// Progress Note model
class ProgressNote {
  final int id;
  final String visitDate;
  final String? visitTime;
  final Map<String, dynamic>? vitals;
  final Map<String, dynamic>? interventions;
  final String? generalCondition;
  final int? painLevel;
  final String? woundStatus;
  final String? observations;
  final String? otherObservations;
  final String? interventionsProvided;
  final String? educationProvided;
  final String? familyConcerns;
  final String? nextSteps;
  final String? createdAt;

  ProgressNote({
    required this.id,
    required this.visitDate,
    this.visitTime,
    this.vitals,
    this.interventions,
    this.generalCondition,
    this.painLevel,
    this.woundStatus,
    this.observations,
    this.otherObservations,
    this.interventionsProvided,
    this.educationProvided,
    this.familyConcerns,
    this.nextSteps,
    this.createdAt,
  });

  factory ProgressNote.fromJson(Map<String, dynamic> json) {
    try {
      int? safeParseInt(dynamic value) {
        if (value == null) return null;
        if (value is int) return value;
        if (value is String) return int.tryParse(value);
        return null;
      }

      String? safeParseString(dynamic value) {
        if (value == null) return null;
        return value.toString();
      }

      return ProgressNote(
        id: safeParseInt(json['id']) ?? 0,
        visitDate: safeParseString(json['visit_date'] ?? json['visitDate']) ?? '',
        visitTime: safeParseString(json['visit_time'] ?? json['visitTime']),
        vitals: json['vitals'] as Map<String, dynamic>?,
        interventions: json['interventions'] as Map<String, dynamic>?,
        generalCondition: safeParseString(json['general_condition'] ?? json['generalCondition']),
        painLevel: safeParseInt(json['pain_level'] ?? json['painLevel']),
        woundStatus: safeParseString(json['wound_status'] ?? json['woundStatus']),
        observations: safeParseString(json['observations']),
        otherObservations: safeParseString(json['other_observations'] ?? json['otherObservations']),
        interventionsProvided: safeParseString(json['interventions_provided'] ?? json['interventionsProvided']),
        educationProvided: safeParseString(json['education_provided'] ?? json['educationProvided']),
        familyConcerns: safeParseString(json['family_concerns'] ?? json['familyConcerns']),
        nextSteps: safeParseString(json['next_steps'] ?? json['nextSteps']),
        createdAt: safeParseString(json['created_at'] ?? json['createdAt']),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error parsing ProgressNote: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visit_date': visitDate,
      if (visitTime != null) 'visit_time': visitTime,
      if (vitals != null) 'vitals': vitals,
      if (interventions != null) 'interventions': interventions,
      if (generalCondition != null) 'general_condition': generalCondition,
      if (painLevel != null) 'pain_level': painLevel,
      if (woundStatus != null) 'wound_status': woundStatus,
      if (observations != null) 'observations': observations,
      if (otherObservations != null) 'other_observations': otherObservations,
      if (interventionsProvided != null) 'interventions_provided': interventionsProvided,
      if (educationProvided != null) 'education_provided': educationProvided,
      if (familyConcerns != null) 'family_concerns': familyConcerns,
      if (nextSteps != null) 'next_steps': nextSteps,
      if (createdAt != null) 'created_at': createdAt,
    };
  }
}

// Schedule model
class Schedule {
  final int id;
  final String date;
  final String startTime;
  final String? endTime;
  final int? duration;
  final String status;
  final String? location;
  final String? notes;

  Schedule({
    required this.id,
    required this.date,
    required this.startTime,
    this.endTime,
    this.duration,
    required this.status,
    this.location,
    this.notes,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    try {
      int? safeParseInt(dynamic value) {
        if (value == null) return null;
        if (value is int) return value;
        if (value is String) return int.tryParse(value);
        return null;
      }

      String? safeParseString(dynamic value) {
        if (value == null) return null;
        return value.toString();
      }

      return Schedule(
        id: safeParseInt(json['id']) ?? 0,
        date: safeParseString(json['date']) ?? '',
        startTime: safeParseString(json['startTime'] ?? json['start_time']) ?? '00:00',
        endTime: safeParseString(json['endTime'] ?? json['end_time']),
        duration: safeParseInt(json['duration']),
        status: safeParseString(json['status']) ?? 'pending',
        location: safeParseString(json['location']),
        notes: safeParseString(json['notes']),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error parsing Schedule: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('JSON data: $json');
      rethrow;
    }
  }
}

// Initial Assessment Emergency Contact
class InitialAssessmentEmergencyContact {
  final String? name;
  final String? relationship;
  final String? phone;

  InitialAssessmentEmergencyContact({
    this.name,
    this.relationship,
    this.phone,
  });

  factory InitialAssessmentEmergencyContact.fromJson(Map<String, dynamic> json) {
    return InitialAssessmentEmergencyContact(
      name: json['name']?.toString(),
      relationship: json['relationship']?.toString(),
      phone: json['phone']?.toString(),
    );
  }
}

// Initial Vitals from Assessment
class InitialVitals {
  final String? spo2;
  final String? pulse;
  final String? weight;
  final String? temperature;
  final String? bloodPressure;
  final String? respiratoryRate;

  InitialVitals({
    this.spo2,
    this.pulse,
    this.weight,
    this.temperature,
    this.bloodPressure,
    this.respiratoryRate,
  });

  factory InitialVitals.fromJson(Map<String, dynamic> json) {
    return InitialVitals(
      spo2: json['spo2']?.toString(),
      pulse: json['pulse']?.toString(),
      weight: json['weight']?.toString(),
      temperature: json['temperature']?.toString(),
      bloodPressure: json['blood_pressure']?.toString(),
      respiratoryRate: json['respiratory_rate']?.toString(),
    );
  }
}

// Assessment Nurse
class AssessmentNurse {
  final int id;
  final String name;

  AssessmentNurse({
    required this.id,
    required this.name,
  });

  factory AssessmentNurse.fromJson(Map<String, dynamic> json) {
    return AssessmentNurse(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? 'Unknown Nurse',
    );
  }
}

// Initial Assessment model
class InitialAssessment {
  final int id;
  final String? physicalAddress;
  final String? occupation;
  final String? religion;
  final List<InitialAssessmentEmergencyContact> emergencyContacts;
  final String? presentingCondition;
  final String? pastMedicalHistory;
  final String? allergies;
  final String? currentMedications;
  final String? specialNeeds;
  final String? generalCondition;
  final String? hydrationStatus;
  final String? nutritionStatus;
  final String? mobilityStatus;
  final bool hasWounds;
  final String? woundDescription;
  final int? painLevel;
  final InitialVitals? initialVitals;
  final String? initialNursingImpression;
  final String? assessmentStatus;
  final AssessmentNurse? nurse;
  final String? completedAt;
  final String? createdAt;

  InitialAssessment({
    required this.id,
    this.physicalAddress,
    this.occupation,
    this.religion,
    required this.emergencyContacts,
    this.presentingCondition,
    this.pastMedicalHistory,
    this.allergies,
    this.currentMedications,
    this.specialNeeds,
    this.generalCondition,
    this.hydrationStatus,
    this.nutritionStatus,
    this.mobilityStatus,
    this.hasWounds = false,
    this.woundDescription,
    this.painLevel,
    this.initialVitals,
    this.initialNursingImpression,
    this.assessmentStatus,
    this.nurse,
    this.completedAt,
    this.createdAt,
  });

  factory InitialAssessment.fromJson(Map<String, dynamic> json) {
    try {
      return InitialAssessment(
        id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
        physicalAddress: json['physical_address']?.toString(),
        occupation: json['occupation']?.toString(),
        religion: json['religion']?.toString(),
        emergencyContacts: (json['emergency_contacts'] as List<dynamic>?)
            ?.map((e) => InitialAssessmentEmergencyContact.fromJson(e as Map<String, dynamic>))
            .toList() ?? [],
        presentingCondition: json['presenting_condition']?.toString(),
        pastMedicalHistory: json['past_medical_history']?.toString(),
        allergies: json['allergies']?.toString(),
        currentMedications: json['current_medications']?.toString(),
        specialNeeds: json['special_needs']?.toString(),
        generalCondition: json['general_condition']?.toString(),
        hydrationStatus: json['hydration_status']?.toString(),
        nutritionStatus: json['nutrition_status']?.toString(),
        mobilityStatus: json['mobility_status']?.toString(),
        hasWounds: json['has_wounds'] == true,
        woundDescription: json['wound_description']?.toString(),
        painLevel: json['pain_level'] is int ? json['pain_level'] : int.tryParse(json['pain_level']?.toString() ?? ''),
        initialVitals: json['initial_vitals'] != null && json['initial_vitals'] is Map
            ? InitialVitals.fromJson(json['initial_vitals'] as Map<String, dynamic>)
            : null,
        initialNursingImpression: json['initial_nursing_impression']?.toString(),
        assessmentStatus: json['assessment_status']?.toString(),
        nurse: json['nurse'] != null && json['nurse'] is Map
            ? AssessmentNurse.fromJson(json['nurse'] as Map<String, dynamic>)
            : null,
        completedAt: json['completed_at']?.toString(),
        createdAt: json['created_at']?.toString(),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error parsing InitialAssessment: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('JSON data: $json');
      rethrow;
    }
  }

  // Helper getters for display formatting
  String get generalConditionDisplay => _capitalizeFirst(generalCondition ?? 'N/A');
  String get hydrationStatusDisplay => _capitalizeFirst(hydrationStatus ?? 'N/A');
  String get nutritionStatusDisplay => _capitalizeFirst(nutritionStatus ?? 'N/A');
  String get mobilityStatusDisplay => _capitalizeFirst(mobilityStatus ?? 'N/A');
  String get assessmentStatusDisplay => _capitalizeFirst(assessmentStatus ?? 'N/A');

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}

// ==================== VITALS TIMELINE MODELS ====================

/// Top-level response for the patient vitals timeline endpoint.
class VitalsTimelineResponse {
  final bool success;
  final String? patientName;
  final int totalRecords;
  final List<VitalsDay> days;
  final VitalsPagination pagination;

  VitalsTimelineResponse({
    required this.success,
    required this.patientName,
    required this.totalRecords,
    required this.days,
    required this.pagination,
  });

  factory VitalsTimelineResponse.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map<String, dynamic>?) ?? const {};
    final patient = data['patient'] as Map<String, dynamic>?;
    final daysJson = (data['days'] as List<dynamic>?) ?? const [];

    return VitalsTimelineResponse(
      success: json['success'] == true,
      patientName: patient?['name']?.toString(),
      totalRecords: (data['total_records'] as num?)?.toInt() ?? 0,
      days: daysJson
          .whereType<Map<String, dynamic>>()
          .map(VitalsDay.fromJson)
          .toList(),
      pagination: VitalsPagination.fromJson(
        (data['pagination'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }
}

/// Pagination metadata for the vitals timeline (paginated by day).
class VitalsPagination {
  final int currentPage;
  final int perPage;
  final int totalDays;
  final int lastPage;
  final bool hasMore;

  VitalsPagination({
    required this.currentPage,
    required this.perPage,
    required this.totalDays,
    required this.lastPage,
    required this.hasMore,
  });

  factory VitalsPagination.fromJson(Map<String, dynamic> json) {
    return VitalsPagination(
      currentPage: (json['current_page'] as num?)?.toInt() ?? 1,
      perPage: (json['per_page'] as num?)?.toInt() ?? 14,
      totalDays: (json['total_days'] as num?)?.toInt() ?? 0,
      lastPage: (json['last_page'] as num?)?.toInt() ?? 1,
      hasMore: json['has_more'] == true,
    );
  }
}

/// A single day in the timeline, with all readings recorded that day.
class VitalsDay {
  final String date;
  final String dateDisplay;
  final String dayLabel;
  final bool isToday;
  final int recordsCount;
  final List<VitalsRecord> records;

  VitalsDay({
    required this.date,
    required this.dateDisplay,
    required this.dayLabel,
    required this.isToday,
    required this.recordsCount,
    required this.records,
  });

  factory VitalsDay.fromJson(Map<String, dynamic> json) {
    final recordsJson = (json['records'] as List<dynamic>?) ?? const [];
    return VitalsDay(
      date: json['date']?.toString() ?? '',
      dateDisplay: json['date_display']?.toString() ?? '',
      dayLabel: json['day_label']?.toString() ?? '',
      isToday: json['is_today'] == true,
      recordsCount: (json['records_count'] as num?)?.toInt() ?? recordsJson.length,
      records: recordsJson
          .whereType<Map<String, dynamic>>()
          .map(VitalsRecord.fromJson)
          .toList(),
    );
  }
}

/// A single vitals reading taken at a specific time by a specific nurse.
class VitalsRecord {
  final String id;
  final String source; // 'progress_note' | 'assessment'
  final String sourceLabel;
  final String? timeDisplay;
  final String? recordedAt;
  final String? nurseName;
  final bool isOwn;
  final PatientVitals vitals;

  VitalsRecord({
    required this.id,
    required this.source,
    required this.sourceLabel,
    required this.timeDisplay,
    required this.recordedAt,
    required this.nurseName,
    required this.isOwn,
    required this.vitals,
  });

  factory VitalsRecord.fromJson(Map<String, dynamic> json) {
    final nurse = json['nurse'] as Map<String, dynamic>?;
    return VitalsRecord(
      id: json['id']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      sourceLabel: json['source_label']?.toString() ?? '',
      timeDisplay: json['time_display']?.toString(),
      recordedAt: json['recorded_at']?.toString(),
      nurseName: nurse?['name']?.toString(),
      isOwn: json['is_own'] == true,
      vitals: PatientVitals.fromJson(
        (json['vitals'] as Map<String, dynamic>?) ?? const {},
      ),
    );
  }
}

// ============================================================================
// THERAPY NOTES (Physiotherapy / Speech Therapy)
// ============================================================================

/// The therapist's assignment to a patient (only present for therapist views)
class TherapistAssignmentInfo {
  final int id;
  final String therapistType; // physiotherapist | speech_therapist
  final String therapistTypeLabel;
  final String? assignedAt;
  final String? notes;

  TherapistAssignmentInfo({
    required this.id,
    required this.therapistType,
    required this.therapistTypeLabel,
    this.assignedAt,
    this.notes,
  });

  factory TherapistAssignmentInfo.fromJson(Map<String, dynamic> json) {
    return TherapistAssignmentInfo(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      therapistType: json['therapist_type']?.toString() ?? '',
      therapistTypeLabel: json['therapist_type_label']?.toString() ?? 'Therapist',
      assignedAt: json['assigned_at']?.toString(),
      notes: json['notes']?.toString(),
    );
  }
}

/// A free-text therapy session note recorded by a physiotherapist or speech
/// therapist. Shown in the patient's History labelled by therapy type.
class TherapyNote {
  final int id;
  final int patientId;
  final int therapistId;
  final String therapyType; // physiotherapy | speech_therapy
  final String therapyTypeLabel; // "Physiotherapy" | "Speech Therapy"
  final String? sessionDate; // yyyy-MM-dd
  final String? sessionTime; // HH:mm
  final String note;
  final String? therapistName;
  final String? therapistRole;
  final String? therapistSpecialization;
  final bool isOwn;
  final bool isEditable;
  final String? createdAt;
  final String? updatedAt;

  TherapyNote({
    required this.id,
    required this.patientId,
    required this.therapistId,
    required this.therapyType,
    required this.therapyTypeLabel,
    this.sessionDate,
    this.sessionTime,
    required this.note,
    this.therapistName,
    this.therapistRole,
    this.therapistSpecialization,
    this.isOwn = false,
    this.isEditable = false,
    this.createdAt,
    this.updatedAt,
  });

  bool get isSpeechTherapy => therapyType == 'speech_therapy';
  bool get isPhysiotherapy => therapyType == 'physiotherapy';

  /// e.g. "Physiotherapy Note" / "Speech Therapy Note"
  String get title => '$therapyTypeLabel Note';

  DateTime? get sessionDateTime {
    if (sessionDate == null) return null;
    try {
      final date = DateTime.parse(sessionDate!);
      if (sessionTime != null && sessionTime!.contains(':')) {
        final parts = sessionTime!.split(':');
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        return DateTime(date.year, date.month, date.day, h, m);
      }
      return date;
    } catch (_) {
      return null;
    }
  }

  factory TherapyNote.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? 0;
    }

    String? str(dynamic v) => v?.toString();

    final therapist = json['therapist'];
    final therapistMap = therapist is Map ? Map<String, dynamic>.from(therapist) : null;

    final type = str(json['therapy_type']) ?? '';
    final label = str(json['therapy_type_label']) ??
        (type == 'speech_therapy'
            ? 'Speech Therapy'
            : type == 'physiotherapy'
                ? 'Physiotherapy'
                : 'Therapy');

    return TherapyNote(
      id: parseInt(json['id']),
      patientId: parseInt(json['patient_id']),
      therapistId: parseInt(json['therapist_id']),
      therapyType: type,
      therapyTypeLabel: label,
      sessionDate: str(json['session_date']),
      sessionTime: str(json['session_time']),
      note: str(json['note']) ?? '',
      therapistName: therapistMap != null ? str(therapistMap['name']) : null,
      therapistRole: therapistMap != null ? str(therapistMap['role']) : null,
      therapistSpecialization:
          therapistMap != null ? str(therapistMap['specialization']) : null,
      isOwn: json['is_own'] == true,
      isEditable: json['is_editable'] == true,
      createdAt: str(json['created_at']),
      updatedAt: str(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patient_id': patientId,
        'therapist_id': therapistId,
        'therapy_type': therapyType,
        'therapy_type_label': therapyTypeLabel,
        'session_date': sessionDate,
        'session_time': sessionTime,
        'note': note,
        'therapist': {
          'name': therapistName,
          'role': therapistRole,
          'specialization': therapistSpecialization,
        },
        'is_own': isOwn,
        'is_editable': isEditable,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}
