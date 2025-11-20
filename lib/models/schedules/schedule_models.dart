class NurseScheduleResponse {
  final bool success;
  final List<ScheduleItem> data;
  final Map<String, int> counts;
  final String? message;

  NurseScheduleResponse({
    required this.success,
    required this.data,
    required this.counts,
    this.message,
  });

  factory NurseScheduleResponse.fromJson(Map<String, dynamic> json) {
    return NurseScheduleResponse(
      success: json['success'] as bool? ?? false,
      data: (json['data'] as List<dynamic>?)
              ?.map((e) => ScheduleItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      counts: Map<String, int>.from(json['counts'] as Map? ?? {}),
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'success': success,
        'data': data.map((e) => e.toJson()).toList(),
        'counts': counts,
        'message': message,
      };
}

class ScheduleItem {
  final String id;
  final String patientName;  // For nurses: patient name | For patients: nurse name
  final int? patientAge;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String shiftType;
  final String location;
  final String careType;
  final String status;
  final String notes;
  final bool isCompleted;
  final String priority;
  final String? carePlanId;
  final String? carePlanTitle;
  final DateTime? actualStartTime;
  final DateTime? actualEndTime;
  final DateTime? confirmedAt;
  final String? nursePhone;  // Only for patients viewing schedules

  ScheduleItem({
    required this.id,
    required this.patientName,
    this.patientAge,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.shiftType,
    required this.location,
    required this.careType,
    required this.status,
    this.notes = '',
    this.isCompleted = false,
    this.priority = 'medium',
    this.carePlanId,
    this.carePlanTitle,
    this.actualStartTime,
    this.actualEndTime,
    this.confirmedAt,
    this.nursePhone,
  });

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    // Handle both nurse view (patientName) and patient view (nurseName)
    String displayName = 'Unknown';
    
    // For patients: backend sends nurseName
    if (json['nurseName'] != null) {
      displayName = json['nurseName'].toString();
    } 
    // For nurses: backend sends patientName
    else if (json['patientName'] != null) {
      displayName = json['patientName'].toString();
    }

    return ScheduleItem(
      id: json['id']?.toString() ?? '',
      patientName: displayName,
      patientAge: json['patientAge'] as int?,
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      startTime: json['startTime']?.toString() ?? '00:00',
      endTime: json['endTime']?.toString() ?? '00:00',
      shiftType: json['shiftType']?.toString() ?? 
                 _inferShiftType(json['startTime']?.toString()),
      location: json['location']?.toString() ?? 'Location not specified',
      careType: json['careType']?.toString() ?? 'General Care',
      status: json['status']?.toString() ?? 'scheduled',
      notes: json['notes']?.toString() ?? '',
      isCompleted: json['isCompleted'] == true || 
                   json['isCompleted'] == 'true' ||
                   json['status']?.toString().toLowerCase() == 'completed',
      priority: json['priority']?.toString() ?? 'medium',
      carePlanId: json['carePlanId']?.toString(),
      carePlanTitle: json['carePlanTitle']?.toString(),
      actualStartTime: json['actualStartTime'] != null
          ? DateTime.tryParse(json['actualStartTime'].toString())
          : null,
      actualEndTime: json['actualEndTime'] != null
          ? DateTime.tryParse(json['actualEndTime'].toString())
          : null,
      confirmedAt: json['confirmedAt'] != null
          ? DateTime.tryParse(json['confirmedAt'].toString())
          : null,
      nursePhone: json['nursePhone']?.toString(),
    );
  }

  /// Helper method to infer shift type from start time if not provided
  static String _inferShiftType(String? startTime) {
    if (startTime == null || startTime.isEmpty) return 'General Shift';

    try {
      // Remove extra spaces and convert to uppercase
      final timeStr = startTime.trim().toUpperCase();
      
      // Extract hour and AM/PM
      final isPM = timeStr.contains('PM');
      final isAM = timeStr.contains('AM');
      
      // Parse the hour
      final timeParts = timeStr.replaceAll(RegExp(r'[^0-9:]'), '').split(':');
      if (timeParts.isEmpty) return 'General Shift';
      
      int hour = int.tryParse(timeParts[0]) ?? 12;

      // Convert to 24-hour format
      int hour24 = hour;
      if (isPM && hour != 12) {
        hour24 = hour + 12;
      } else if (isAM && hour == 12) {
        hour24 = 0;
      }

      // Determine shift based on 24-hour time
      // Morning: 6 AM - 2 PM (6:00 - 13:59)
      // Afternoon: 2 PM - 10 PM (14:00 - 21:59)
      // Night: 10 PM - 6 AM (22:00 - 5:59)
      if (hour24 >= 6 && hour24 < 14) {
        return 'Morning Shifts';
      } else if (hour24 >= 14 && hour24 < 22) {
        return 'Afternoon Shifts';
      } else {
        return 'Night Shifts';
      }
    } catch (e) {
      return 'General Shift';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientName': patientName,
        'patientAge': patientAge,
        'date': date.toIso8601String(),
        'startTime': startTime,
        'endTime': endTime,
        'shiftType': shiftType,
        'location': location,
        'careType': careType,
        'status': status,
        'notes': notes,
        'isCompleted': isCompleted,
        'priority': priority,
        'carePlanId': carePlanId,
        'carePlanTitle': carePlanTitle,
        'actualStartTime': actualStartTime?.toIso8601String(),
        'actualEndTime': actualEndTime?.toIso8601String(),
        'confirmedAt': confirmedAt?.toIso8601String(),
        'nursePhone': nursePhone,
      };

  /// Create a copy with updated fields
  ScheduleItem copyWith({
    String? id,
    String? patientName,
    int? patientAge,
    DateTime? date,
    String? startTime,
    String? endTime,
    String? shiftType,
    String? location,
    String? careType,
    String? status,
    String? notes,
    bool? isCompleted,
    String? priority,
    String? carePlanId,
    String? carePlanTitle,
    DateTime? actualStartTime,
    DateTime? actualEndTime,
    DateTime? confirmedAt,
    String? nursePhone,
  }) {
    return ScheduleItem(
      id: id ?? this.id,
      patientName: patientName ?? this.patientName,
      patientAge: patientAge ?? this.patientAge,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      shiftType: shiftType ?? this.shiftType,
      location: location ?? this.location,
      careType: careType ?? this.careType,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      carePlanId: carePlanId ?? this.carePlanId,
      carePlanTitle: carePlanTitle ?? this.carePlanTitle,
      actualStartTime: actualStartTime ?? this.actualStartTime,
      actualEndTime: actualEndTime ?? this.actualEndTime,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      nursePhone: nursePhone ?? this.nursePhone,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ScheduleItem &&
        other.id == id &&
        other.patientName == patientName &&
        other.patientAge == patientAge &&
        other.date == date &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.shiftType == shiftType &&
        other.location == location &&
        other.careType == careType &&
        other.status == status &&
        other.notes == notes &&
        other.isCompleted == isCompleted &&
        other.priority == priority &&
        other.carePlanId == carePlanId &&
        other.carePlanTitle == carePlanTitle &&
        other.actualStartTime == actualStartTime &&
        other.actualEndTime == actualEndTime &&
        other.confirmedAt == confirmedAt &&
        other.nursePhone == nursePhone;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        patientName.hashCode ^
        patientAge.hashCode ^
        date.hashCode ^
        startTime.hashCode ^
        endTime.hashCode ^
        shiftType.hashCode ^
        location.hashCode ^
        careType.hashCode ^
        status.hashCode ^
        notes.hashCode ^
        isCompleted.hashCode ^
        priority.hashCode ^
        carePlanId.hashCode ^
        carePlanTitle.hashCode ^
        actualStartTime.hashCode ^
        actualEndTime.hashCode ^
        confirmedAt.hashCode ^
        nursePhone.hashCode;
  }

  @override
  String toString() {
    return 'ScheduleItem(id: $id, patientName: $patientName, date: $date, startTime: $startTime, endTime: $endTime, status: $status)';
  }
}