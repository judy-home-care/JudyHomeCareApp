// lib/services/payment_service.dart

import 'dart:developer';
import '../../utils/api_client.dart';
import '../../utils/api_config.dart';
import '../../models/payment/payment_models.dart';

/// Service for handling Payment API calls
class PaymentService {
  final ApiClient _apiClient = ApiClient();

  // ==================== PAYSTACK CONFIGURATION ====================

  /// Get Paystack configuration (public key and channels)
  /// 
  /// Returns payment configuration including public key and available channels
  Future<PaymentConfigResponse> getPaymentConfig() async {
    try {
      print('📡 [PaymentService] Fetching payment configuration...');
      
      final response = await _apiClient.get(
        ApiConfig.paymentConfigEndpoint,
        requiresAuth: true,
      );

      print('✅ [PaymentService] Configuration response received');
      print('🎯 [PaymentService] Success: ${response['success']}');

      if (response['success'] == true) {
        print('✅ [PaymentService] Payment configuration fetched successfully');
        return PaymentConfigResponse.fromJson(response);
      } else {
        print('❌ [PaymentService] Configuration fetch failed');
        throw PaymentException(
          message: response['message'] ?? 'Failed to fetch payment configuration',
        );
      }
    } catch (e) {
      print('💥 [PaymentService] Error fetching payment config: $e');
      if (e is PaymentException) {
        rethrow;
      }
      throw PaymentException(
        message: 'Network error: Unable to fetch payment configuration',
      );
    }
  }

  // ==================== PAYMENT INITIALIZATION ====================

  /// Initialize payment with Paystack
  /// 
  /// Parameters:
  /// - [careRequestId]: The care request ID to initialize payment for
  /// - [channel]: Payment channel (mobile_money, card, bank)
  /// - [provider]: Payment provider (MTN, Vodafone, etc.)
  /// - [phoneNumber]: Phone number for mobile money
  /// 
  /// Returns payment initialization data including access code and reference
  Future<PaymentInitializationResponse> initializePayment(
    int careRequestId, {
    String? channel,
    String? provider,
    String? phoneNumber,
  }) async {
    try {
      print('📡 [PaymentService] Initializing payment...');
      print('🔗 [PaymentService] Care Request ID: $careRequestId');
      
      final body = <String, dynamic>{};
      
      if (channel != null) body['channel'] = channel;
      if (provider != null) body['provider'] = provider;
      if (phoneNumber != null) body['phone_number'] = phoneNumber;

      final response = await _apiClient.post(
        ApiConfig.initiatePaymentEndpoint(careRequestId),
        body: body,
        requiresAuth: true,
      );

      print('✅ [PaymentService] Payment initialization response received');
      print('🎯 [PaymentService] Success: ${response['success']}');

      if (response['success'] == true) {
        print('✅ [PaymentService] Payment initialized successfully');
        return PaymentInitializationResponse.fromJson(response);
      } else {
        print('❌ [PaymentService] Payment initialization failed');
        throw PaymentException(
          message: response['message'] ?? 'Failed to initialize payment',
        );
      }
    } catch (e) {
      print('💥 [PaymentService] Error initializing payment: $e');
      if (e is PaymentException) {
        rethrow;
      }
      throw PaymentException(
        message: 'Network error: Unable to initialize payment',
      );
    }
  }

  // ==================== PAYMENT VERIFICATION ====================

  /// Verify payment after completion
  /// 
  /// Parameters:
  /// - [reference]: The payment reference to verify
  /// 
  /// Returns verification result with payment status and details
  Future<PaymentVerificationResponse> verifyPayment(String reference) async {
    try {
      print('📡 [PaymentService] Verifying payment...');
      print('🔗 [PaymentService] Reference: $reference');

      final body = {
        'reference': reference,
      };

      final response = await _apiClient.post(
        ApiConfig.paystackVerifyEndpoint,
        body: body,
        requiresAuth: true,
      );

      print('✅ [PaymentService] Verification response received');
      print('🎯 [PaymentService] Success: ${response['success']}');

      if (response['success'] == true) {
        print('✅ [PaymentService] Payment verified successfully');
        print('💰 [PaymentService] Status: ${response['data']?['status']}');
        return PaymentVerificationResponse.fromJson(response);
      } else {
        print('❌ [PaymentService] Payment verification failed');
        print('❌ [PaymentService] Error: ${response['message']}');
        throw PaymentException(
          message: response['message'] ?? 'Payment verification failed',
        );
      }
    } catch (e) {
      print('💥 [PaymentService] Error verifying payment: $e');
      if (e is PaymentException) {
        rethrow;
      }
      throw PaymentException(
        message: 'Network error: Unable to verify payment',
      );
    }
  }

  // ==================== OTP METHODS ====================

  /// Send OTP to mobile money number
  /// 
  /// Parameters:
  /// - [phoneNumber]: The mobile money number
  /// - [network]: The mobile money network (MTN, Vodafone, AirtelTigo)
  /// 
  /// Returns OTP data including expiry time
  Future<SendOtpResponse> sendOtp({
    required String phoneNumber,
    required String network,
  }) async {
    try {
      log('📱 [PaymentService] Sending OTP to $phoneNumber');
      
      final body = {
        'phone_number': phoneNumber,
        'network': network,
      };

      final response = await _apiClient.post(
        '${ApiConfig.mobilePrefix}/payments/send-otp',
        body: body,
        requiresAuth: true,
      );

      log('✅ [PaymentService] OTP send response received');

      if (response['success'] == true) {
        return SendOtpResponse.fromJson(response);
      } else {
        throw PaymentException(
          message: response['message'] ?? 'Failed to send OTP',
        );
      }
    } catch (e) {
      log('💥 [PaymentService] Send OTP error: $e');
      if (e is PaymentException) {
        rethrow;
      }
      throw PaymentException(
        message: 'Failed to send OTP: ${e.toString()}',
      );
    }
  }

  /// Verify OTP code
  /// 
  /// Parameters:
  /// - [phoneNumber]: The mobile money number
  /// - [otpCode]: The 6-digit OTP code
  /// 
  /// Returns verification result
  Future<VerifyOtpResponse> verifyOtp({
    required String phoneNumber,
    required String otpCode,
  }) async {
    try {
      log('🔍 [PaymentService] Verifying OTP for $phoneNumber');
      
      final body = {
        'phone_number': phoneNumber,
        'otp_code': otpCode,
      };

      final response = await _apiClient.post(
        '${ApiConfig.mobilePrefix}/payments/verify-otp',
        body: body,
        requiresAuth: true,
      );

      log('✅ [PaymentService] OTP verification response received');

      if (response['success'] == true) {
        return VerifyOtpResponse.fromJson(response);
      } else {
        return VerifyOtpResponse.fromJson(response); // Return even on failure for detailed error handling
      }
    } catch (e) {
      log('💥 [PaymentService] Verify OTP error: $e');
      throw PaymentException(
        message: 'Failed to verify OTP: ${e.toString()}',
      );
    }
  }

  /// Resend OTP
  /// 
  /// Parameters:
  /// - [phoneNumber]: The mobile money number
  /// - [network]: The mobile money network
  /// 
  /// Returns new OTP data
  Future<SendOtpResponse> resendOtp({
    required String phoneNumber,
    required String network,
  }) async {
    try {
      log('🔄 [PaymentService] Resending OTP to $phoneNumber');
      
      final body = {
        'phone_number': phoneNumber,
        'network': network,
      };

      final response = await _apiClient.post(
        '${ApiConfig.mobilePrefix}/payments/resend-otp',
        body: body,
        requiresAuth: true,
      );

      log('✅ [PaymentService] OTP resend response received');

      if (response['success'] == true) {
        return SendOtpResponse.fromJson(response);
      } else {
        throw PaymentException(
          message: response['message'] ?? 'Failed to resend OTP',
        );
      }
    } catch (e) {
      log('💥 [PaymentService] Resend OTP error: $e');
      if (e is PaymentException) {
        rethrow;
      }
      throw PaymentException(
        message: 'Failed to resend OTP: ${e.toString()}',
      );
    }
  }

  // ==================== PAYMENT HISTORY ====================

  /// Get payment history for the current user
  /// 
  /// Parameters:
  /// - [page]: Page number for pagination (default: 1)
  /// - [perPage]: Number of items per page (default: 15)
  /// - [status]: Filter by payment status (optional)
  Future<PaymentHistoryResponse> getPaymentHistory({
    int page = 1,
    int perPage = 15,
    String? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };

      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      final uri = Uri.parse(ApiConfig.paymentHistoryEndpoint).replace(
        queryParameters: queryParams,
      );

      print('📡 [PaymentService] Fetching payment history...');
      print('🔗 [PaymentService] URL: ${uri.toString()}');

      final response = await _apiClient.get(
        uri.toString(),
        requiresAuth: true,
      );

      if (response['success'] == true) {
        print('✅ [PaymentService] Payment history received');
        print('📊 [PaymentService] Total: ${response['pagination']?['total'] ?? 0}');
        return PaymentHistoryResponse.fromJson(response);
      } else {
        throw PaymentException(
          message: response['message'] ?? 'Failed to fetch payment history',
        );
      }
    } catch (e) {
      print('💥 [PaymentService] Error fetching payment history: $e');
      if (e is PaymentException) {
        rethrow;
      }
      throw PaymentException(
        message: 'An unexpected error occurred: $e',
      );
    }
  }

  // ==================== PAYMENT RECEIPT ====================

  /// Get payment receipt
  /// 
  /// Parameters:
  /// - [paymentId]: The payment ID to get receipt for
  Future<PaymentReceiptResponse> getPaymentReceipt(int paymentId) async {
    try {
      print('📡 [PaymentService] Fetching payment receipt...');
      print('🔗 [PaymentService] Payment ID: $paymentId');

      final response = await _apiClient.get(
        ApiConfig.paymentReceiptEndpoint(paymentId),
        requiresAuth: true,
      );

      if (response['success'] == true) {
        print('✅ [PaymentService] Payment receipt received');
        return PaymentReceiptResponse.fromJson(response);
      } else {
        throw PaymentException(
          message: response['message'] ?? 'Failed to fetch payment receipt',
        );
      }
    } catch (e) {
      print('💥 [PaymentService] Error fetching receipt: $e');
      if (e is PaymentException) {
        rethrow;
      }
      throw PaymentException(
        message: 'An unexpected error occurred: $e',
      );
    }
  }

  // ==================== CONVENIENCE METHODS ====================

  /// Check if payment is for assessment fee
  bool isAssessmentPayment(String paymentType) {
    return paymentType == 'assessment_fee';
  }

  /// Check if payment is for care fee
  bool isCarePayment(String paymentType) {
    return paymentType == 'care_fee';
  }

  /// Format amount with currency
  String formatAmount(double amount, String currency) {
    return '$currency ${amount.toStringAsFixed(2)}';
  }

  /// Get payment status display text
  String getPaymentStatusText(String status) {
    final statusTexts = {
      'pending': 'Pending',
      'processing': 'Processing',
      'completed': 'Completed',
      'failed': 'Failed',
      'refunded': 'Refunded',
      'cancelled': 'Cancelled',
    };
    return statusTexts[status] ?? status;
  }

  /// Get payment method display text
  String getPaymentMethodText(String method) {
    final methodTexts = {
      'mobile_money': 'Mobile Money',
      'card': 'Card Payment',
      'bank_transfer': 'Bank Transfer',
      'ussd': 'USSD',
    };
    return methodTexts[method] ?? method;
  }
}

// ============================================================================
// EXCEPTION CLASS
// ============================================================================

/// Custom exception for Payment operations
class PaymentException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  PaymentException({
    required this.message,
    this.statusCode,
    this.errors,
  });

  @override
  String toString() => message;

  /// Get first error message from errors map
  String? getFirstError() {
    if (errors == null || errors!.isEmpty) return null;

    final firstKey = errors!.keys.first;
    final firstValue = errors![firstKey];

    if (firstValue is List && firstValue.isNotEmpty) {
      return firstValue.first.toString();
    } else if (firstValue is String) {
      return firstValue;
    }

    return null;
  }
}

// ============================================================================
// RESPONSE MODELS
// ============================================================================

class PaymentConfigResponse {
  final bool success;
  final String message;
  final PaymentConfig? data;

  PaymentConfigResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory PaymentConfigResponse.fromJson(Map<String, dynamic> json) {
    return PaymentConfigResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? PaymentConfig.fromJson(json['data']) : null,
    );
  }
}

class PaymentInitializationResponse {
  final bool success;
  final String message;
  final PaymentInitialization? data;

  PaymentInitializationResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory PaymentInitializationResponse.fromJson(Map<String, dynamic> json) {
    return PaymentInitializationResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? PaymentInitialization.fromJson(json['data']) : null,
    );
  }
}

class PaymentVerificationResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;

  PaymentVerificationResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory PaymentVerificationResponse.fromJson(Map<String, dynamic> json) {
    return PaymentVerificationResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'],
    );
  }
}

class PaymentHistoryResponse {
  final bool success;
  final String message;
  final List<Payment> data;
  final Pagination? pagination;

  PaymentHistoryResponse({
    required this.success,
    required this.message,
    required this.data,
    this.pagination,
  });

  factory PaymentHistoryResponse.fromJson(Map<String, dynamic> json) {
    return PaymentHistoryResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: (json['data'] as List<dynamic>?)
              ?.map((e) => Payment.fromJson(e))
              .toList() ??
          [],
      pagination: json['pagination'] != null
          ? Pagination.fromJson(json['pagination'])
          : null,
    );
  }
}

class PaymentReceiptResponse {
  final bool success;
  final String message;
  final PaymentReceipt? data;

  PaymentReceiptResponse({
    required this.success,
    required this.message,
    this.data,
  });

  factory PaymentReceiptResponse.fromJson(Map<String, dynamic> json) {
    return PaymentReceiptResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? PaymentReceipt.fromJson(json['data']) : null,
    );
  }
}

// ==================== OTP RESPONSE MODELS ====================

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