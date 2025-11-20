import '../../utils/api_client.dart';
import '../../utils/api_config.dart';
import '../../models/care_request/care_request_models.dart';

/// Service for handling Care Request API calls
class CareRequestService {
  final ApiClient _apiClient = ApiClient();

  // ==================== CARE REQUEST INFO ====================

  /// Get care request process information and assessment fee
  /// 
  /// Parameters:
  /// - [careType]: Type of care needed (optional)
  /// - [region]: Patient's region for regional pricing (optional)
  Future<CareRequestInfoResponse> getRequestInfo({
    String? careType,
    String? region,
  }) async {
    try {
      final queryParams = <String, dynamic>{};

      if (careType != null && careType.isNotEmpty) {
        queryParams['care_type'] = careType;
      }

      if (region != null && region.isNotEmpty) {
        queryParams['region'] = region;
      }

      final uri = Uri.parse(ApiConfig.careRequestInfoEndpoint).replace(
        queryParameters: queryParams,
      );

      print('📡 [CareRequestService] Fetching request info...');
      print('🔗 [CareRequestService] URL: ${uri.toString()}');
      
      final response = await _apiClient.get(uri.toString());

      if (response['success'] == true) {
        print('✅ [CareRequestService] Request info received');
        return CareRequestInfoResponse.fromJson(response);
      } else {
        throw CareRequestException(
          message: response['message'] ?? 'Failed to fetch request info',
        );
      }
    } catch (e) {
      print('💥 [CareRequestService] Error fetching request info: $e');
      if (e is CareRequestException) {
        rethrow;
      }
      throw CareRequestException(
        message: 'An unexpected error occurred: $e',
      );
    }
  }

  // ==================== CARE REQUESTS LIST ====================

  /// Get all care requests for the patient
  /// 
  /// Parameters:
  /// - [page]: Page number for pagination (default: 1)
  /// - [perPage]: Number of items per page (default: 15)
  /// - [status]: Filter by status (optional)
  Future<CareRequestsResponse> getCareRequests({
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

      final uri = Uri.parse(ApiConfig.careRequestsEndpoint).replace(
        queryParameters: queryParams,
      );

      print('📡 [CareRequestService] Fetching care requests...');
      print('🔗 [CareRequestService] URL: ${uri.toString()}');
      
      final response = await _apiClient.get(uri.toString());

      if (response['success'] == true) {
        print('✅ [CareRequestService] Care requests received');
        print('📊 [CareRequestService] Total: ${response['pagination']?['total'] ?? 0}');
        return CareRequestsResponse.fromJson(response);
      } else {
        throw CareRequestException(
          message: response['message'] ?? 'Failed to fetch care requests',
        );
      }
    } catch (e) {
      print('💥 [CareRequestService] Error fetching care requests: $e');
      if (e is CareRequestException) {
        rethrow;
      }
      throw CareRequestException(
        message: 'An unexpected error occurred: $e',
      );
    }
  }

  /// Get a specific care request by ID
  /// 
  /// Parameters:
  /// - [requestId]: The ID of the care request to fetch
  Future<CareRequestDetailResponse> getCareRequestById(int requestId) async {
    try {
      print('📡 [CareRequestService] Fetching care request detail...');
      print('🔗 [CareRequestService] Request ID: $requestId');
      print('🔗 [CareRequestService] Endpoint: ${ApiConfig.careRequestDetailEndpoint(requestId)}');
      
      final response = await _apiClient.get(
        ApiConfig.careRequestDetailEndpoint(requestId),
      );

      print('✅ [CareRequestService] Detail response received');
      print('🎯 [CareRequestService] Success: ${response['success']}');

      if (response['success'] == true) {
        print('✅ [CareRequestService] Parsing detail response');
        return CareRequestDetailResponse.fromJson(response);
      } else {
        print('❌ [CareRequestService] API returned success=false');
        print('❌ [CareRequestService] Error message: ${response['message']}');
        throw CareRequestException(
          message: response['message'] ?? 'Failed to fetch care request',
        );
      }
    } catch (e) {
      print('💥 [CareRequestService] Detail exception caught: $e');
      
      if (e is CareRequestException) {
        rethrow;
      }
      throw CareRequestException(
        message: 'An unexpected error occurred: $e',
      );
    }
  }

  // ==================== CREATE CARE REQUEST ====================

  /// Create a new care request
  /// 
  /// Parameters:
  /// - [request]: The care request data to create
  Future<CreateCareRequestResponse> createCareRequest(
    CreateCareRequestRequest request,
  ) async {
    try {
      print('📡 [CareRequestService] Creating care request...');
      print('📋 [CareRequestService] Request data: ${request.toJson()}');
      
      final response = await _apiClient.post(
        ApiConfig.careRequestsEndpoint,
        body: request.toJson(),
        requiresAuth: true,
      );

      print('✅ [CareRequestService] Create response received');
      print('🎯 [CareRequestService] Success: ${response['success']}');

      if (response['success'] == true) {
        print('✅ [CareRequestService] Care request created successfully');
        return CreateCareRequestResponse.fromJson(response);
      } else {
        print('❌ [CareRequestService] Create API returned success=false');
        print('❌ [CareRequestService] Error message: ${response['message']}');
        print('❌ [CareRequestService] Errors: ${response['errors']}');
        throw CareRequestException(
          message: response['message'] ?? 'Failed to create care request',
          errors: response['errors'],
        );
      }
    } catch (e) {
      print('💥 [CareRequestService] Create exception caught: $e');
      
      if (e is CareRequestException) {
        rethrow;
      }
      throw CareRequestException(
        message: 'An unexpected error occurred: $e',
      );
    }
  }

  // ==================== CANCEL CARE REQUEST ====================

  /// Cancel a care request
  /// 
  /// Parameters:
  /// - [requestId]: The ID of the care request to cancel
  /// - [reason]: Optional reason for cancellation
  Future<CancelCareRequestResponse> cancelCareRequest(
    int requestId, {
    String? reason,
  }) async {
    try {
      print('📡 [CareRequestService] Cancelling care request...');
      print('🔗 [CareRequestService] Request ID: $requestId');
      
      final body = <String, dynamic>{};
      if (reason != null && reason.isNotEmpty) {
        body['reason'] = reason;
      }

      final response = await _apiClient.post(
        ApiConfig.cancelCareRequestEndpoint(requestId),
        body: body,
        requiresAuth: true,
      );

      print('✅ [CareRequestService] Cancel response received');
      print('🎯 [CareRequestService] Success: ${response['success']}');

      if (response['success'] == true) {
        print('✅ [CareRequestService] Care request cancelled successfully');
        return CancelCareRequestResponse.fromJson(response);
      } else {
        print('❌ [CareRequestService] Cancel API returned success=false');
        print('❌ [CareRequestService] Error message: ${response['message']}');
        throw CareRequestException(
          message: response['message'] ?? 'Failed to cancel care request',
        );
      }
    } catch (e) {
      print('💥 [CareRequestService] Cancel exception caught: $e');
      
      if (e is CareRequestException) {
        rethrow;
      }
      throw CareRequestException(
        message: 'An unexpected error occurred: $e',
      );
    }
  }

  // ==================== PAYMENT OPERATIONS ====================

  /// Initiate payment for assessment or care
  /// 
  /// Parameters:
  /// - [requestId]: The ID of the care request
  /// - [paymentMethod]: Payment method (mobile_money, card, bank_transfer)
  /// - [paymentProvider]: Payment provider (MTN, Vodafone, etc.)
  /// - [phoneNumber]: Phone number for mobile money
  Future<InitiatePaymentResponse> initiatePayment({
    required int requestId,
    required String paymentMethod,
    required String paymentProvider,
    required String phoneNumber,
  }) async {
    try {
      print('📡 [CareRequestService] Initiating payment...');
      print('🔗 [CareRequestService] Request ID: $requestId');
      print('💳 [CareRequestService] Method: $paymentMethod');
      
      final body = {
        'payment_method': paymentMethod,
        'payment_provider': paymentProvider,
        'phone_number': phoneNumber,
      };

      final response = await _apiClient.post(
        ApiConfig.initiatePaymentEndpoint(requestId),
        body: body,
        requiresAuth: true,
      );

      print('✅ [CareRequestService] Payment initiation response received');
      print('🎯 [CareRequestService] Success: ${response['success']}');

      if (response['success'] == true) {
        print('✅ [CareRequestService] Payment initiated successfully');
        return InitiatePaymentResponse.fromJson(response);
      } else {
        print('❌ [CareRequestService] Payment initiation failed');
        print('❌ [CareRequestService] Error message: ${response['message']}');
        throw CareRequestException(
          message: response['message'] ?? 'Failed to initiate payment',
          errors: response['errors'],
        );
      }
    } catch (e) {
      print('💥 [CareRequestService] Payment initiation exception: $e');
      
      if (e is CareRequestException) {
        rethrow;
      }
      throw CareRequestException(
        message: 'An unexpected error occurred: $e',
      );
    }
  }

  /// Verify payment
  /// 
  /// Parameters:
  /// - [reference]: Payment reference number
  /// - [transactionId]: Transaction ID from payment provider
  Future<VerifyPaymentResponse> verifyPayment({
    required String reference,
    required String transactionId,
  }) async {
    try {
      print('📡 [CareRequestService] Verifying payment...');
      print('🔗 [CareRequestService] Reference: $reference');
      
      final body = {
        'reference': reference,
        'transaction_id': transactionId,
      };

      final response = await _apiClient.post(
        ApiConfig.verifyPaymentEndpoint,
        body: body,
        requiresAuth: true,
      );

      print('✅ [CareRequestService] Payment verification response received');
      print('🎯 [CareRequestService] Success: ${response['success']}');

      if (response['success'] == true) {
        print('✅ [CareRequestService] Payment verified successfully');
        return VerifyPaymentResponse.fromJson(response);
      } else {
        print('❌ [CareRequestService] Payment verification failed');
        print('❌ [CareRequestService] Error message: ${response['message']}');
        throw CareRequestException(
          message: response['message'] ?? 'Failed to verify payment',
        );
      }
    } catch (e) {
      print('💥 [CareRequestService] Payment verification exception: $e');
      
      if (e is CareRequestException) {
        rethrow;
      }
      throw CareRequestException(
        message: 'An unexpected error occurred: $e',
      );
    }
  }

  // ==================== CONVENIENCE METHODS ====================

  /// Get pending payment requests
  /// 
  /// This is a convenience method that filters by pending_payment status
  Future<CareRequestsResponse> getPendingPaymentRequests({
    int page = 1,
    int perPage = 15,
  }) async {
    print('💰 [CareRequestService] Fetching pending payment requests');
    return getCareRequests(
      status: 'pending_payment',
      page: page,
      perPage: perPage,
    );
  }

  /// Get active care requests
  /// 
  /// This is a convenience method that filters by care_active status
  Future<CareRequestsResponse> getActiveCareRequests({
    int page = 1,
    int perPage = 15,
  }) async {
    print('🏥 [CareRequestService] Fetching active care requests');
    return getCareRequests(
      status: 'care_active',
      page: page,
      perPage: perPage,
    );
  }

  /// Get completed care requests
  /// 
  /// This is a convenience method that filters by completed status
  Future<CareRequestsResponse> getCompletedCareRequests({
    int page = 1,
    int perPage = 15,
  }) async {
    print('✅ [CareRequestService] Fetching completed care requests');
    return getCareRequests(
      status: 'completed',
      page: page,
      perPage: perPage,
    );
  }

  /// Check if care request can be cancelled
  /// 
  /// Parameters:
  /// - [status]: Current status of the care request
  bool canCancelRequest(String status) {
    final cancellableStatuses = [
      'pending_payment',
      'payment_received',
      'nurse_assigned',
      'assessment_scheduled',
    ];
    return cancellableStatuses.contains(status);
  }

  /// Check if care request requires assessment payment
  /// 
  /// Parameters:
  /// - [status]: Current status of the care request
  bool requiresAssessmentPayment(String status) {
    return status == 'pending_payment';
  }

  /// Check if care request requires care payment
  /// 
  /// Parameters:
  /// - [status]: Current status of the care request
  bool requiresCarePayment(String status) {
    return status == 'awaiting_care_payment';
  }

  /// Get status display text
  /// 
  /// Parameters:
  /// - [status]: Status code
  String getStatusDisplayText(String status) {
    final statusTexts = {
      'pending_payment': 'Pending Payment',
      'payment_received': 'Payment Received',
      'nurse_assigned': 'Nurse Assigned',
      'assessment_scheduled': 'Assessment Scheduled',
      'assessment_completed': 'Assessment Completed',
      'under_review': 'Under Review',
      'awaiting_care_payment': 'Awaiting Care Payment',
      'care_payment_received': 'Care Payment Received',
      'care_active': 'Care Active',
      'completed': 'Completed',
      'cancelled': 'Cancelled',
      'rejected': 'Rejected',
    };
    return statusTexts[status] ?? status;
  }

  /// Get urgency display text
  /// 
  /// Parameters:
  /// - [urgency]: Urgency level
  String getUrgencyDisplayText(String urgency) {
    final urgencyTexts = {
      'routine': 'Routine',
      'urgent': 'Urgent',
      'emergency': 'Emergency',
    };
    return urgencyTexts[urgency] ?? urgency;
  }

  /// Get care type display text
  /// 
  /// Parameters:
  /// - [careType]: Care type code
  String getCareTypeDisplayText(String careType) {
    final careTypeTexts = {
      'general_nursing': 'General Nursing',
      'elderly_care': 'Elderly Care',
      'post_surgical': 'Post-Surgical Care',
      'chronic_disease': 'Chronic Disease Management',
      'palliative_care': 'Palliative Care',
      'rehabilitation': 'Rehabilitation',
      'wound_care': 'Wound Care',
      'medication_management': 'Medication Management',
    };
    return careTypeTexts[careType] ?? careType;
  }


  /// Get care requests assigned to nurse (for assessments)
  Future<CareRequestsResponse> getAssignedCareRequests({
    int page = 1,
    int perPage = 15,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };

      final uri = Uri.parse(ApiConfig.nurseAssignedCareRequestsEndpoint).replace(
        queryParameters: queryParams,
      );

      print('📡 [CareRequestService] Fetching assigned care requests...');
      print('🔗 [CareRequestService] URL: ${uri.toString()}');
      
      final response = await _apiClient.get(uri.toString());

      if (response['success'] == true) {
        print('✅ [CareRequestService] Assigned care requests received');
        print('📊 [CareRequestService] Total: ${response['pagination']?['total'] ?? 0}');
        return CareRequestsResponse.fromJson(response);
      } else {
        throw CareRequestException(
          message: response['message'] ?? 'Failed to fetch assigned care requests',
        );
      }
    } catch (e) {
      print('💥 [CareRequestService] Error fetching assigned care requests: $e');
      if (e is CareRequestException) {
        rethrow;
      }
      throw CareRequestException(
        message: 'An unexpected error occurred: $e',
      );
    }
  }
  
}





// ============================================================================
// EXCEPTION CLASS
// ============================================================================

/// Custom exception for Care Request operations
class CareRequestException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  CareRequestException({
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