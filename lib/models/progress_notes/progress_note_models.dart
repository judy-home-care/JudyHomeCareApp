/// Progress Notes Models
/// 
/// Contains all data models for Progress Notes feature including:
/// - Response models (list, detail, create)
/// - Request models (create)
/// - Entity models (progress note, patient info, nurse info)
/// - Pagination model

// ============================================================================
// RESPONSE MODELS
// ============================================================================

/// Response model for list of progress notes
class ProgressNotesResponse {
  final bool success;
  final List<ProgressNote> data;
  final PaginationInfo pagination;

  ProgressNotesResponse({
    required this.success,
    required this.data,
    required this.pagination,
  });

  factory ProgressNotesResponse.fromJson(Map<String, dynamic> json) {
    return ProgressNotesResponse(
      success: json['success'] ?? false,
      data: (json['data'] as List<dynamic>?)
              ?.map((item) => ProgressNote.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      pagination: PaginationInfo.fromJson(json['pagination'] ?? {}),
    );
  }
}

/// Response model for a single progress note detail
class ProgressNoteDetailResponse {
  final bool success;
  final ProgressNoteDetail data;

  ProgressNoteDetailResponse({
    required this.success,
    required this.data,
  });

  factory ProgressNoteDetailResponse.fromJson(Map<String, dynamic> json) {
    return ProgressNoteDetailResponse(
      success: json['success'] ?? false,
      data: ProgressNoteDetail.fromJson(json['data'] ?? {}),
    );
  }
}

/// Response model for creating a progress note
class CreateProgressNoteResponse {
  final bool success;
  final String message;
  final ProgressNoteDetail data;

  CreateProgressNoteResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory CreateProgressNoteResponse.fromJson(Map<String, dynamic> json) {
    return CreateProgressNoteResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: ProgressNoteDetail.fromJson(json['data'] ?? {}),
    );
  }
}

// ============================================================================
// REQUEST MODELS
// ============================================================================

/// Request model for creating a progress note
class CreateProgressNoteRequest {
  final int patientId;
  final String visitDate;
  final String visitTime;
  final Map<String, dynamic>? vitals;
  final Map<String, dynamic>? interventions;
  final String generalCondition;
  final int painLevel;
  final String? woundStatus;
  final String? otherObservations;
  final String? educationProvided;
  final String? familyConcerns;
  final String? nextSteps;

  CreateProgressNoteRequest({
    required this.patientId,
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
    final Map<String, dynamic> data = {
      'patient_id': patientId,
      'visit_date': visitDate,
      'visit_time': visitTime,
      'general_condition': generalCondition,
      'pain_level': painLevel,
    };

    if (vitals != null) {
      data['vitals'] = vitals;
    }

    if (interventions != null) {
      data['interventions'] = interventions;
    }

    if (woundStatus != null && woundStatus!.isNotEmpty) {
      data['wound_status'] = woundStatus;
    }

    if (otherObservations != null && otherObservations!.isNotEmpty) {
      data['other_observations'] = otherObservations;
    }

    if (educationProvided != null && educationProvided!.isNotEmpty) {
      data['education_provided'] = educationProvided;
    }

    if (familyConcerns != null && familyConcerns!.isNotEmpty) {
      data['family_concerns'] = familyConcerns;
    }

    if (nextSteps != null && nextSteps!.isNotEmpty) {
      data['next_steps'] = nextSteps;
    }

    return data;
  }
}

// ============================================================================
// ENTITY MODELS
// ============================================================================

/// Progress Note model (for list view - basic info)
class ProgressNote {
  final int id;
  final String visitDate;
  final String visitTime;
  final String generalCondition;
  final int painLevel;
  final Map<String, dynamic>? vitals;
  final Map<String, dynamic>? interventions;
  final String? woundStatus;
  final String? otherObservations;
  final String? educationProvided;
  final String? familyConcerns;
  final String? nextSteps;
  final String? createdAt;
  final PatientInfo? patient; 
  final NurseInfo? nurse; 

  ProgressNote({
    required this.id,
    required this.visitDate,
    required this.visitTime,
    required this.generalCondition,
    required this.painLevel,
    this.vitals,
    this.interventions,
    this.woundStatus,
    this.otherObservations,
    this.educationProvided,
    this.familyConcerns,
    this.nextSteps,
    this.createdAt,
    this.patient,
    this.nurse,
  });

  factory ProgressNote.fromJson(Map<String, dynamic> json) {
    return ProgressNote(
      id: json['id'] ?? 0,
      visitDate: json['visit_date'] ?? '',
      visitTime: json['visit_time'] ?? '',
      generalCondition: json['general_condition'] ?? '',
      painLevel: json['pain_level'] ?? 0,
      vitals: json['vitals'] as Map<String, dynamic>?,
      interventions: json['interventions'] as Map<String, dynamic>?,
      woundStatus: json['wound_status'],
      otherObservations: json['other_observations'],
      educationProvided: json['education_provided'],
      familyConcerns: json['family_concerns'],
      nextSteps: json['next_steps'],
      createdAt: json['created_at'],
      patient: json['patient'] != null
          ? PatientInfo.fromJson(json['patient'])
          : null,
      nurse: json['nurse'] != null ? NurseInfo.fromJson(json['nurse']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visit_date': visitDate,
      'visit_time': visitTime,
      'general_condition': generalCondition,
      'pain_level': painLevel,
      'vitals': vitals,
      'interventions': interventions,
      'wound_status': woundStatus,
      'other_observations': otherObservations,
      'education_provided': educationProvided,
      'family_concerns': familyConcerns,
      'next_steps': nextSteps,
      'created_at': createdAt,
      'patient': patient?.toJson(),
      'nurse': nurse?.toJson(),
    };
  }
}

/// Progress Note Detail model (for detail view - complete info)
class ProgressNoteDetail {
  final int id;
  final String visitDate;
  final String visitTime;
  final String generalCondition;
  final int painLevel;
  final Map<String, dynamic>? vitals;
  final Map<String, dynamic>? interventions;
  final String? woundStatus;
  final String? otherObservations;
  final String? educationProvided;
  final String? familyConcerns;
  final String? nextSteps;
  final String? createdAt;
  final PatientInfo? patient;
  final NurseInfo? nurse;

  ProgressNoteDetail({
    required this.id,
    required this.visitDate,
    required this.visitTime,
    required this.generalCondition,
    required this.painLevel,
    this.vitals,
    this.interventions,
    this.woundStatus,
    this.otherObservations,
    this.educationProvided,
    this.familyConcerns,
    this.nextSteps,
    this.createdAt,
    this.patient,
    this.nurse,
  });

  factory ProgressNoteDetail.fromJson(Map<String, dynamic> json) {
    return ProgressNoteDetail(
      id: json['id'] ?? 0,
      visitDate: json['visit_date'] ?? '',
      visitTime: json['visit_time'] ?? '',
      generalCondition: json['general_condition'] ?? '',
      painLevel: json['pain_level'] ?? 0,
      vitals: json['vitals'] as Map<String, dynamic>?,
      interventions: json['interventions'] as Map<String, dynamic>?,
      woundStatus: json['wound_status'],
      otherObservations: json['other_observations'],
      educationProvided: json['education_provided'],
      familyConcerns: json['family_concerns'],
      nextSteps: json['next_steps'],
      createdAt: json['created_at'],
      patient: json['patient'] != null
          ? PatientInfo.fromJson(json['patient'])
          : null,
      nurse: json['nurse'] != null ? NurseInfo.fromJson(json['nurse']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'visit_date': visitDate,
      'visit_time': visitTime,
      'general_condition': generalCondition,
      'pain_level': painLevel,
      'vitals': vitals,
      'interventions': interventions,
      'wound_status': woundStatus,
      'other_observations': otherObservations,
      'education_provided': educationProvided,
      'family_concerns': familyConcerns,
      'next_steps': nextSteps,
      'created_at': createdAt,
      'patient': patient?.toJson(),
      'nurse': nurse?.toJson(),
    };
  }
}

/// Patient info model
class PatientInfo {
  final int id;
  final String name;

  PatientInfo({
    required this.id,
    required this.name,
  });

  factory PatientInfo.fromJson(Map<String, dynamic> json) {
    return PatientInfo(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

/// Nurse info model
class NurseInfo {
  final int id;
  final String name;

  NurseInfo({
    required this.id,
    required this.name,
  });

  factory NurseInfo.fromJson(Map<String, dynamic> json) {
    return NurseInfo(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

// ============================================================================
// PAGINATION MODEL
// ============================================================================

/// Pagination info model
class PaginationInfo {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  PaginationInfo({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      currentPage: json['current_page'] ?? 1,
      lastPage: json['last_page'] ?? 1,
      perPage: json['per_page'] ?? 15,
      total: json['total'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_page': currentPage,
      'last_page': lastPage,
      'per_page': perPage,
      'total': total,
    };
  }

  bool get hasMorePages => currentPage < lastPage;
  
  bool get isFirstPage => currentPage == 1;
  
  bool get isLastPage => currentPage == lastPage;
  
  int get remainingItems => total - (currentPage * perPage);
}