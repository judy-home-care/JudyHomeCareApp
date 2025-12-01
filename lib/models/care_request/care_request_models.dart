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
    return PaymentInitiation(
      reference: json['reference'] ?? '',
      paymentUrl: json['payment_url'] ?? '',
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