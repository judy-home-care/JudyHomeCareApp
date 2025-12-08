class PatientDashboardData {
  final double weekHours;
  final int nursesToday;
  final int activePlans;
  final List<ScheduleVisit> scheduleVisits;
  final List<UpcomingNurse> upcomingNurses;
  final PatientInitialAssessment? initialAssessment;

  PatientDashboardData({
    required this.weekHours,
    required this.nursesToday,
    required this.activePlans,
    required this.scheduleVisits,
    required this.upcomingNurses,
    this.initialAssessment,
  });

  factory PatientDashboardData.fromJson(Map<String, dynamic> json) {
    // Debug: Check if initial_assessment is present
    print('📦 [PatientDashboardData] Parsing JSON keys: ${json.keys.toList()}');
    print('📦 [PatientDashboardData] initial_assessment present: ${json.containsKey('initial_assessment')}');
    if (json['initial_assessment'] != null) {
      print('📦 [PatientDashboardData] initial_assessment type: ${json['initial_assessment'].runtimeType}');
    }

    final assessment = json['initial_assessment'] != null && json['initial_assessment'] is Map
        ? PatientInitialAssessment.fromJson(json['initial_assessment'] as Map<String, dynamic>)
        : null;

    print('📦 [PatientDashboardData] Parsed initialAssessment: ${assessment != null ? 'ID ${assessment.id}' : 'null'}');

    return PatientDashboardData(
      weekHours: (json['weekHours'] ?? 0).toDouble(),
      nursesToday: json['nursesToday'] ?? 0,
      activePlans: json['activePlans'] ?? 0,
      scheduleVisits: (json['scheduleVisits'] as List?)
          ?.map((v) => ScheduleVisit.fromJson(v))
          .toList() ?? [],
      upcomingNurses: (json['upcomingNurses'] as List?)
          ?.map((n) => UpcomingNurse.fromJson(n))
          .toList() ?? [],
      initialAssessment: assessment,
    );
  }
}

class ScheduleVisit {
  final int id;
  final String date;
  final String dateDisplay;
  final String startDate;
  final String endDate;
  final String startDateDisplay;
  final String endDateDisplay;
  final String time;
  final String? endTime;
  final String dailyDuration;
  final String assignmentDuration;
  final String? timeCompleted;
  final String status;
  final String carePlanTitle;
  final String careType;
  final String priority;
  final String location;
  final NurseInfo? nurse;

  ScheduleVisit({
    required this.id,
    required this.date,
    required this.dateDisplay,
    required this.startDate,
    required this.endDate,
    required this.startDateDisplay,
    required this.endDateDisplay,
    required this.time,
    this.endTime,
    required this.dailyDuration,
    required this.assignmentDuration,
    this.timeCompleted,
    required this.status,
    required this.carePlanTitle,
    required this.careType,
    required this.priority,
    required this.location,
    this.nurse,
  });

  /// Check if this is a multi-day assignment
  bool get isMultiDay => startDate != endDate;

  /// Get formatted date range display
  String get dateRangeDisplay {
    if (isMultiDay) {
      return '$startDateDisplay - $endDateDisplay';
    }
    return startDateDisplay;
  }

  /// Get formatted time range display
  String get timeRangeDisplay {
    if (endTime != null && endTime!.isNotEmpty) {
      return '$time - $endTime';
    }
    return time;
  }

  factory ScheduleVisit.fromJson(Map<String, dynamic> json) {
    return ScheduleVisit(
      id: json['id'] ?? 0,
      date: json['date'] ?? '',
      dateDisplay: json['dateDisplay'] ?? '',
      startDate: json['startDate'] ?? json['date'] ?? '',
      endDate: json['endDate'] ?? json['date'] ?? '',
      startDateDisplay: json['startDateDisplay'] ?? json['dateDisplay'] ?? '',
      endDateDisplay: json['endDateDisplay'] ?? json['dateDisplay'] ?? '',
      time: json['time'] ?? '',
      endTime: json['endTime'],
      dailyDuration: json['dailyDuration'] ?? json['duration'] ?? '0m',
      assignmentDuration: json['assignmentDuration'] ?? '',
      timeCompleted: json['timeCompleted'],
      status: json['status'] ?? 'scheduled',
      carePlanTitle: json['carePlanTitle'] ?? '',
      careType: json['careType'] ?? '',
      priority: json['priority'] ?? 'medium',
      location: json['location'] ?? '',
      nurse: json['nurse'] != null ? NurseInfo.fromJson(json['nurse']) : null,
    );
  }
}

class NurseInfo {
  final int id;
  final String name;
  final String? specialization;
  final String? phone;
  final String avatar;

  NurseInfo({
    required this.id,
    required this.name,
    this.specialization,
    this.phone,
    required this.avatar,
  });

  factory NurseInfo.fromJson(Map<String, dynamic> json) {
    return NurseInfo(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      specialization: json['specialization'],
      phone: json['phone'],
      avatar: json['avatar'] ?? '',
    );
  }
}

class UpcomingNurse {
  final int scheduleId;
  final String scheduledTime;
  final String scheduledDate;
  final String startDate;
  final String endDate;
  final String startDateDisplay;
  final String endDateDisplay;
  final String? endTime;
  final String timeUntil;
  final bool isToday;
  final String careType;
  final String priority;
  final String location;
  final String dailyDuration;
  final String assignmentDuration;
  final List<ScheduleInfo> upcomingSchedules;
  final int totalSchedules;
  final NurseDetail nurse;
  final VitalsInfo? currentVitals;

  UpcomingNurse({
    required this.scheduleId,
    required this.scheduledTime,
    required this.scheduledDate,
    required this.startDate,
    required this.endDate,
    required this.startDateDisplay,
    required this.endDateDisplay,
    this.endTime,
    required this.timeUntil,
    required this.isToday,
    required this.careType,
    required this.priority,
    required this.location,
    required this.dailyDuration,
    required this.assignmentDuration,
    required this.upcomingSchedules,
    required this.totalSchedules,
    required this.nurse,
    this.currentVitals,
  });

  /// Check if this is a multi-day assignment
  bool get isMultiDay => startDate != endDate;

  /// Get formatted date range display
  String get dateRangeDisplay {
    if (isMultiDay) {
      return '$startDateDisplay - $endDateDisplay';
    }
    return startDateDisplay;
  }

  /// Get formatted time range display
  String get timeRangeDisplay {
    if (endTime != null && endTime!.isNotEmpty) {
      return '$scheduledTime - $endTime';
    }
    return scheduledTime;
  }

  factory UpcomingNurse.fromJson(Map<String, dynamic> json) {
    return UpcomingNurse(
      scheduleId: json['scheduleId'] ?? 0,
      scheduledTime: json['scheduledTime'] ?? '',
      scheduledDate: json['scheduledDate'] ?? '',
      startDate: json['startDate'] ?? json['scheduledDate'] ?? '',
      endDate: json['endDate'] ?? json['scheduledDate'] ?? '',
      startDateDisplay: json['startDateDisplay'] ?? json['scheduledDate'] ?? '',
      endDateDisplay: json['endDateDisplay'] ?? json['scheduledDate'] ?? '',
      endTime: json['endTime'],
      timeUntil: json['timeUntil'] ?? '',
      isToday: json['isToday'] ?? false,
      careType: json['careType'] ?? '',
      priority: json['priority'] ?? 'medium',
      location: json['location'] ?? '',
      dailyDuration: json['dailyDuration'] ?? json['duration'] ?? '0m',
      assignmentDuration: json['assignmentDuration'] ?? '',
      upcomingSchedules: (json['upcomingSchedules'] as List?)
          ?.map((s) => ScheduleInfo.fromJson(s))
          .toList() ?? [],
      totalSchedules: json['totalSchedules'] ?? 0,
      nurse: NurseDetail.fromJson(json['nurse'] ?? {}),
      currentVitals: json['currentVitals'] != null
          ? VitalsInfo.fromJson(json['currentVitals'])
          : null,
    );
  }
}

class ScheduleInfo {
  final int scheduleId;
  final String scheduledTime;
  final String scheduledDate;
  final String startDate;
  final String endDate;
  final String startDateDisplay;
  final String endDateDisplay;
  final String? endTime;
  final String timeUntil;
  final bool isToday;
  final String careType;
  final String location;
  final String dailyDuration;
  final String assignmentDuration;

  ScheduleInfo({
    required this.scheduleId,
    required this.scheduledTime,
    required this.scheduledDate,
    required this.startDate,
    required this.endDate,
    required this.startDateDisplay,
    required this.endDateDisplay,
    this.endTime,
    required this.timeUntil,
    required this.isToday,
    required this.careType,
    required this.location,
    required this.dailyDuration,
    required this.assignmentDuration,
  });

  /// Check if this is a multi-day assignment
  bool get isMultiDay => startDate != endDate;

  /// Get formatted date range display
  String get dateRangeDisplay {
    if (isMultiDay) {
      return '$startDateDisplay - $endDateDisplay';
    }
    return startDateDisplay;
  }

  /// Get formatted time range display
  String get timeRangeDisplay {
    if (endTime != null && endTime!.isNotEmpty) {
      return '$scheduledTime - $endTime';
    }
    return scheduledTime;
  }

  factory ScheduleInfo.fromJson(Map<String, dynamic> json) {
    return ScheduleInfo(
      scheduleId: json['scheduleId'] ?? 0,
      scheduledTime: json['scheduledTime'] ?? '',
      scheduledDate: json['scheduledDate'] ?? '',
      startDate: json['startDate'] ?? json['scheduledDate'] ?? '',
      endDate: json['endDate'] ?? json['scheduledDate'] ?? '',
      startDateDisplay: json['startDateDisplay'] ?? json['scheduledDate'] ?? '',
      endDateDisplay: json['endDateDisplay'] ?? json['scheduledDate'] ?? '',
      endTime: json['endTime'],
      timeUntil: json['timeUntil'] ?? '',
      isToday: json['isToday'] ?? false,
      careType: json['careType'] ?? '',
      location: json['location'] ?? '',
      dailyDuration: json['dailyDuration'] ?? json['duration'] ?? '0m',
      assignmentDuration: json['assignmentDuration'] ?? '',
    );
  }
}

class NurseDetail {
  final int id;
  final String name;
  final String? specialization;
  final String? phone;
  final String avatar;

  NurseDetail({
    required this.id,
    required this.name,
    this.specialization,
    this.phone,
    required this.avatar,
  });

  factory NurseDetail.fromJson(Map<String, dynamic> json) {
    return NurseDetail(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      specialization: json['specialization'],
      phone: json['phone'],
      avatar: json['avatar'] ?? '',
    );
  }
}

class VitalsInfo {
  final String bloodPressure;
  final String temperature;
  final String pulse;
  final String spo2;
  final String respiration;
  final String recordedAt;

  VitalsInfo({
    required this.bloodPressure,
    required this.temperature,
    required this.pulse,
    required this.spo2,
    required this.respiration,
    required this.recordedAt,
  });

  factory VitalsInfo.fromJson(Map<String, dynamic> json) {
    return VitalsInfo(
      bloodPressure: json['blood_pressure']?.toString() ?? 'N/A',
      temperature: json['temperature']?.toString() ?? 'N/A',
      pulse: json['pulse']?.toString() ?? 'N/A',
      spo2: json['spo2']?.toString() ?? 'N/A',
      respiration: json['respiration']?.toString() ?? 'N/A',
      recordedAt: json['recordedAt']?.toString() ?? '',
    );
  }
}

// Initial Assessment Models
class PatientInitialAssessmentEmergencyContact {
  final String? name;
  final String? relationship;
  final String? phone;

  PatientInitialAssessmentEmergencyContact({
    this.name,
    this.relationship,
    this.phone,
  });

  factory PatientInitialAssessmentEmergencyContact.fromJson(Map<String, dynamic> json) {
    return PatientInitialAssessmentEmergencyContact(
      name: json['name']?.toString(),
      relationship: json['relationship']?.toString(),
      phone: json['phone']?.toString(),
    );
  }
}

class PatientInitialVitals {
  final String? spo2;
  final String? pulse;
  final String? weight;
  final String? temperature;
  final String? bloodPressure;
  final String? respiratoryRate;

  PatientInitialVitals({
    this.spo2,
    this.pulse,
    this.weight,
    this.temperature,
    this.bloodPressure,
    this.respiratoryRate,
  });

  factory PatientInitialVitals.fromJson(Map<String, dynamic> json) {
    return PatientInitialVitals(
      spo2: json['spo2']?.toString(),
      pulse: json['pulse']?.toString(),
      weight: json['weight']?.toString(),
      temperature: json['temperature']?.toString(),
      bloodPressure: json['blood_pressure']?.toString(),
      respiratoryRate: json['respiratory_rate']?.toString(),
    );
  }
}

class PatientAssessmentNurse {
  final int id;
  final String name;

  PatientAssessmentNurse({
    required this.id,
    required this.name,
  });

  factory PatientAssessmentNurse.fromJson(Map<String, dynamic> json) {
    return PatientAssessmentNurse(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
    );
  }
}

class PatientInitialAssessment {
  final int id;
  final String? physicalAddress;
  final String? occupation;
  final String? religion;
  final List<PatientInitialAssessmentEmergencyContact> emergencyContacts;
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
  final PatientInitialVitals? initialVitals;
  final String? initialNursingImpression;
  final String? assessmentStatus;
  final PatientAssessmentNurse? nurse;
  final String? completedAt;
  final String? createdAt;

  PatientInitialAssessment({
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
    required this.hasWounds,
    this.woundDescription,
    this.painLevel,
    this.initialVitals,
    this.initialNursingImpression,
    this.assessmentStatus,
    this.nurse,
    this.completedAt,
    this.createdAt,
  });

  bool get isCompleted => assessmentStatus?.toLowerCase() == 'completed';

  factory PatientInitialAssessment.fromJson(Map<String, dynamic> json) {
    final emergencyContactsData = json['emergency_contacts'];
    List<PatientInitialAssessmentEmergencyContact> contacts = [];
    if (emergencyContactsData is List) {
      contacts = emergencyContactsData
          .map((c) => PatientInitialAssessmentEmergencyContact.fromJson(c as Map<String, dynamic>))
          .toList();
    }

    return PatientInitialAssessment(
      id: json['id'] ?? 0,
      physicalAddress: json['physical_address']?.toString(),
      occupation: json['occupation']?.toString(),
      religion: json['religion']?.toString(),
      emergencyContacts: contacts,
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
          ? PatientInitialVitals.fromJson(json['initial_vitals'] as Map<String, dynamic>)
          : null,
      initialNursingImpression: json['initial_nursing_impression']?.toString(),
      assessmentStatus: json['assessment_status']?.toString(),
      nurse: json['nurse'] != null && json['nurse'] is Map
          ? PatientAssessmentNurse.fromJson(json['nurse'] as Map<String, dynamic>)
          : null,
      completedAt: json['completed_at']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}