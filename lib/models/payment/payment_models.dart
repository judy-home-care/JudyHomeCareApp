// lib/models/payment/payment_models.dart

class PaymentConfig {
  final String publicKey;
  final List<String> supportedChannels;
  final String currency;
  
  PaymentConfig({
    required this.publicKey,
    required this.supportedChannels,
    required this.currency,
  });
  
  factory PaymentConfig.fromJson(Map<String, dynamic> json) {
    return PaymentConfig(
      publicKey: json['public_key'] ?? '',
      supportedChannels: List<String>.from(json['supported_channels'] ?? []),
      currency: json['currency'] ?? 'GHS',
    );
  }
}

class PaymentInitialization {
  final String authorizationUrl;
  final String accessCode;
  final String reference;
  final String? email;
  
  PaymentInitialization({
    required this.authorizationUrl,
    required this.accessCode,
    required this.reference,
    this.email,
  });
  
  factory PaymentInitialization.fromJson(Map<String, dynamic> json) {
    return PaymentInitialization(
      authorizationUrl: json['authorization_url'] ?? '',
      accessCode: json['access_code'] ?? '',
      reference: json['reference'] ?? '',
      email: json['email'],
    );
  }
}

class PaymentVerification {
  final String reference;
  final double amount;
  final String channel;
  final String status;
  final String? paidAt;
  
  PaymentVerification({
    required this.reference,
    required this.amount,
    required this.channel,
    required this.status,
    this.paidAt,
  });
  
  factory PaymentVerification.fromJson(Map<String, dynamic> json) {
    return PaymentVerification(
      reference: json['reference'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      channel: json['channel'] ?? '',
      status: json['status'] ?? '',
      paidAt: json['paid_at'],
    );
  }
}

// ==================== ADDITIONAL MODELS ====================

class Payment {
  final int id;
  final int careRequestId;
  final int patientId;
  final String paymentType;
  final double amount;
  final String currency;
  final double taxAmount;
  final double totalAmount;
  final String paymentMethod;
  final String? paymentProvider;
  final String? transactionId;
  final String referenceNumber;
  final String? providerReference;
  final String status;
  final String? description;
  final String? failureReason;
  final DateTime? paidAt;
  final DateTime? refundedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Payment({
    required this.id,
    required this.careRequestId,
    required this.patientId,
    required this.paymentType,
    required this.amount,
    required this.currency,
    required this.taxAmount,
    required this.totalAmount,
    required this.paymentMethod,
    this.paymentProvider,
    this.transactionId,
    required this.referenceNumber,
    this.providerReference,
    required this.status,
    this.description,
    this.failureReason,
    this.paidAt,
    this.refundedAt,
    required this.createdAt,
    required this.updatedAt,
  });

factory Payment.fromJson(Map<String, dynamic> json) {
  return Payment(
    id: json['id'] ?? 0,
    careRequestId: json['care_request_id'] ?? 0,
    patientId: json['patient_id'] ?? 0,
    paymentType: json['payment_type'] ?? '',
    amount: _parseDouble(json['amount']),
    currency: json['currency'] ?? 'GHS',
    taxAmount: _parseDouble(json['tax_amount']),
    totalAmount: _parseDouble(json['total_amount']),
    paymentMethod: json['payment_method'] ?? '',
    paymentProvider: json['payment_provider'],
    transactionId: json['transaction_id'],
    referenceNumber: json['reference_number'] ?? '',
    providerReference: json['provider_reference'],
    status: json['status'] ?? 'pending',
    description: json['description'],
    failureReason: json['failure_reason'],
    paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
    refundedAt: json['refunded_at'] != null ? DateTime.parse(json['refunded_at']) : null,
    createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    updatedAt: DateTime.parse(json['updated_at'] ?? DateTime.now().toIso8601String()),
  );
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'care_request_id': careRequestId,
      'patient_id': patientId,
      'payment_type': paymentType,
      'amount': amount,
      'currency': currency,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'payment_provider': paymentProvider,
      'transaction_id': transactionId,
      'reference_number': referenceNumber,
      'provider_reference': providerReference,
      'status': status,
      'description': description,
      'failure_reason': failureReason,
      'paid_at': paidAt?.toIso8601String(),
      'refunded_at': refundedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Helper getters
  bool get isPaid => status == 'completed';
  bool get isPending => status == 'pending' || status == 'processing';
  bool get isFailed => status == 'failed';
  bool get isRefunded => status == 'refunded';
  
  String get formattedAmount => '$currency ${totalAmount.toStringAsFixed(2)}';
  
  String get formattedStatus {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'processing':
        return 'Processing';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      case 'refunded':
        return 'Refunded';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
  
  String get formattedPaymentType {
    switch (paymentType) {
      case 'assessment_fee':
        return 'Assessment Fee';
      case 'care_fee':
        return 'Care Fee';
      default:
        return paymentType;
    }
  }
}

class Pagination {
  final int total;
  final int perPage;
  final int currentPage;
  final int lastPage;
  final String? nextPageUrl;
  final String? prevPageUrl;
  final int from;
  final int to;

  Pagination({
    required this.total,
    required this.perPage,
    required this.currentPage,
    required this.lastPage,
    this.nextPageUrl,
    this.prevPageUrl,
    required this.from,
    required this.to,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      total: json['total'] ?? 0,
      perPage: json['per_page'] ?? 15,
      currentPage: json['current_page'] ?? 1,
      lastPage: json['last_page'] ?? 1,
      nextPageUrl: json['next_page_url'],
      prevPageUrl: json['prev_page_url'],
      from: json['from'] ?? 0,
      to: json['to'] ?? 0,
    );
  }

  bool get hasNextPage => nextPageUrl != null;
  bool get hasPrevPage => prevPageUrl != null;
}

class PaymentReceipt {
  final int id;
  final String referenceNumber;
  final String receiptNumber;
  final DateTime paymentDate;
  final String patientName;
  final String patientEmail;
  final String paymentType;
  final String paymentMethod;
  final double amount;
  final double taxAmount;
  final double totalAmount;
  final String currency;
  final String status;
  final String? description;
  final Map<String, dynamic>? metadata;
  
  PaymentReceipt({
    required this.id,
    required this.referenceNumber,
    required this.receiptNumber,
    required this.paymentDate,
    required this.patientName,
    required this.patientEmail,
    required this.paymentType,
    required this.paymentMethod,
    required this.amount,
    required this.taxAmount,
    required this.totalAmount,
    required this.currency,
    required this.status,
    this.description,
    this.metadata,
  });

  factory PaymentReceipt.fromJson(Map<String, dynamic> json) {
    return PaymentReceipt(
      id: json['id'] ?? 0,
      referenceNumber: json['reference_number'] ?? '',
      receiptNumber: json['receipt_number'] ?? '',
      paymentDate: DateTime.parse(json['payment_date'] ?? DateTime.now().toIso8601String()),
      patientName: json['patient_name'] ?? '',
      patientEmail: json['patient_email'] ?? '',
      paymentType: json['payment_type'] ?? '',
      paymentMethod: json['payment_method'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      taxAmount: (json['tax_amount'] ?? 0).toDouble(),
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'GHS',
      status: json['status'] ?? '',
      description: json['description'],
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reference_number': referenceNumber,
      'receipt_number': receiptNumber,
      'payment_date': paymentDate.toIso8601String(),
      'patient_name': patientName,
      'patient_email': patientEmail,
      'payment_type': paymentType,
      'payment_method': paymentMethod,
      'amount': amount,
      'tax_amount': taxAmount,
      'total_amount': totalAmount,
      'currency': currency,
      'status': status,
      'description': description,
      'metadata': metadata,
    };
  }
}

// ==================== OTP MODELS ====================

class SendOtpResponse {
  final bool success;
  final String message;
  final OtpData? data;

  SendOtpResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory SendOtpResponse.fromJson(Map<String, dynamic> json) {
    return SendOtpResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? OtpData.fromJson(json['data']) : null,
    );
  }
}

class OtpData {
  final int otpId;
  final String phoneNumber;
  final String network;
  final String expiresAt;
  final int expiresInSeconds;
  final int? waitSeconds;

  OtpData({
    required this.otpId,
    required this.phoneNumber,
    required this.network,
    required this.expiresAt,
    required this.expiresInSeconds,
    this.waitSeconds,
  });

  factory OtpData.fromJson(Map<String, dynamic> json) {
    return OtpData(
      otpId: json['otp_id'] ?? 0,
      phoneNumber: json['phone_number'] ?? '',
      network: json['network'] ?? '',
      expiresAt: json['expires_at'] ?? '',
      expiresInSeconds: json['expires_in_seconds'] ?? 300,
      waitSeconds: json['wait_seconds'],
    );
  }
}

class VerifyOtpResponse {
  final bool success;
  final String message;
  final OtpVerificationData? data;

  VerifyOtpResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory VerifyOtpResponse.fromJson(Map<String, dynamic> json) {
    return VerifyOtpResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? OtpVerificationData.fromJson(json['data']) : null,
    );
  }
}

class OtpVerificationData {
  final bool verified;
  final String phoneNumber;
  final String network;
  final String? verifiedAt;
  final int? attemptsRemaining;
  final bool? maxAttemptsReached;
  final bool? expired;

  OtpVerificationData({
    required this.verified,
    required this.phoneNumber,
    required this.network,
    this.verifiedAt,
    this.attemptsRemaining,
    this.maxAttemptsReached,
    this.expired,
  });

  factory OtpVerificationData.fromJson(Map<String, dynamic> json) {
    return OtpVerificationData(
      verified: json['verified'] ?? false,
      phoneNumber: json['phone_number'] ?? '',
      network: json['network'] ?? '',
      verifiedAt: json['verified_at'],
      attemptsRemaining: json['attempts_remaining'],
      maxAttemptsReached: json['max_attempts_reached'],
      expired: json['expired'],
    );
  }
}