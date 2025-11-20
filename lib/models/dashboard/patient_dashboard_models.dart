class PatientDashboardData {
  final double weekHours;
  final int nursesToday;
  final int activePlans;
  final List<ScheduleVisit> scheduleVisits;
  final List<UpcomingNurse> upcomingNurses;

  PatientDashboardData({
    required this.weekHours,
    required this.nursesToday,
    required this.activePlans,
    required this.scheduleVisits,
    required this.upcomingNurses,
  });

  factory PatientDashboardData.fromJson(Map<String, dynamic> json) {
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
    );
  }
}

class ScheduleVisit {
  final int id;
  final String date;
  final String dateDisplay;
  final String time;
  final String? endTime;
  final String duration;
  final String? durationCompleted;
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
    required this.time,
    this.endTime,
    required this.duration,
    this.durationCompleted,
    required this.status,
    required this.carePlanTitle,
    required this.careType,
    required this.priority,
    required this.location,
    this.nurse,
  });

  factory ScheduleVisit.fromJson(Map<String, dynamic> json) {
    return ScheduleVisit(
      id: json['id'] ?? 0,
      date: json['date'] ?? '',
      dateDisplay: json['dateDisplay'] ?? '',
      time: json['time'] ?? '',
      endTime: json['endTime'],
      duration: json['duration'] ?? '0m',
      durationCompleted: json['duration_completed'],
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
  final String? endTime;
  final String timeUntil;
  final bool isToday;
  final String careType;
  final String priority;
  final String location;
  final String duration;
  final List<ScheduleInfo> upcomingSchedules;
  final int totalSchedules;
  final NurseDetail nurse;
  final VitalsInfo? currentVitals;

  UpcomingNurse({
    required this.scheduleId,
    required this.scheduledTime,
    required this.scheduledDate,
    this.endTime,
    required this.timeUntil,
    required this.isToday,
    required this.careType,
    required this.priority,
    required this.location,
    required this.duration,
    required this.upcomingSchedules,
    required this.totalSchedules,
    required this.nurse,
    this.currentVitals,
  });

  factory UpcomingNurse.fromJson(Map<String, dynamic> json) {
    return UpcomingNurse(
      scheduleId: json['scheduleId'] ?? 0,
      scheduledTime: json['scheduledTime'] ?? '',
      scheduledDate: json['scheduledDate'] ?? '',
      endTime: json['endTime'],
      timeUntil: json['timeUntil'] ?? '',
      isToday: json['isToday'] ?? false,
      careType: json['careType'] ?? '',
      priority: json['priority'] ?? 'medium',
      location: json['location'] ?? '',
      duration: json['duration'] ?? '0m',
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
  final String? endTime;
  final String timeUntil;
  final bool isToday;
  final String careType;
  final String location;
  final String duration;

  ScheduleInfo({
    required this.scheduleId,
    required this.scheduledTime,
    required this.scheduledDate,
    this.endTime,
    required this.timeUntil,
    required this.isToday,
    required this.careType,
    required this.location,
    required this.duration,
  });

  factory ScheduleInfo.fromJson(Map<String, dynamic> json) {
    return ScheduleInfo(
      scheduleId: json['scheduleId'] ?? 0,
      scheduledTime: json['scheduledTime'] ?? '',
      scheduledDate: json['scheduledDate'] ?? '',
      endTime: json['endTime'],
      timeUntil: json['timeUntil'] ?? '',
      isToday: json['isToday'] ?? false,
      careType: json['careType'] ?? '',
      location: json['location'] ?? '',
      duration: json['duration'] ?? '0m',
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