/// Care Request Models
/// 
/// This file contains all data models for the Care Request feature

// ============================================================================
// REQUEST MODELS
// ============================================================================
import '../payment/payment_models.dart'; 

/// Request model for creating a new care request
class CreateCareRequestRequest {
  final String careType;
  final String urgencyLevel;
  final String description;
  final String? specialRequirements;
  final String serviceAddress;
  final String city;
  final String? region;
  final String? preferredStartDate;
  final String? preferredTime;
  final bool shareWithEmergencyContact;

  CreateCareRequestRequest({
    required this.careType,
    required this.urgencyLevel,
    required this.description,
    this.specialRequirements,
    required this.serviceAddress,
    required this.city,
    this.region,
    this.preferredStartDate,
    this.preferredTime,
    this.shareWithEmergencyContact = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'care_type': careType,
      'urgency_level': urgencyLevel,
      'description': description,
      'special_requirements': specialRequirements,
      'service_address': serviceAddress,
      'city': city,
      'region': region,
      'preferred_start_date': preferredStartDate,
      'preferred_time': preferredTime,
      'share_with_emergency_contact': shareWithEmergencyContact,
    };
  }
}

// ============================================================================
// RESPONSE MODELS
// ============================================================================

/// Response model for care request info (assessment fee, etc.)
class CareRequestInfoResponse {
  final bool success;
  final String message;
  final CareRequestInfo? data;

  CareRequestInfoResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory CareRequestInfoResponse.fromJson(Map<String, dynamic> json) {
    return CareRequestInfoResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null 
          ? CareRequestInfo.fromJson(json['data'])
          : null,
    );
  }
}

class CareRequestInfo {
  final AssessmentFee assessmentFee;
  final String? careType;
  final String? region;
  final String? description;

  CareRequestInfo({
    required this.assessmentFee,
    this.careType,
    this.region,
    this.description,
  });

  factory CareRequestInfo.fromJson(Map<String, dynamic> json) {
    return CareRequestInfo(
      assessmentFee: AssessmentFee.fromJson(
        json['assessment_fee'] is Map 
            ? json['assessment_fee'] 
            : {'amount': json['assessment_fee'] ?? 0, 'currency': 'GHS'}
      ),
      careType: json['care_type'],
      region: json['region'],
      description: json['description'],
    );
  }
}

/// Assessment Fee structure
class AssessmentFee {
  final double amount;
  final double tax;
  final double total;
  final String currency;

  AssessmentFee({
    required this.amount,
    required this.tax,
    required this.total,
    required this.currency,
  });

factory AssessmentFee.fromJson(Map<String, dynamic> json) {
  final amount = _parseDouble(json['amount']);
  final tax = _parseDouble(json['tax']);
  final total = _parseDouble(json['total']) == 0.0 ? amount : _parseDouble(json['total']);
  
  return AssessmentFee(
    amount: amount,
    tax: tax,
    total: total,
    currency: json['currency'] ?? 'GHS',
  );
}

// Add this helper method
static double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    return double.tryParse(value) ?? 0.0;
  }
  return 0.0;
}

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'tax': tax,
      'total': total,
      'currency': currency,
    };
  }
}

/// Response model for listing care requests
class CareRequestsResponse {
  final bool success;
  final String message;
  final List<CareRequest> data;
  final PaginationMeta? pagination;

  CareRequestsResponse({
    required this.success,
    required this.message,
    required this.data,
    this.pagination,
  });

  factory CareRequestsResponse.fromJson(Map<String, dynamic> json) {
    return CareRequestsResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: (json['data'] as List<dynamic>?)
              ?.map((item) => CareRequest.fromJson(item))
              .toList() ??
          [],
      pagination: json['pagination'] != null
          ? PaginationMeta.fromJson(json['pagination'])
          : null,
    );
  }
}

/// Response model for getting a single care request detail
class CareRequestDetailResponse {
  final bool success;
  final String message;
  final CareRequest? data;

  CareRequestDetailResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory CareRequestDetailResponse.fromJson(Map<String, dynamic> json) {
    return CareRequestDetailResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null 
          ? CareRequest.fromJson(json['data'])
          : null,
    );
  }
}

/// Response model for creating a care request
class CreateCareRequestResponse {
  final bool success;
  final String message;
  final CareRequest? data;
  final Payment? payment;

  CreateCareRequestResponse({
    required this.success,
    required this.message,
    this.data,
    this.payment, 
  });

  factory CreateCareRequestResponse.fromJson(Map<String, dynamic> json) {
    // Handle the nested structure from Laravel
    CareRequest? careRequest;
    Payment? payment;
    
    if (json['data'] != null) {
      // Check if data contains 'care_request' (nested structure from Laravel)
      if (json['data']['care_request'] != null) {
        careRequest = CareRequest.fromJson(json['data']['care_request']);
        // Also get payment if available
        if (json['data']['payment'] != null) {
          payment = Payment.fromJson(json['data']['payment']);
        }
      } else {
        // Fall back to direct parsing if not nested
        careRequest = CareRequest.fromJson(json['data']);
      }
    }
    
    return CreateCareRequestResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: careRequest,
      payment: payment,
    );
  }
}

/// Response model for cancelling a care request
class CancelCareRequestResponse {
  final bool success;
  final String message;
  final CareRequest? data;

  CancelCareRequestResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory CancelCareRequestResponse.fromJson(Map<String, dynamic> json) {
    return CancelCareRequestResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null 
          ? CareRequest.fromJson(json['data'])
          : null,
    );
  }
}

/// Response model for initiating payment
class InitiatePaymentResponse {
  final bool success;
  final String message;
  final PaymentInitiation? data;

  InitiatePaymentResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory InitiatePaymentResponse.fromJson(Map<String, dynamic> json) {
    return InitiatePaymentResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null 
          ? PaymentInitiation.fromJson(json['data'])
          : null,
    );
  }
}

/// Response model for verifying payment
class VerifyPaymentResponse {
  final bool success;
  final String message;
  final PaymentVerification? data;

  VerifyPaymentResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory VerifyPaymentResponse.fromJson(Map<String, dynamic> json) {
    return VerifyPaymentResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null 
          ? PaymentVerification.fromJson(json['data'])
          : null,
    );
  }
}

// ============================================================================
// DATA MODELS
// ============================================================================

/// Care Request data model
// In your care_request_models.dart file, make sure the CareRequest model has this:

/// Care Request data model with all datetime fields
class CareRequest {
  final int id;
  final int patientId;
  final int? assignedNurseId;
  final int? medicalAssessmentId;
  final String careType;
  final String urgencyLevel;
  final String description;
  final String? specialRequirements;
  final String? preferredLanguage;
  final String? preferredStartDate;
  final String? preferredTime;
  final String serviceAddress;
  final String? city;
  final String? region;
  final double? latitude;
  final double? longitude;
  final String status;
  final String? rejectionReason;
  final String? adminNotes;
  
  // Datetime fields
  final DateTime? assessmentScheduledAt;
  final DateTime? assessmentCompletedAt;
  final DateTime? careStartedAt;
  final DateTime? careEndedAt;
  final DateTime? cancelledAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Relationships
  final Payment? assessmentPayment;
  final Payment? carePayment;

  CareRequest({
    required this.id,
    required this.patientId,
    this.assignedNurseId,
    this.medicalAssessmentId,
    required this.careType,
    required this.urgencyLevel,
    required this.description,
    this.specialRequirements,
    this.preferredLanguage,
    this.preferredStartDate,
    this.preferredTime,
    required this.serviceAddress,
    this.city,
    this.region,
    this.latitude,
    this.longitude,
    required this.status,
    this.rejectionReason,
    this.adminNotes,
    this.assessmentScheduledAt,
    this.assessmentCompletedAt,
    this.careStartedAt,
    this.careEndedAt,
    this.cancelledAt,
    required this.createdAt,
    required this.updatedAt,
    this.assessmentPayment,
    this.carePayment,
  });

  factory CareRequest.fromJson(Map<String, dynamic> json) {
    print('📊 [CareRequest] Parsing JSON: ${json.toString()}');
    print('🆔 [CareRequest] ID value: ${json['id']}, Type: ${json['id'].runtimeType}');
    
    return CareRequest(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      patientId: json['patient_id'] is int 
          ? json['patient_id'] 
          : int.parse(json['patient_id'].toString()),
      assignedNurseId: json['assigned_nurse_id'],
      medicalAssessmentId: json['medical_assessment_id'],
      careType: json['care_type'] ?? '',
      urgencyLevel: json['urgency_level'] ?? 'routine',
      description: json['description'] ?? '',
      specialRequirements: json['special_requirements'],
      preferredLanguage: json['preferred_language'],
      preferredStartDate: json['preferred_start_date'],
      preferredTime: json['preferred_time'],
      serviceAddress: json['service_address'] ?? '',
      city: json['city'],
      region: json['region'],
      latitude: json['latitude'] != null 
          ? double.tryParse(json['latitude'].toString()) 
          : null,
      longitude: json['longitude'] != null 
          ? double.tryParse(json['longitude'].toString()) 
          : null,
      status: json['status'] ?? 'pending_payment',
      rejectionReason: json['rejection_reason'],
      adminNotes: json['admin_notes'],
      
      // Parse datetime fields
      assessmentScheduledAt: json['assessment_scheduled_at'] != null
          ? DateTime.parse(json['assessment_scheduled_at'])
          : null,
      assessmentCompletedAt: json['assessment_completed_at'] != null
          ? DateTime.parse(json['assessment_completed_at'])
          : null,
      careStartedAt: json['care_started_at'] != null
          ? DateTime.parse(json['care_started_at'])
          : null,
      careEndedAt: json['care_ended_at'] != null
          ? DateTime.parse(json['care_ended_at'])
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'])
          : null,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String()
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String()
      ),
      
      // Parse relationships
      assessmentPayment: json['assessment_payment'] != null
          ? Payment.fromJson(json['assessment_payment'])
          : null,
      carePayment: json['care_payment'] != null
          ? Payment.fromJson(json['care_payment'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'assigned_nurse_id': assignedNurseId,
      'medical_assessment_id': medicalAssessmentId,
      'care_type': careType,
      'urgency_level': urgencyLevel,
      'description': description,
      'special_requirements': specialRequirements,
      'preferred_language': preferredLanguage,
      'preferred_start_date': preferredStartDate,
      'preferred_time': preferredTime,
      'service_address': serviceAddress,
      'city': city,
      'region': region,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'rejection_reason': rejectionReason,
      'admin_notes': adminNotes,
      'assessment_scheduled_at': assessmentScheduledAt?.toIso8601String(),
      'assessment_completed_at': assessmentCompletedAt?.toIso8601String(),
      'care_started_at': careStartedAt?.toIso8601String(),
      'care_ended_at': careEndedAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'assessment_payment': assessmentPayment?.toJson(),
      'care_payment': carePayment?.toJson(),
    };
  }
  
  /// Helper method to check if assessment is scheduled
  bool get hasScheduledAssessment => assessmentScheduledAt != null;
  
  /// Helper method to check if assessment is completed
  bool get hasCompletedAssessment => assessmentCompletedAt != null;
  
  /// Helper method to check if care has started
  bool get hasCareStarted => careStartedAt != null;
  
  /// Helper method to check if care has ended
  bool get hasCareEnded => careEndedAt != null;
  
  /// Helper method to check if request is cancelled
  bool get isCancelled => cancelledAt != null;
}

/// Payment Initiation data model
class PaymentInitiation {
  final String reference;
  final String paymentUrl;
  final double amount;
  final String currency;
  final String status;
  final String? checkoutUrl;

  PaymentInitiation({
    required this.reference,
    required this.paymentUrl,
    required this.amount,
    required this.currency,
    required this.status,
    this.checkoutUrl,
  });

  factory PaymentInitiation.fromJson(Map<String, dynamic> json) {
    // Handle both 'payment_url' and 'authorization_url' field names
    final paymentUrl = json['payment_url'] ??
                       json['authorization_url'] ??
                       json['checkout_url'] ??
                       '';
    return PaymentInitiation(
      reference: json['reference'] ?? '',
      paymentUrl: paymentUrl,
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'GHS',
      status: json['status'] ?? 'pending',
      checkoutUrl: json['checkout_url'],
    );
  }
}

/// Payment Verification data model
class PaymentVerification {
  final String reference;
  final String status;
  final double amount;
  final String currency;
  final String? transactionId;
  final CareRequest? careRequest;

  PaymentVerification({
    required this.reference,
    required this.status,
    required this.amount,
    required this.currency,
    this.transactionId,
    this.careRequest,
  });

  factory PaymentVerification.fromJson(Map<String, dynamic> json) {
    return PaymentVerification(
      reference: json['reference'] ?? '',
      status: json['status'] ?? 'pending',
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'GHS',
      transactionId: json['transaction_id'],
      careRequest: json['care_request'] != null
          ? CareRequest.fromJson(json['care_request'])
          : null,
    );
  }
}

/// Pagination metadata
class PaginationMeta {
  final int total;
  final int perPage;
  final int currentPage;
  final int lastPage;
  final int from;
  final int to;

  PaginationMeta({
    required this.total,
    required this.perPage,
    required this.currentPage,
    required this.lastPage,
    required this.from,
    required this.to,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) {
    return PaginationMeta(
      total: json['total'] ?? 0,
      perPage: json['per_page'] ?? 15,
      currentPage: json['current_page'] ?? 1,
      lastPage: json['last_page'] ?? 1,
      from: json['from'] ?? 0,
      to: json['to'] ?? 0,
    );
  }
}

// ============================================================================
// INSTALLMENT MODELS
// ============================================================================

/// Response model for getting installments
class InstallmentsResponse {
  final bool success;
  final String message;
  final InstallmentsData? data;

  InstallmentsResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory InstallmentsResponse.fromJson(Map<String, dynamic> json) {
    return InstallmentsResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null
          ? InstallmentsData.fromJson(json['data'])
          : null,
    );
  }
}

/// Installments data containing all installment information
class InstallmentsData {
  final bool hasInstallments;
  final bool firstPaymentCompleted;
  final List<Installment> installments;
  final List<Installment> completedPayments;
  final InstallmentSummary? summary;
  final InstallmentPaymentConfig? paymentConfig;

  InstallmentsData({
    required this.hasInstallments,
    required this.firstPaymentCompleted,
    required this.installments,
    required this.completedPayments,
    this.summary,
    this.paymentConfig,
  });

  factory InstallmentsData.fromJson(Map<String, dynamic> json) {
    return InstallmentsData(
      hasInstallments: json['has_installments'] ?? false,
      firstPaymentCompleted: json['first_payment_completed'] ?? false,
      installments: (json['installments'] as List<dynamic>?)
              ?.map((item) => Installment.fromJson(item))
              .toList() ??
          [],
      completedPayments: (json['completed_payments'] as List<dynamic>?)
              ?.map((item) => Installment.fromJson(item))
              .toList() ??
          [],
      summary: json['summary'] != null
          ? InstallmentSummary.fromJson(json['summary'])
          : null,
      paymentConfig: json['payment_config'] != null
          ? InstallmentPaymentConfig.fromJson(json['payment_config'])
          : null,
    );
  }

  /// Check if there are pending installments
  bool get hasPendingInstallments => installments.isNotEmpty;

  /// Get the next payable installment
  Installment? get nextPayableInstallment {
    try {
      return installments.firstWhere((i) => i.canPay);
    } catch (e) {
      return null;
    }
  }

  /// Get overdue installments
  List<Installment> get overdueInstallments {
    return installments.where((i) => i.isOverdue).toList();
  }
}

/// Individual installment
class Installment {
  final int id;
  final int installmentNumber;
  final int totalInstallments;
  final String label;
  final double amount;
  final String currency;
  final String status;
  final String? statusLabel;
  final String? dueDate;
  final String? dueDateFormatted;
  final bool isOverdue;
  final int? daysUntilDue;
  final bool canPay;
  final DateTime? paidAt;
  final String? paidAtFormatted;
  final bool isCompleted;
  final bool isPendingStatus;
  final bool isProcessing;
  final bool isFailed;
  // New due status fields from API
  final String? dueStatus; // "overdue|due_today|due_soon|upcoming|paid|no_due_date"
  final String? dueStatusLabel; // "Overdue by 3 days" | "Due Today" | "Due in 5 days" | etc.
  final bool isDueToday;
  final bool isDueSoon; // Within 7 days

  Installment({
    required this.id,
    required this.installmentNumber,
    required this.totalInstallments,
    required this.label,
    required this.amount,
    required this.currency,
    required this.status,
    this.statusLabel,
    this.dueDate,
    this.dueDateFormatted,
    required this.isOverdue,
    this.daysUntilDue,
    required this.canPay,
    this.paidAt,
    this.paidAtFormatted,
    this.isCompleted = false,
    this.isPendingStatus = false,
    this.isProcessing = false,
    this.isFailed = false,
    this.dueStatus,
    this.dueStatusLabel,
    this.isDueToday = false,
    this.isDueSoon = false,
  });

  factory Installment.fromJson(Map<String, dynamic> json) {
    return Installment(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      installmentNumber: _parseInt(json['installment_number']) ?? 1,
      totalInstallments: _parseInt(json['total_installments']) ?? 1,
      label: json['label'] ?? '',
      amount: _parseDouble(json['amount']),
      currency: json['currency'] ?? 'GHS',
      status: json['status'] ?? 'pending',
      statusLabel: json['status_label'],
      dueDate: json['due_date'],
      dueDateFormatted: json['due_date_formatted'],
      isOverdue: json['is_overdue'] ?? false,
      daysUntilDue: _parseInt(json['days_until_due']),
      canPay: json['can_pay'] ?? false,
      paidAt: json['paid_at'] != null
          ? DateTime.tryParse(json['paid_at'].toString())
          : null,
      paidAtFormatted: json['paid_at_formatted'],
      isCompleted: json['is_completed'] ?? false,
      isPendingStatus: json['is_pending'] ?? false,
      isProcessing: json['is_processing'] ?? false,
      isFailed: json['is_failed'] ?? false,
      // New due status fields
      dueStatus: json['due_status'],
      dueStatusLabel: json['due_status_label'],
      isDueToday: json['is_due_today'] ?? false,
      isDueSoon: json['is_due_soon'] ?? false,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  /// Check if installment is paid
  bool get isPaid => isCompleted || status == 'paid' || status == 'completed';

  /// Check if installment is pending (computed fallback)
  bool get isPending => isPendingStatus || status == 'pending';

  /// Get formatted amount
  String get formattedAmount => '$currency ${amount.toStringAsFixed(2)}';

  /// Get status display text
  String get statusDisplayText {
    if (statusLabel != null && statusLabel!.isNotEmpty) {
      return statusLabel!;
    }
    switch (status.toLowerCase()) {
      case 'paid':
      case 'completed':
        return 'Paid';
      case 'pending':
        return 'Pending';
      case 'overdue':
        return 'Overdue';
      case 'processing':
        return 'Processing';
      case 'failed':
        return 'Failed';
      default:
        return status;
    }
  }
}

/// Summary of installment payments
class InstallmentSummary {
  final double totalAmount;
  final double paidAmount;
  final double remainingAmount;
  final String currency;
  final String? nextPaymentDue;
  final int overdueCount;
  final int totalInstallments;
  final int paidInstallments;
  final int remainingInstallments;
  final double? totalCareCost;
  final double? paymentProgressPercentage;
  final double? totalPaid;
  final double? totalRemaining;
  // New due status fields from API
  final bool hasOverdue;
  final int dueTodayCount;
  final int dueSoonCount;
  final NextPaymentInfo? nextPayment;

  InstallmentSummary({
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.currency,
    this.nextPaymentDue,
    required this.overdueCount,
    required this.totalInstallments,
    required this.paidInstallments,
    required this.remainingInstallments,
    this.totalCareCost,
    this.paymentProgressPercentage,
    this.totalPaid,
    this.totalRemaining,
    this.hasOverdue = false,
    this.dueTodayCount = 0,
    this.dueSoonCount = 0,
    this.nextPayment,
  });

  factory InstallmentSummary.fromJson(Map<String, dynamic> json) {
    return InstallmentSummary(
      totalAmount: _parseDouble(json['total_amount']),
      paidAmount: _parseDouble(json['paid_amount']),
      remainingAmount: _parseDouble(json['remaining_amount']),
      currency: json['currency'] ?? 'GHS',
      nextPaymentDue: json['next_payment_due'],
      overdueCount: _parseInt(json['overdue_count']) ?? 0,
      totalInstallments: _parseInt(json['total_installments']) ?? 0,
      paidInstallments: _parseInt(json['paid_installments']) ?? 0,
      remainingInstallments: _parseInt(json['remaining_installments']) ?? 0,
      totalCareCost: _parseDoubleNullable(json['total_care_cost']),
      paymentProgressPercentage: _parseDoubleNullable(json['payment_progress_percentage']),
      totalPaid: _parseDoubleNullable(json['total_paid']),
      totalRemaining: _parseDoubleNullable(json['total_remaining']),
      // New due status fields
      hasOverdue: json['has_overdue'] ?? false,
      dueTodayCount: _parseInt(json['due_today_count']) ?? 0,
      dueSoonCount: _parseInt(json['due_soon_count']) ?? 0,
      nextPayment: json['next_payment'] != null
          ? NextPaymentInfo.fromJson(json['next_payment'])
          : null,
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  static double? _parseDoubleNullable(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  /// Get formatted total amount
  String get formattedTotalAmount => '$currency ${totalAmount.toStringAsFixed(2)}';

  /// Get formatted paid amount
  String get formattedPaidAmount => '$currency ${paidAmount.toStringAsFixed(2)}';

  /// Get formatted remaining amount
  String get formattedRemainingAmount => '$currency ${remainingAmount.toStringAsFixed(2)}';

  /// Get formatted total care cost
  String get formattedTotalCareCost => '$currency ${(totalCareCost ?? totalAmount).toStringAsFixed(2)}';

  /// Get formatted total paid
  String get formattedTotalPaid => '$currency ${(totalPaid ?? paidAmount).toStringAsFixed(2)}';

  /// Get formatted total remaining
  String get formattedTotalRemaining => '$currency ${(totalRemaining ?? remainingAmount).toStringAsFixed(2)}';

  /// Check if there are overdue payments (computed from count if API field not set)
  bool get hasOverduePayments => hasOverdue || overdueCount > 0;

  /// Get progress percentage (uses API value if available)
  double get progressPercentage {
    if (paymentProgressPercentage != null) return paymentProgressPercentage!;
    if (totalInstallments == 0) return 0.0;
    return (paidInstallments / totalInstallments) * 100;
  }
}

/// Next payment information from API
class NextPaymentInfo {
  final int? id;
  final String? dueStatus; // "overdue|due_today|due_soon|upcoming|paid|no_due_date"
  final String? dueStatusLabel; // "Overdue by 3 days" | "Due Today" | "Due in 5 days" | etc.
  final bool isOverdue;
  final bool isDueToday;
  final bool isDueSoon;
  final int? daysUntilDue; // Negative if overdue
  final String? dueDate;
  final String? dueDateFormatted;
  final double? amount;
  final String? currency;

  NextPaymentInfo({
    this.id,
    this.dueStatus,
    this.dueStatusLabel,
    this.isOverdue = false,
    this.isDueToday = false,
    this.isDueSoon = false,
    this.daysUntilDue,
    this.dueDate,
    this.dueDateFormatted,
    this.amount,
    this.currency,
  });

  factory NextPaymentInfo.fromJson(Map<String, dynamic> json) {
    return NextPaymentInfo(
      id: json['id'] is int ? json['id'] : (json['id'] != null ? int.tryParse(json['id'].toString()) : null),
      dueStatus: json['due_status'],
      dueStatusLabel: json['due_status_label'],
      isOverdue: json['is_overdue'] ?? false,
      isDueToday: json['is_due_today'] ?? false,
      isDueSoon: json['is_due_soon'] ?? false,
      daysUntilDue: json['days_until_due'] is int ? json['days_until_due'] : (json['days_until_due'] != null ? int.tryParse(json['days_until_due'].toString()) : null),
      dueDate: json['due_date'],
      dueDateFormatted: json['due_date_formatted'],
      amount: json['amount'] is double ? json['amount'] : (json['amount'] != null ? double.tryParse(json['amount'].toString()) : null),
      currency: json['currency'],
    );
  }

  /// Get formatted amount
  String get formattedAmount => '${currency ?? 'GHS'} ${(amount ?? 0).toStringAsFixed(2)}';
}

/// Payment configuration for installments
class InstallmentPaymentConfig {
  final String publicKey;
  final List<String> supportedChannels;

  InstallmentPaymentConfig({
    required this.publicKey,
    required this.supportedChannels,
  });

  factory InstallmentPaymentConfig.fromJson(Map<String, dynamic> json) {
    return InstallmentPaymentConfig(
      publicKey: json['public_key'] ?? '',
      supportedChannels: (json['supported_channels'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

/// Response model for initiating installment payment
class InstallmentPaymentResponse {
  final bool success;
  final String message;
  final PaymentInitiation? data;

  InstallmentPaymentResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory InstallmentPaymentResponse.fromJson(Map<String, dynamic> json) {
    return InstallmentPaymentResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null
          ? PaymentInitiation.fromJson(json['data'])
          : null,
    );
  }
}