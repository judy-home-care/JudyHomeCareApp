import 'package:flutter/material.dart';

class NurseScheduleResponse {
  final bool success;
  final List<ScheduleItem> data;
  final Map<String, int>? counts;
  final String? message;

  NurseScheduleResponse({
    required this.success,
    required this.data,
    this.counts,
    this.message,
  });

  factory NurseScheduleResponse.fromJson(Map<String, dynamic> json) {
    return NurseScheduleResponse(
      success: json['success'] as bool? ?? false,
      data: (json['data'] as List<dynamic>?)
              ?.map((e) => ScheduleItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      counts: json['counts'] != null 
          ? Map<String, int>.from(json['counts'] as Map) 
          : null,
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


class RescheduleRequestInfo {
  final int id;
  final String status; // pending, approved, rejected
  final String reason;
  final DateTime? preferredDate;
  final String? preferredTime;
  final DateTime submittedAt;
  final DateTime? respondedAt;
  final String? adminNotes;
  final DateTime? newScheduleDate;
  final String? newStartTime;
  final String? newEndTime;

  RescheduleRequestInfo({
    required this.id,
    required this.status,
    required this.reason,
    this.preferredDate,
    this.preferredTime,
    required this.submittedAt,
    this.respondedAt,
    this.adminNotes,
    this.newScheduleDate,
    this.newStartTime,
    this.newEndTime,
  });

  factory RescheduleRequestInfo.fromJson(Map<String, dynamic> json) {
    return RescheduleRequestInfo(
      id: json['id'] as int,
      status: json['status']?.toString() ?? 'pending',
      reason: json['reason']?.toString() ?? '',
      preferredDate: json['preferredDate'] != null
          ? DateTime.tryParse(json['preferredDate'].toString())
          : null,
      preferredTime: json['preferredTime']?.toString(),
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'].toString())
          : DateTime.now(),
      respondedAt: json['respondedAt'] != null
          ? DateTime.tryParse(json['respondedAt'].toString())
          : null,
      adminNotes: json['adminNotes']?.toString(),
      newScheduleDate: json['newScheduleDate'] != null
          ? DateTime.tryParse(json['newScheduleDate'].toString())
          : null,
      newStartTime: json['newStartTime']?.toString(),
      newEndTime: json['newEndTime']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status,
    'reason': reason,
    'preferredDate': preferredDate?.toIso8601String(),
    'preferredTime': preferredTime,
    'submittedAt': submittedAt.toIso8601String(),
    'respondedAt': respondedAt?.toIso8601String(),
    'adminNotes': adminNotes,
    'newScheduleDate': newScheduleDate?.toIso8601String(),
    'newStartTime': newStartTime,
    'newEndTime': newEndTime,
  };

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  String get statusDisplayText {
    switch (status) {
      case 'pending':
        return 'Pending Review';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }

  Color get statusColor {
    switch (status) {
      case 'pending':
        return const Color(0xFFFF9A00);
      case 'approved':
        return const Color(0xFF4CAF50);
      case 'rejected':
        return const Color(0xFFE53935);
      default:
        return Colors.grey;
    }
  }

  IconData get statusIcon {
    switch (status) {
      case 'pending':
        return Icons.hourglass_top;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }
}


class ScheduleItem {
  final String id;
  final String patientName;  // For nurses: patient name | For patients: nurse name
  final int? patientAge;
  final DateTime date;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? startDateDisplay;
  final String? endDateDisplay;
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
  final bool hasPendingRescheduleRequest;
  final RescheduleRequestInfo? rescheduleRequest;
  final bool isMultiDay;
  final int? totalDays;
  final int? dayNumber;
  final String? dayLabel;

  ScheduleItem({
    required this.id,
    required this.patientName,
    this.patientAge,
    required this.date,
    this.startDate,
    this.endDate,
    this.startDateDisplay,
    this.endDateDisplay,
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
    this.hasPendingRescheduleRequest = false,
    this.rescheduleRequest,
    this.isMultiDay = false,
    this.totalDays,
    this.dayNumber,
    this.dayLabel,
  });

  /// Get formatted date range display for multi-day schedules
  String get dateRangeDisplay {
    if (isMultiDay && startDateDisplay != null && endDateDisplay != null) {
      return '$startDateDisplay - $endDateDisplay';
    }
    return startDateDisplay ?? '';
  }

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

    // Determine isCompleted from API response
    final computedIsCompleted = json['isCompleted'] == true ||
                                json['isCompleted'] == 'true' ||
                                json['status']?.toString().toLowerCase() == 'completed';

    return ScheduleItem(
      id: json['id']?.toString() ?? '',
      patientName: displayName,
      patientAge: json['patientAge'] as int?,
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'].toString())
          : null,
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'].toString())
          : null,
      startDateDisplay: json['startDateDisplay']?.toString(),
      endDateDisplay: json['endDateDisplay']?.toString(),
      startTime: json['startTime']?.toString() ?? '00:00',
      endTime: json['endTime']?.toString() ?? '00:00',
      shiftType: json['shiftType']?.toString() ??
                 _inferShiftType(json['startTime']?.toString()),
      location: json['location']?.toString() ?? 'Location not specified',
      careType: json['careType']?.toString() ?? 'General Care',
      status: json['status']?.toString() ?? 'scheduled',
      notes: json['notes']?.toString() ?? '',
      isCompleted: computedIsCompleted,
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
      // Parse the reschedule flag - handle both boolean and integer
      hasPendingRescheduleRequest: json['hasPendingRescheduleRequest'] == true ||
          json['hasPendingRescheduleRequest'] == 1 ||
          json['has_pending_reschedule'] == true ||
          json['has_pending_reschedule'] == 1,
      isMultiDay: json['isMultiDay'] == true,
      totalDays: json['totalDays'] as int?,
      dayNumber: json['dayNumber'] as int?,
      dayLabel: json['dayLabel']?.toString(),
      // Parse reschedule request details if available
      rescheduleRequest: json['rescheduleRequest'] != null
          ? RescheduleRequestInfo.fromJson(json['rescheduleRequest'] as Map<String, dynamic>)
          : null,
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
        'hasPendingRescheduleRequest': hasPendingRescheduleRequest,
        'rescheduleRequest': rescheduleRequest?.toJson(),
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
    bool? hasPendingRescheduleRequest,
    RescheduleRequestInfo? rescheduleRequest,
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
      hasPendingRescheduleRequest: hasPendingRescheduleRequest ?? this.hasPendingRescheduleRequest,
      rescheduleRequest: rescheduleRequest ?? this.rescheduleRequest,
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
        other.nursePhone == nursePhone &&
        other.hasPendingRescheduleRequest == hasPendingRescheduleRequest &&
        other.rescheduleRequest == rescheduleRequest;
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
        nursePhone.hashCode ^
        hasPendingRescheduleRequest.hashCode ^
        rescheduleRequest.hashCode;
  }

  @override
  String toString() {
    return 'ScheduleItem(id: $id, patientName: $patientName, date: $date, startTime: $startTime, endTime: $endTime, status: $status, hasPendingReschedule: $hasPendingRescheduleRequest, rescheduleRequest: $rescheduleRequest)';
  }
}