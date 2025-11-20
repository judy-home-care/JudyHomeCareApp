// Incident Report Models
class IncidentReport {
  final int id;
  final String reportDate;
  final String incidentDate;
  final String incidentTime;
  final String? incidentLocation;
  final String incidentType;
  final String? incidentTypeOther;
  final String incidentDescription;
  
  // Patient Info
  final int patientId;
  final String patientName;
  final int? patientAge;
  final String? patientSex;
  final String? clientIdCaseNo;
  
  // Staff/Family Involved
  final String? staffFamilyInvolved;
  final String? staffFamilyRole;
  final String? staffFamilyRoleOther;
  
  // Immediate Actions
  final bool firstAidProvided;
  final String? firstAidDescription;
  final String? careProviderName;
  final bool transferredToHospital;
  final String? hospitalTransferDetails;
  
  // Witnesses
  final String? witnessNames;
  final String? witnessContacts;
  
  // Follow-Up
  final String? reportedToSupervisor;
  final String? correctivePreventiveActions;
  
  // Reporting
  final String reporterName;
  final String reportedAt;
  final String? reviewerName;
  final String? reviewedAt;
  
  // Status & Tracking
  final String status;
  final String severity;
  final bool followUpRequired;
  final String? followUpDate;
  final bool isOverdue;
  final bool isCritical;
  final bool requiresAttention;
  final int daysOld;
  final bool hasWitnesses;
  final String? investigationNotes;
  final String? finalResolution;

  IncidentReport({
    required this.id,
    required this.reportDate,
    required this.incidentDate,
    required this.incidentTime,
    this.incidentLocation,
    required this.incidentType,
    this.incidentTypeOther,
    required this.incidentDescription,
    required this.patientId,
    required this.patientName,
    this.patientAge,
    this.patientSex,
    this.clientIdCaseNo,
    this.staffFamilyInvolved,
    this.staffFamilyRole,
    this.staffFamilyRoleOther,
    required this.firstAidProvided,
    this.firstAidDescription,
    this.careProviderName,
    required this.transferredToHospital,
    this.hospitalTransferDetails,
    this.witnessNames,
    this.witnessContacts,
    this.reportedToSupervisor,
    this.correctivePreventiveActions,
    required this.reporterName,
    required this.reportedAt,
    this.reviewerName,
    this.reviewedAt,
    required this.status,
    required this.severity,
    required this.followUpRequired,
    this.followUpDate,
    required this.isOverdue,
    required this.isCritical,
    required this.requiresAttention,
    required this.daysOld,
    required this.hasWitnesses,
    this.investigationNotes,
    this.finalResolution,
  });

  factory IncidentReport.fromJson(Map<String, dynamic> json) {
    return IncidentReport(
      id: json['id'] as int,
      reportDate: json['report_date'] as String,
      incidentDate: json['incident_date'] as String,
      incidentTime: json['incident_time'] as String,
      incidentLocation: json['incident_location'] as String?,
      incidentType: json['incident_type'] as String,
      incidentTypeOther: json['incident_type_other'] as String?,
      incidentDescription: json['incident_description'] as String,
      patientId: json['patient_id'] as int,
      patientName: json['patient_name'] as String,
      patientAge: json['patient_age'] as int?,
      patientSex: json['patient_sex'] as String?,
      clientIdCaseNo: json['client_id_case_no'] as String?,
      staffFamilyInvolved: json['staff_family_involved'] as String?,
      staffFamilyRole: json['staff_family_role'] as String?,
      staffFamilyRoleOther: json['staff_family_role_other'] as String?,
      firstAidProvided: json['first_aid_provided'] as bool? ?? false,
      firstAidDescription: json['first_aid_description'] as String?,
      careProviderName: json['care_provider_name'] as String?,
      transferredToHospital: json['transferred_to_hospital'] as bool? ?? false,
      hospitalTransferDetails: json['hospital_transfer_details'] as String?,
      witnessNames: json['witness_names'] as String?,
      witnessContacts: json['witness_contacts'] as String?,
      reportedToSupervisor: json['reported_to_supervisor'] as String?,
      correctivePreventiveActions: json['corrective_actions'] as String?,
      reporterName: json['reporter_name'] as String,
      reportedAt: json['reported_at'] as String,
      reviewerName: json['reviewer_name'] as String?,
      reviewedAt: json['reviewed_at'] as String?,
      status: json['status'] as String,
      severity: json['severity'] as String,
      followUpRequired: json['follow_up_required'] as bool? ?? false,
      followUpDate: json['follow_up_date'] as String?,
      isOverdue: json['is_overdue'] as bool? ?? false,
      isCritical: json['is_critical'] as bool? ?? false,
      requiresAttention: json['requires_attention'] as bool? ?? false,
      daysOld: json['days_old'] as int? ?? 0,
      hasWitnesses: json['has_witnesses'] as bool? ?? false,
      investigationNotes: json['investigation_notes'] as String?,
      finalResolution: json['final_resolution'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'report_date': reportDate,
    'incident_date': incidentDate,
    'incident_time': incidentTime,
    'incident_location': incidentLocation,
    'incident_type': incidentType,
    'incident_type_other': incidentTypeOther,
    'incident_description': incidentDescription,
    'patient_id': patientId,
    'patient_name': patientName,
    'patient_age': patientAge,
    'patient_sex': patientSex,
    'client_id_case_no': clientIdCaseNo,
    'staff_family_involved': staffFamilyInvolved,
    'staff_family_role': staffFamilyRole,
    'staff_family_role_other': staffFamilyRoleOther,
    'first_aid_provided': firstAidProvided,
    'first_aid_description': firstAidDescription,
    'care_provider_name': careProviderName,
    'transferred_to_hospital': transferredToHospital,
    'hospital_transfer_details': hospitalTransferDetails,
    'witness_names': witnessNames,
    'witness_contacts': witnessContacts,
    'reported_to_supervisor': reportedToSupervisor,
    'corrective_actions': correctivePreventiveActions,
    'reporter_name': reporterName,
    'reported_at': reportedAt,
    'reviewer_name': reviewerName,
    'reviewed_at': reviewedAt,
    'status': status,
    'severity': severity,
    'follow_up_required': followUpRequired,
    'follow_up_date': followUpDate,
    'is_overdue': isOverdue,
    'is_critical': isCritical,
    'requires_attention': requiresAttention,
    'days_old': daysOld,
    'has_witnesses': hasWitnesses,
    'investigation_notes': investigationNotes,
    'final_resolution': finalResolution,
  };

  // Helper methods
  String get formattedIncidentType {
    if (incidentType == 'other' && incidentTypeOther != null) {
      return incidentTypeOther!;
    }
    return incidentType.split('_').map((word) => 
      word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  String get formattedSeverity {
    return severity[0].toUpperCase() + severity.substring(1);
  }

  String get formattedStatus {
    return status.split('_').map((word) => 
      word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }

  String get statusColor {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'FF9A00';
      case 'under_review':
        return '6C63FF';
      case 'investigated':
        return '199A8E';
      case 'resolved':
        return '4CAF50';
      case 'closed':
        return '9E9E9E';
      default:
        return '199A8E';
    }
  }

  String get severityColor {
    switch (severity.toLowerCase()) {
      case 'critical':
        return 'FF4757';
      case 'high':
        return 'FF6B6B';
      case 'medium':
        return 'FF9A00';
      case 'low':
        return '199A8E';
      default:
        return '199A8E';
    }
  }
}

// Create Incident Request Model
class CreateIncidentRequest {
  // Section 1: General Information
  final String reportDate;
  final String incidentDate;
  final String incidentTime;
  final String? incidentLocation;
  final String incidentType;
  final String? incidentTypeOther;
  
  // Section 2: Person(s) Involved
  final int patientId;
  final int? patientAge;
  final String? patientSex;
  final String? clientIdCaseNo;
  final String? staffFamilyInvolved;
  final String? staffFamilyRole;
  final String? staffFamilyRoleOther;
  
  // Section 3: Description
  final String incidentDescription;
  
  // Section 4: Immediate Actions
  final bool firstAidProvided;
  final String? firstAidDescription;
  final String? careProviderName;
  final bool transferredToHospital;
  final String? hospitalTransferDetails;
  
  // Section 5: Witnesses
  final String? witnessNames;
  final String? witnessContacts;
  
  // Section 6: Follow-Up
  final String? reportedToSupervisor;
  final String? correctivePreventiveActions;
  
  // Additional tracking
  final String? severity;
  final bool followUpRequired;
  final String? followUpDate;
  final int? assignedTo;

  CreateIncidentRequest({
    required this.reportDate,
    required this.incidentDate,
    required this.incidentTime,
    this.incidentLocation,
    required this.incidentType,
    this.incidentTypeOther,
    required this.patientId,
    this.patientAge,
    this.patientSex,
    this.clientIdCaseNo,
    this.staffFamilyInvolved,
    this.staffFamilyRole,
    this.staffFamilyRoleOther,
    required this.incidentDescription,
    this.firstAidProvided = false,
    this.firstAidDescription,
    this.careProviderName,
    this.transferredToHospital = false,
    this.hospitalTransferDetails,
    this.witnessNames,
    this.witnessContacts,
    this.reportedToSupervisor,
    this.correctivePreventiveActions,
    this.severity,
    this.followUpRequired = false,
    this.followUpDate,
    this.assignedTo,
  });

  Map<String, dynamic> toJson() {
    return {
      'report_date': reportDate,
      'incident_date': incidentDate,
      'incident_time': incidentTime,
      'incident_location': incidentLocation,
      'incident_type': incidentType,
      'incident_type_other': incidentTypeOther,
      'patient_id': patientId,
      'patient_age': patientAge,
      'patient_sex': patientSex,
      'client_id_case_no': clientIdCaseNo,
      'staff_family_involved': staffFamilyInvolved,
      'staff_family_role': staffFamilyRole,
      'staff_family_role_other': staffFamilyRoleOther,
      'incident_description': incidentDescription,
      'first_aid_provided': firstAidProvided,
      'first_aid_description': firstAidDescription,
      'care_provider_name': careProviderName,
      'transferred_to_hospital': transferredToHospital,
      'hospital_transfer_details': hospitalTransferDetails,
      'witness_names': witnessNames,
      'witness_contacts': witnessContacts,
      'reported_to_supervisor': reportedToSupervisor,
      'corrective_preventive_actions': correctivePreventiveActions,
      'severity': severity,
      'follow_up_required': followUpRequired,
      'follow_up_date': followUpDate,
      'assigned_to': assignedTo,
    };
  }
}

// Incident Types
class IncidentTypes {
  static const List<Map<String, String>> types = [
    {'value': 'fall', 'label': 'Fall'},
    {'value': 'medication_error', 'label': 'Medication Error'},
    {'value': 'equipment_failure', 'label': 'Equipment Failure'},
    {'value': 'injury', 'label': 'Injury'},
    {'value': 'other', 'label': 'Other'},
  ];
}

// Severity Levels
class SeverityLevels {
  static const List<Map<String, String>> levels = [
    {'value': 'low', 'label': 'Low'},
    {'value': 'medium', 'label': 'Medium'},
    {'value': 'high', 'label': 'High'},
    {'value': 'critical', 'label': 'Critical'},
  ];
}

// Staff/Family Roles
class StaffFamilyRoles {
  static const List<Map<String, String>> roles = [
    {'value': 'nurse', 'label': 'Nurse'},
    {'value': 'family', 'label': 'Family Member'},
    {'value': 'other', 'label': 'Other'},
  ];
}

// Incident Response Model
class IncidentResponse {
  final bool success;
  final String message;
  final IncidentReport? data;
  final Map<String, dynamic>? errors;

  IncidentResponse({
    required this.success,
    required this.message,
    this.data,
    this.errors,
  });

  factory IncidentResponse.fromJson(Map<String, dynamic> json) {
    return IncidentResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null 
          ? IncidentReport.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      errors: json['errors'] as Map<String, dynamic>?,
    );
  }
}

// Incident List Response Model
class IncidentListResponse {
  final bool success;
  final String message;
  final List<IncidentReport> data;
  final int total;
  final int currentPage;
  final int lastPage;
  final int? perPage;
  final Map<String, int>? counts;

  IncidentListResponse({
    required this.success,
    required this.message,
    required this.data,
    required this.total,
    required this.currentPage,
    required this.lastPage,
    this.perPage,
    this.counts,
  });

  factory IncidentListResponse.fromJson(Map<String, dynamic> json) {
    // Parse incidents data
    final dataList = json['data'] as List<dynamic>? ?? [];
    final incidents = dataList
        .map((item) => IncidentReport.fromJson(item as Map<String, dynamic>))
        .toList();

    // Parse counts
    Map<String, int>? counts;
    if (json['counts'] != null) {
      final countsData = json['counts'] as Map<String, dynamic>;
      counts = countsData.map((key, value) => MapEntry(key, value as int));
    }

    return IncidentListResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: incidents,
      // CRITICAL: These must match the backend response structure
      total: json['total'] as int? ?? 0,
      currentPage: json['current_page'] as int? ?? 1,
      lastPage: json['last_page'] as int? ?? 1,
      perPage: json['per_page'] as int?,
      counts: counts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'data': data.map((incident) => incident.toJson()).toList(),
      'total': total,
      'current_page': currentPage,
      'last_page': lastPage,
      'per_page': perPage,
      'counts': counts,
    };
  }

  @override
  String toString() {
    return 'IncidentListResponse(success: $success, total: $total, currentPage: $currentPage, lastPage: $lastPage, itemCount: ${data.length})';
  }
}

// Patient Selection Model (for dropdown)
class PatientOption {
  final int id;
  final String name;
  final int age;
  final String? gender;

  PatientOption({
    required this.id,
    required this.name,
    required this.age,
    this.gender,
  });

  factory PatientOption.fromJson(Map<String, dynamic> json) {
    return PatientOption(
      id: json['id'] as int,
      name: json['name'] as String,
      age: json['age'] as int? ?? 0,
      gender: json['gender'] as String?,
    );
  }
}