// lib/models/notification/notification_models.dart

/// Notification item model
class NotificationItem {
  final int id;
  final int userId;
  final String userType;
  final String notificationType;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final String? notifiableType;
  final int? notifiableId;
  final bool sentViaPush;
  final bool sentViaEmail;
  final bool sentViaSms;
  final String status;
  final String? failureReason;
  final String? fcmMessageId;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime? failedAt;
  final String priority;
  final DateTime? scheduledFor;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isRead;
  final String timeAgo;

  NotificationItem({
    required this.id,
    required this.userId,
    required this.userType,
    required this.notificationType,
    required this.title,
    required this.body,
    this.data,
    this.notifiableType,
    this.notifiableId,
    required this.sentViaPush,
    required this.sentViaEmail,
    required this.sentViaSms,
    required this.status,
    this.failureReason,
    this.fcmMessageId,
    this.sentAt,
    this.deliveredAt,
    this.readAt,
    this.failedAt,
    required this.priority,
    this.scheduledFor,
    required this.createdAt,
    required this.updatedAt,
    required this.isRead,
    required this.timeAgo,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      userType: json['user_type'] ?? 'patient',
      notificationType: json['notification_type'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      data: json['data'] as Map<String, dynamic>?,
      notifiableType: json['notifiable_type'],
      notifiableId: json['notifiable_id'],
      sentViaPush: json['sent_via_push'] ?? false,
      sentViaEmail: json['sent_via_email'] ?? false,
      sentViaSms: json['sent_via_sms'] ?? false,
      status: json['status'] ?? 'pending',
      failureReason: json['failure_reason'],
      fcmMessageId: json['fcm_message_id'],
      sentAt: json['sent_at'] != null ? DateTime.parse(json['sent_at']) : null,
      deliveredAt: json['delivered_at'] != null ? DateTime.parse(json['delivered_at']) : null,
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
      failedAt: json['failed_at'] != null ? DateTime.parse(json['failed_at']) : null,
      priority: json['priority'] ?? 'normal',
      scheduledFor: json['scheduled_for'] != null ? DateTime.parse(json['scheduled_for']) : null,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
      isRead: json['is_read'] ?? false,
      timeAgo: json['time_ago'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_type': userType,
      'notification_type': notificationType,
      'title': title,
      'body': body,
      'data': data,
      'notifiable_type': notifiableType,
      'notifiable_id': notifiableId,
      'sent_via_push': sentViaPush,
      'sent_via_email': sentViaEmail,
      'sent_via_sms': sentViaSms,
      'status': status,
      'failure_reason': failureReason,
      'fcm_message_id': fcmMessageId,
      'sent_at': sentAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
      'failed_at': failedAt?.toIso8601String(),
      'priority': priority,
      'scheduled_for': scheduledFor?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_read': isRead,
      'time_ago': timeAgo,
    };
  }

  /// Get notification icon based on type
  String getIcon() {
    const icons = {
      'appointment_reminder': '📅',
      'medication_reminder': '💊',
      'vitals_reminder': '❤️',
      'care_plan_update': '📋',
      'payment_reminder': '💳',
      'nurse_assigned': '👩‍⚕️',
      'assessment_scheduled': '🏥',
      'care_started': '✅',
      'care_completed': '🎉',
    };
    return icons[notificationType] ?? '🔔';
  }

  /// Get priority color
  String getPriorityColor() {
    switch (priority) {
      case 'urgent':
        return '#FF0000';
      case 'high':
        return '#FF6B00';
      case 'normal':
        return '#007AFF';
      case 'low':
        return '#8E8E93';
      default:
        return '#007AFF';
    }
  }

  /// Get status display text
  String getStatusText() {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'sent':
        return 'Sent';
      case 'delivered':
        return 'Delivered';
      case 'failed':
        return 'Failed';
      case 'read':
        return 'Read';
      default:
        return status;
    }
  }

  /// Copy with method for updating properties
  NotificationItem copyWith({
    int? id,
    int? userId,
    String? userType,
    String? notificationType,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    String? notifiableType,
    int? notifiableId,
    bool? sentViaPush,
    bool? sentViaEmail,
    bool? sentViaSms,
    String? status,
    String? failureReason,
    String? fcmMessageId,
    DateTime? sentAt,
    DateTime? deliveredAt,
    DateTime? readAt,
    DateTime? failedAt,
    String? priority,
    DateTime? scheduledFor,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isRead,
    String? timeAgo,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userType: userType ?? this.userType,
      notificationType: notificationType ?? this.notificationType,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      notifiableType: notifiableType ?? this.notifiableType,
      notifiableId: notifiableId ?? this.notifiableId,
      sentViaPush: sentViaPush ?? this.sentViaPush,
      sentViaEmail: sentViaEmail ?? this.sentViaEmail,
      sentViaSms: sentViaSms ?? this.sentViaSms,
      status: status ?? this.status,
      failureReason: failureReason ?? this.failureReason,
      fcmMessageId: fcmMessageId ?? this.fcmMessageId,
      sentAt: sentAt ?? this.sentAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      failedAt: failedAt ?? this.failedAt,
      priority: priority ?? this.priority,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isRead: isRead ?? this.isRead,
      timeAgo: timeAgo ?? this.timeAgo,
    );
  }
}

/// Notification type constants
class NotificationTypes {
  static const String appointmentReminder = 'appointment_reminder';
  static const String medicationReminder = 'medication_reminder';
  static const String vitalsReminder = 'vitals_reminder';
  static const String carePlanUpdate = 'care_plan_update';
  static const String paymentReminder = 'payment_reminder';
  static const String nurseAssigned = 'nurse_assigned';
  static const String assessmentScheduled = 'assessment_scheduled';
  static const String careStarted = 'care_started';
  static const String careCompleted = 'care_completed';
}

/// Notification status constants
class NotificationStatus {
  static const String pending = 'pending';
  static const String sent = 'sent';
  static const String delivered = 'delivered';
  static const String failed = 'failed';
  static const String read = 'read';
}

/// Notification priority constants
class NotificationPriority {
  static const String low = 'low';
  static const String normal = 'normal';
  static const String high = 'high';
  static const String urgent = 'urgent';
}