class NurseDashboardData {
  final double weekHours;
  final int activePlans;
  final int todayPatients;
  final List<WeekSchedule> weekSchedules;
  final List<ScheduleVisit> scheduleVisits;
  final List<UpcomingPatient> upcomingPatients;

  NurseDashboardData({
    required this.weekHours,
    required this.activePlans,
    required this.todayPatients,
    required this.weekSchedules,
    required this.scheduleVisits,
    required this.upcomingPatients,
  });

  factory NurseDashboardData.fromJson(Map<String, dynamic> json) {
    return NurseDashboardData(
      weekHours: (json['weekHours'] as num?)?.toDouble() ?? 0.0,
      activePlans: json['activePlans'] as int? ?? 0,
      todayPatients: json['todayPatients'] as int? ?? 0,
      weekSchedules: (json['weekSchedules'] as List<dynamic>?)
          ?.map((e) => WeekSchedule.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      scheduleVisits: (json['scheduleVisits'] as List<dynamic>?)
          ?.map((e) => ScheduleVisit.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      upcomingPatients: (json['upcomingPatients'] as List<dynamic>?)
          ?.map((e) => UpcomingPatient.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}

class WeekSchedule {
  final String date;
  final String dateDisplay;
  final int count;
  final List<ScheduleVisit> schedules;

  WeekSchedule({
    required this.date,
    required this.dateDisplay,
    required this.count,
    required this.schedules,
  });

  factory WeekSchedule.fromJson(Map<String, dynamic> json) {
    return WeekSchedule(
      date: json['date'] as String,
      dateDisplay: json['dateDisplay'] as String,
      count: json['count'] as int,
      schedules: (json['schedules'] as List<dynamic>)
          .map((e) => ScheduleVisit.fromJson(e as Map<String, dynamic>))
          .toList(),
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
  final PatientInfo? patient;

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
    this.patient,
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
      id: json['id'] as int,
      date: json['date'] as String? ?? '',
      dateDisplay: json['dateDisplay'] as String? ?? '',
      startDate: json['startDate'] as String? ?? json['date'] as String? ?? '',
      endDate: json['endDate'] as String? ?? json['date'] as String? ?? '',
      startDateDisplay: json['startDateDisplay'] as String? ?? json['dateDisplay'] as String? ?? '',
      endDateDisplay: json['endDateDisplay'] as String? ?? json['dateDisplay'] as String? ?? '',
      time: json['time'] as String? ?? '',
      endTime: json['endTime'] as String?,
      dailyDuration: json['dailyDuration'] as String? ?? json['duration'] as String? ?? '',
      assignmentDuration: json['assignmentDuration'] as String? ?? '',
      timeCompleted: json['timeCompleted'] as String?,
      status: json['status'] as String? ?? 'scheduled',
      carePlanTitle: json['carePlanTitle'] as String? ?? 'Care Plan Visit',
      careType: json['careType'] as String? ?? 'general_care',
      priority: json['priority'] as String? ?? 'medium',
      location: json['location'] as String? ?? '',
      patient: json['patient'] != null
          ? PatientInfo.fromJson(json['patient'] as Map<String, dynamic>)
          : null,
    );
  }
}

class PatientInfo {
  final int id;
  final String name;
  final int age;
  final String avatar;

  PatientInfo({
    required this.id,
    required this.name,
    required this.age,
    required this.avatar,
  });

  factory PatientInfo.fromJson(Map<String, dynamic> json) {
    return PatientInfo(
      id: json['id'] as int,
      name: json['name'] as String,
      age: json['age'] as int,
      avatar: json['avatar'] as String,
    );
  }
}

class UpcomingPatient {
  final int scheduleId;
  final String scheduledTime;
  final String scheduledDate;
  final String startDate;
  final String endDate;
  final String startDateDisplay;
  final String endDateDisplay;
  final String timeUntil;
  final bool isToday;
  final String? endTime;
  final String careType;
  final String priority;
  final String location;
  final String dailyDuration;
  final String assignmentDuration;
  final List<ScheduleInfo> upcomingSchedules;
  final int totalSchedules;
  final UpcomingPatientDetails? patient;

  UpcomingPatient({
    required this.scheduleId,
    required this.scheduledTime,
    required this.scheduledDate,
    required this.startDate,
    required this.endDate,
    required this.startDateDisplay,
    required this.endDateDisplay,
    required this.timeUntil,
    this.endTime,
    required this.isToday,
    required this.careType,
    required this.priority,
    required this.location,
    required this.dailyDuration,
    required this.assignmentDuration,
    required this.upcomingSchedules,
    required this.totalSchedules,
    this.patient,
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

  factory UpcomingPatient.fromJson(Map<String, dynamic> json) {
    return UpcomingPatient(
      scheduleId: json['scheduleId'] as int,
      scheduledTime: json['scheduledTime'] as String? ?? '',
      scheduledDate: json['scheduledDate'] as String? ?? '',
      startDate: json['startDate'] as String? ?? json['scheduledDate'] as String? ?? '',
      endDate: json['endDate'] as String? ?? json['scheduledDate'] as String? ?? '',
      startDateDisplay: json['startDateDisplay'] as String? ?? json['scheduledDate'] as String? ?? '',
      endDateDisplay: json['endDateDisplay'] as String? ?? json['scheduledDate'] as String? ?? '',
      timeUntil: json['timeUntil'] as String? ?? '',
      endTime: json['endTime'] as String?,
      isToday: json['isToday'] as bool? ?? false,
      careType: json['careType'] as String? ?? 'general_care',
      priority: json['priority'] as String? ?? 'medium',
      location: json['location'] as String? ?? '',
      dailyDuration: json['dailyDuration'] as String? ?? json['duration'] as String? ?? '',
      assignmentDuration: json['assignmentDuration'] as String? ?? '',
      upcomingSchedules: (json['upcomingSchedules'] as List<dynamic>?)
          ?.map((e) => ScheduleInfo.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      totalSchedules: json['totalSchedules'] as int? ?? 1,
      patient: json['patient'] != null
          ? UpcomingPatientDetails.fromJson(json['patient'] as Map<String, dynamic>)
          : null,
    );
  }
}

class UpcomingPatientDetails {
  final int id;
  final String name;
  final int age;
  final String phone;
  final String avatar;
  final EmergencyContact emergencyContact;
  final PatientVitals? lastVitals;

  UpcomingPatientDetails({
    required this.id,
    required this.name,
    required this.age,
    required this.phone,
    required this.avatar,
    required this.emergencyContact,
    this.lastVitals,
  });

  factory UpcomingPatientDetails.fromJson(Map<String, dynamic> json) {
    return UpcomingPatientDetails(
      id: json['id'] as int,
      name: json['name'] as String,
      age: json['age'] as int,
      phone: json['phone'] as String,
      avatar: json['avatar'] as String,
      emergencyContact: EmergencyContact.fromJson(
        json['emergencyContact'] as Map<String, dynamic>
      ),
      lastVitals: json['lastVitals'] != null 
          ? PatientVitals.fromJson(json['lastVitals'] as Map<String, dynamic>)
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
      scheduleId: json['scheduleId'] as int,
      scheduledTime: json['scheduledTime'] as String? ?? '',
      scheduledDate: json['scheduledDate'] as String? ?? '',
      startDate: json['startDate'] as String? ?? json['scheduledDate'] as String? ?? '',
      endDate: json['endDate'] as String? ?? json['scheduledDate'] as String? ?? '',
      startDateDisplay: json['startDateDisplay'] as String? ?? json['scheduledDate'] as String? ?? '',
      endDateDisplay: json['endDateDisplay'] as String? ?? json['scheduledDate'] as String? ?? '',
      timeUntil: json['timeUntil'] as String? ?? '',
      endTime: json['endTime'] as String?,
      isToday: json['isToday'] as bool? ?? false,
      careType: json['careType'] as String? ?? 'general_care',
      location: json['location'] as String? ?? '',
      dailyDuration: json['dailyDuration'] as String? ?? json['duration'] as String? ?? '',
      assignmentDuration: json['assignmentDuration'] as String? ?? '',
    );
  }
}

class EmergencyContact {
  final String? name;
  final String? phone;

  EmergencyContact({this.name, this.phone});

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      name: json['name'] as String?,
      phone: json['phone'] as String?,
    );
  }
}

// UPDATED: Standardized PatientVitals to match new format
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
    return PatientVitals(
      bloodPressure: _parseVitalValue(json['blood_pressure']),
      pulse: _parseVitalValue(json['pulse']),
      temperature: _parseVitalValue(json['temperature']),
      spo2: _parseVitalValue(json['spo2']),
      respiration: _parseVitalValue(json['respiration']),
      recordedAt: json['recordedAt'] as String?,
    );
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
      // For temperature, keep one decimal place
      if (value is double) {
        return value.toStringAsFixed(1);
      }
      return value.toString();
    }
    
    // Fallback for any other type
    return value.toString();
  }
}