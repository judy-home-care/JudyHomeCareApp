/// Models for the physiotherapist / speech therapist mobile dashboard
/// (GET /api/mobile/therapist/dashboard).

class TherapistDashboardData {
  final TherapistInfo therapist;
  final TherapistDashboardStats stats;
  final List<TherapistDashboardPatient> patients;
  final List<TherapistDashboardPatient> needsAttention;
  final List<TherapistDashboardNote> recentNotes;
  final List<TherapistWeeklyActivityDay> weeklyActivity;
  final String? today;

  TherapistDashboardData({
    required this.therapist,
    required this.stats,
    required this.patients,
    required this.needsAttention,
    required this.recentNotes,
    required this.weeklyActivity,
    this.today,
  });

  factory TherapistDashboardData.fromJson(Map<String, dynamic> json) {
    List<T> parseList<T>(dynamic raw, T Function(Map<String, dynamic>) f) {
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .map((e) => f(Map<String, dynamic>.from(e)))
          .toList();
    }

    return TherapistDashboardData(
      therapist: TherapistInfo.fromJson(
        json['therapist'] is Map ? Map<String, dynamic>.from(json['therapist']) : {},
      ),
      stats: TherapistDashboardStats.fromJson(
        json['stats'] is Map ? Map<String, dynamic>.from(json['stats']) : {},
      ),
      patients: parseList(json['patients'], TherapistDashboardPatient.fromJson),
      needsAttention: parseList(json['needsAttention'], TherapistDashboardPatient.fromJson),
      recentNotes: parseList(json['recentNotes'], TherapistDashboardNote.fromJson),
      weeklyActivity: parseList(json['weeklyActivity'], TherapistWeeklyActivityDay.fromJson),
      today: json['today']?.toString(),
    );
  }
}

class TherapistInfo {
  final int id;
  final String name;
  final String role; // physiotherapist | speech_therapist
  final String roleLabel;
  final String therapyType; // physiotherapy | speech_therapy
  final String therapyTypeLabel;
  final String? staffId;
  final String? specialization;

  TherapistInfo({
    required this.id,
    required this.name,
    required this.role,
    required this.roleLabel,
    required this.therapyType,
    required this.therapyTypeLabel,
    this.staffId,
    this.specialization,
  });

  factory TherapistInfo.fromJson(Map<String, dynamic> json) {
    return TherapistInfo(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      roleLabel: json['roleLabel']?.toString() ?? 'Therapist',
      therapyType: json['therapyType']?.toString() ?? '',
      therapyTypeLabel: json['therapyTypeLabel']?.toString() ?? 'Therapy',
      staffId: json['staffId']?.toString(),
      specialization: json['specialization']?.toString(),
    );
  }
}

class TherapistDashboardStats {
  final int assignedPatients;
  final int sessionsToday;
  final int notesThisWeek;
  final int notesThisMonth;
  final int totalNotes;
  final int patientsSeenThisWeek;
  final int newAssignmentsThisWeek;

  TherapistDashboardStats({
    required this.assignedPatients,
    required this.sessionsToday,
    required this.notesThisWeek,
    required this.notesThisMonth,
    required this.totalNotes,
    required this.patientsSeenThisWeek,
    required this.newAssignmentsThisWeek,
  });

  factory TherapistDashboardStats.fromJson(Map<String, dynamic> json) {
    int i(dynamic v) => v is int ? v : int.tryParse('${v ?? 0}') ?? 0;
    return TherapistDashboardStats(
      assignedPatients: i(json['assignedPatients']),
      sessionsToday: i(json['sessionsToday']),
      notesThisWeek: i(json['notesThisWeek']),
      notesThisMonth: i(json['notesThisMonth']),
      totalNotes: i(json['totalNotes']),
      patientsSeenThisWeek: i(json['patientsSeenThisWeek']),
      newAssignmentsThisWeek: i(json['newAssignmentsThisWeek']),
    );
  }
}

class TherapistDashboardPatient {
  final int id;
  final String name;
  final int? age;
  final String? gender;
  final String? phone;
  final String? address;
  final String? avatar;
  final String priority; // Critical | High | Medium | Low
  final String careType;
  final String? condition;
  final String? assignedAt;
  final String? assignedAtDisplay;
  final String? assignmentNotes;
  final int sessionsCount;
  final String? lastSessionDate;
  final String lastSessionDisplay;
  final int? daysSinceLastSession;

  TherapistDashboardPatient({
    required this.id,
    required this.name,
    this.age,
    this.gender,
    this.phone,
    this.address,
    this.avatar,
    required this.priority,
    required this.careType,
    this.condition,
    this.assignedAt,
    this.assignedAtDisplay,
    this.assignmentNotes,
    required this.sessionsCount,
    this.lastSessionDate,
    required this.lastSessionDisplay,
    this.daysSinceLastSession,
  });

  factory TherapistDashboardPatient.fromJson(Map<String, dynamic> json) {
    int? iN(dynamic v) => v == null ? null : (v is int ? v : int.tryParse('$v'));
    return TherapistDashboardPatient(
      id: iN(json['id']) ?? 0,
      name: json['name']?.toString() ?? 'Unknown Patient',
      age: iN(json['age']),
      gender: json['gender']?.toString(),
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      avatar: json['avatar']?.toString(),
      priority: json['priority']?.toString() ?? 'Medium',
      careType: json['careType']?.toString() ?? 'General Care',
      condition: json['condition']?.toString(),
      assignedAt: json['assignedAt']?.toString(),
      assignedAtDisplay: json['assignedAtDisplay']?.toString(),
      assignmentNotes: json['assignmentNotes']?.toString(),
      sessionsCount: iN(json['sessionsCount']) ?? 0,
      lastSessionDate: json['lastSessionDate']?.toString(),
      lastSessionDisplay: json['lastSessionDisplay']?.toString() ?? 'No sessions yet',
      daysSinceLastSession: iN(json['daysSinceLastSession']),
    );
  }
}

class TherapistDashboardNote {
  final int id;
  final int patientId;
  final String therapyType;
  final String therapyTypeLabel;
  final String? sessionDate;
  final String? sessionTime;
  final String? sessionDateDisplay;
  final String note;
  final String excerpt;
  final String? patientName;
  final String? patientAvatar;
  final bool isEditable;
  final String? createdAt;

  TherapistDashboardNote({
    required this.id,
    required this.patientId,
    required this.therapyType,
    required this.therapyTypeLabel,
    this.sessionDate,
    this.sessionTime,
    this.sessionDateDisplay,
    required this.note,
    required this.excerpt,
    this.patientName,
    this.patientAvatar,
    this.isEditable = false,
    this.createdAt,
  });

  factory TherapistDashboardNote.fromJson(Map<String, dynamic> json) {
    final patient = json['patient'] is Map ? Map<String, dynamic>.from(json['patient']) : null;
    int i(dynamic v) => v is int ? v : int.tryParse('${v ?? 0}') ?? 0;
    return TherapistDashboardNote(
      id: i(json['id']),
      patientId: i(json['patient_id'] ?? patient?['id']),
      therapyType: json['therapy_type']?.toString() ?? '',
      therapyTypeLabel: json['therapy_type_label']?.toString() ?? 'Therapy',
      sessionDate: json['session_date']?.toString(),
      sessionTime: json['session_time']?.toString(),
      sessionDateDisplay: json['sessionDateDisplay']?.toString(),
      note: json['note']?.toString() ?? '',
      excerpt: json['excerpt']?.toString() ?? (json['note']?.toString() ?? ''),
      patientName: patient?['name']?.toString(),
      patientAvatar: patient?['avatar']?.toString(),
      isEditable: json['is_editable'] == true,
      createdAt: json['created_at']?.toString(),
    );
  }
}

class TherapistWeeklyActivityDay {
  final String date;
  final String dayLabel;
  final bool isToday;
  final int count;

  TherapistWeeklyActivityDay({
    required this.date,
    required this.dayLabel,
    required this.isToday,
    required this.count,
  });

  factory TherapistWeeklyActivityDay.fromJson(Map<String, dynamic> json) {
    return TherapistWeeklyActivityDay(
      date: json['date']?.toString() ?? '',
      dayLabel: json['dayLabel']?.toString() ?? '',
      isToday: json['isToday'] == true,
      count: json['count'] is int ? json['count'] : int.tryParse('${json['count'] ?? 0}') ?? 0,
    );
  }
}
